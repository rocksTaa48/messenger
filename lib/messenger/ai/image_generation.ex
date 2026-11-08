defmodule Messenger.Ai.ImageGeneration do
  alias Messenger.{Chats, Accounts, Storage}
  alias Messenger.Ai.OpenRouterClient
  require Logger

  def start_generation(current_user, attrs) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      try do
        run(current_user, attrs)
      rescue
        e ->
          Logger.error("Image generation crashed: " <> Exception.format(:error, e, __STACKTRACE__))
          fail_generation(current_user.id, attrs, {:crash, Exception.message(e)})
      end
    end)
  end

  defp run(current_user, attrs) do
    client_attrs = %{
      "prompt" => Map.fetch!(attrs, "image_prompt"),
      "image_ai_model" => Map.fetch!(attrs, "image_ai_model").openrouter_model_id
    }

    # Без Retry
    case OpenRouterClient.call_image_generator(client_attrs) do
      {:ok, %{binary: binary, media_type: media_type, usage: usage}} ->
        # 1) Сначала durable-сохранение — картинка оплачена, терять нельзя
        case Storage.save_image(binary, media_type) do
          {:ok, image_ref} ->
            thumb_ref = make_thumbnail_or_fallback(binary, media_type, image_ref)
            successful_transaction(current_user, attrs, image_ref, thumb_ref, usage)

          {:error, reason} ->
            Logger.error("Failed to persist generated image: #{inspect(reason)}")
            fail_generation(current_user.id, attrs, {:storage_error, reason})
        end

      {:error, reason} ->
        fail_generation(current_user.id, attrs, reason)
    end
  end

  # Картинка уже на диске. Пишем транзакцию + сообщение + broadcast.
  defp successful_transaction(current_user, attrs, image_ref, thumb_ref, usage) do
    chat_id = Map.get(attrs, "chat_id")
    message_id = Map.get(attrs, "message_id")
    prompt = Map.get(attrs, "image_prompt")
    image_ai_model = Map.fetch!(attrs, "image_ai_model")

    case Chats.create_chat_image(%{
      "storage_key" => image_ref.storage_key,
      "thumb_storage_key" => thumb_ref.storage_key,
      "message_id" => message_id,
      "metadata" => %{
        "prompt" => prompt,
        "media_type" => image_ref.media_type,
        "thumb_media_type" => thumb_ref.media_type,
        "thumb_height" => thumb_ref.height,
        "thumb_width" => thumb_ref.width,
        "model" => image_ai_model.openrouter_model_id,
        "usage" => usage
      }
    }) do
      {:ok, chat_image} ->
        try do
          Accounts.record_transaction(%{
            "user_id" => current_user.id,
            "ai_model_id" => image_ai_model.id,
            "cost_total" => get_in(usage || %{}, ["cost"]) || 0.0,
            "metadata" => %{
              "action" => "chat_image_generation",
              "chat_id" => chat_id,
              "chat_image_id" => chat_image.id,
              "model" => image_ai_model.openrouter_model_id
            }
          })
        rescue
          e ->
            Logger.error("Transaction record failed chat=#{chat_id}: #{inspect(e)}")
        end

        if message_id, do: Chats.mark_message_completed(message_id)

        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{current_user.id}:lobby",
          {:ai_image_done, %{
            chat_id: chat_id,
            message_id: message_id,
            image_url: thumb_ref.url,
            media_type: thumb_ref.media_type,
            image_height: thumb_ref.height,
            image_width: thumb_ref.width,
            chat_image_id: chat_image.id
          }}
        )

      {:error, changeset} ->
        Logger.error(
          "ChatImage creation failed, file orphaned: #{image_ref.storage_key} errors=#{inspect(changeset.errors)}"
        )

          fail_generation(current_user.id, attrs, {:db_error, changeset.errors})
    end
  end

  defp fail_generation(user_id, attrs, reason) do
    chat_id = Map.get(attrs, "chat_id")
    message_id = Map.get(attrs, "message_id")

    Logger.error("Image generation error chat=#{chat_id} message_id=#{message_id}: #{inspect(reason)}")

    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_image_error, %{
        chat_id: chat_id,
        message_id: message_id,
        reason: generation_error(reason)
      }}
    )
  end

  defp make_thumbnail_or_fallback(binary, media_type, image_ref) do
    case Storage.save_thumbnail(binary, media_type) do
      {:ok, thumb_ref} ->
        thumb_ref

      {:error, reason} ->
        Logger.warning("Thumbnail failed, falling back to original: #{inspect(reason)}")
        image_ref
    end
  end

  defp generation_error(reason) do
    case reason do
      {:http, 401} -> "Проблема с доступом к AI. Обратитесь в поддержку."
      {:http, 402} -> "Закончились кредиты на генерацию. Пополните баланс."
      {:http, 429} -> "Слишком много запросов. Подождите минуту."
      {:http, s} when s >= 500 -> "Сервис временно недоступен. Попробуйте позже."
      {:http, _} -> "Ошибка при обработке запроса."
      {:network_error, _} -> "Проблема с соединением."
      :rate_limited -> "Слишком много запросов."
      :empty_response -> "AI вернул пустой ответ."
      {:storage_error, _} -> "Не удалось сохранить изображение."
      _ -> "Произошла ошибка. Попробуйте позже."
    end
  end
end
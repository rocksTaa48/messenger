defmodule Messenger.Ai.MessageTranscript do
  alias Messenger.Ai.{Retry, OpenRouterClient}
  alias Messenger.AiProfiles
  alias Messenger.Chats
  alias Messenger.Accounts
  require Logger

  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_generation(current_user, attrs) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn -> run(current_user, attrs) end)
  end

  defp run(current_user, attrs) do
    ai_transcript_model = AiProfiles.get_ai_model(attrs.ai_transcript_model_id)

    client_attrs = %{
      "base64" => attrs.base64,
      "format" => attrs.format,
      "ai_transcript_model" => ai_transcript_model.openrouter_model_id,
    }

    action = Retry.call(fn -> OpenRouterClient.call_transcript(client_attrs) end)

    case action do
      {:ok, %{content: content, usage: usage}} ->
        successful_transaction(current_user, attrs, content, usage)

      {:error, reason} ->
        send_error_to_lobby(current_user.id, attrs.chat_id, reason)
    end
  end

  # Запрос состоялся, удачная транзакция
  defp successful_transaction(current_user, attrs, content, usage) do
    chat_id = attrs.chat_id
    temp_id = attrs.temp_id

    Accounts.record_transaction(%{
      "user_id" => current_user.id,
      "ai_model_id" => attrs.ai_transcript_model_id,
      "cost_total" => Map.get(usage, "cost", 0.0),
      "metadata" => %{"action" => "chat_transcript_voice", "chat_id" => chat_id, "time_seconds" => Map.get(usage, "seconds", 0.0)}
    })

    case Chats.MessageSender.create_message(current_user, %{attrs | text: content, base64: nil, format: nil})do
      {:ok, %{chat: chat, message: message}} ->
        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{current_user.id}:lobby",
          {:ai_transcript_done, %{
            temp_id: temp_id,
            chat_id: chat.id,
            message_id: message.id,
            is_audio: true,
            text: message.content,
            ai_model_id: to_string(chat.ai_model_id),
            profile_overrides: chat.profile_overrides
          }}
        )

      {:error, changeset} ->
        send_error_to_lobby(current_user.id, chat_id, "DB error: #{inspect(changeset.errors)}")
    end
  end

  # Запрос упал с ошибкой
  defp send_error_to_lobby(user_id, chat_id, reason) do
    Logger.error("AI transcription error for chat #{chat_id}: #{inspect(reason)}")
    user_message = translate_error(reason)
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_transcript_error, %{chat_id: chat_id, reason: user_message}}
    )
  end

  defp translate_error(reason) do
    case reason do
      {:http, 401} -> "Проблема с доступом к AI. Обратитесь в поддержку."
      {:http, 429} -> "Слишком много запросов. Подождите минуту и попробуйте снова."
      {:http, s} when s >= 500 -> "Сервис временно недоступен. Попробуйте позже."
      {:http, _} -> "Ошибка при обработке запроса."
      {:network_error, _} -> "Проблема с соединением. Проверьте интернет."
      :rate_limited -> "Слишком много запросов. Подождите минуту."
      :empty_response -> "AI вернул пустой ответ. Попробуйте еще раз."
      _ -> "Произошла ошибка. Попробуйте позже."
    end
  end
end
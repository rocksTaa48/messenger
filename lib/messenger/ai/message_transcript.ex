defmodule Messenger.Ai.MessageTranscript do
  alias Messenger.Ai.{Retry, OpenRouterClient}
  alias Messenger.Chats
  require Logger

  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_generation(current_user, attrs) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn -> run(current_user, attrs) end)
  end

  defp run(current_user, attrs) do
    client_attrs = %{
      "base64" => Map.fetch!(attrs, "base64"),
      "format" => Map.fetch!(attrs, "format"),
      "ai_transcript_model" => Map.fetch!(attrs, "ai_transcript_model").openrouter_model_id,
    }

    action = Retry.call(fn -> OpenRouterClient.call_transcript(client_attrs) end)

    case action do
      {:ok, %{content: content, usage: usage}} ->
        successful_transaction(current_user, attrs, content, usage)

      {:error, reason} ->
        send_error_to_lobby(current_user.id, Map.get(attrs, "chat_id"), reason)
    end
  end

  # Запрос состоялся, удачная транзакция
  defp successful_transaction(current_user, attrs, content, usage) do
    IO.inspect(attrs, label: "-------------------- ТО ЧТО ПРИШЛО В MESSAGE SENDER")
    chat_id = Map.get(attrs, "chat_id")
    temp_id = Map.get(attrs, "temp_id")
    profile_overrides = Map.get(attrs, "profile_overrides")

    ai_model_id =
      case Map.get(attrs, "ai_model_id") do
        nil -> nil
        id when is_integer(id) -> id
        id when is_binary(id) -> String.to_integer(id)
      end
      # ДОДЕЛАЙ ОТДАЧУ!!!! после аудио не отдается model_id top_p temperature и прочая хуета!
    case Chats.MessageSender.create_message(current_user,
           %{"text" => content,
             "chat_id" => chat_id,
             "temp_id" => temp_id,
             "is_audio" => true,
             "ai_model_id" => ai_model_id,
             "profile_overrides" => profile_overrides
           }) do
      {:ok, chat, message} ->
        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{current_user.id}:lobby",
          {:ai_transcript_done, %{
            temp_id: temp_id,
            chat_id: chat.id,
            message_id: message.id,
            is_audio: true,
            text: message.content,
            ai_model_id: to_string(ai_model_id),
            profile_overrides: profile_overrides
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
defmodule Messenger.Ai.MessageTranscript do
  alias Messenger.Ai.{Retry, OpenRouterClient}
  alias Messenger.Chats

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
      "ai_model" => Map.fetch!(attrs, "ai_model").openrouter_model_id,
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
    chat_id = Map.get(attrs, "chat_id")
    temp_id = Map.get(attrs, "temp_id")
    ai_model = Map.get(attrs, "ai_model")
    action =
      if is_nil(chat_id) do
        Chats.ChatsBuilder.create_first_message(current_user, %{"text" => content, "temp_id" => temp_id, "is_audio" => true})
      else
        Chats.ChatsBuilder.create_message_in_chat(current_user, %{"text" => content, "chat_id" => chat_id, "temp_id" => temp_id, "is_audio" => true})
      end

    case action do
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
            ai_model_id: ai_model.id
          }}
        )

      {:error, changeset} ->
        send_error_to_lobby(current_user.id, chat_id, "DB error: #{inspect(changeset.errors)}")
    end
  end

  # Запрос упал с ошибкой
  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_transcript_error, %{chat_id: chat_id, reason: reason}}
    )
  end
end
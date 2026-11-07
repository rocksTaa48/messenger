defmodule Messenger.Ai.CreateOrchestratorMessage do
  alias Messenger.Ai.{Retry, OpenRouterClient, ImageGeneration}
  alias Messenger.Chats
  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_generation(current_user, attrs) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn -> run(current_user, attrs) end)
  end


  defp run(current_user, attrs) do
    client_attrs = %{
      "content" => Map.fetch!(attrs, "content"),
      "context" => Map.fetch!(attrs, "context"),
      "ai_profile" => Map.fetch!(attrs, "ai_profile"),
      "ai_model" => Map.fetch!(attrs, "ai_model").openrouter_model_id
    }

    action = Retry.call(fn -> OpenRouterClient.call_orchestrator(client_attrs) end)

    case action do
      {:ok, %{content: raw_json_string, usage: usage}} ->
        IO.inspect(raw_json_string, label: "RAW JSON INCOMING UP TO MODEL <-------------------------------------")

        # Парсим JSON, полученный из контента модели
        case Jason.decode(raw_json_string) do
          {:ok, %{"prompt" => prompt}} ->
            successful_transaction(current_user, attrs, String.trim(prompt), usage)

          {:ok, _other_json} ->
            # Модель прислала JSON, но без нужного ключа
            send_error_to_lobby(current_user.id, Map.get(attrs, "chat_id"), :missing_prompt_key)

          {:error, _parse_error} ->
            # Сбой парсинга или модель оборвала генерацию
            send_error_to_lobby(current_user.id, Map.get(attrs, "chat_id"), :invalid_json_content)
        end

      {:error, reason} ->
        send_error_to_lobby(current_user.id, Map.get(attrs, "chat_id"), reason)
    end
  end

  # Запрос состоялся, удачная транзакция
  defp successful_transaction(current_user, attrs, content, usage) do
    ai_model_id = Map.fetch!(attrs, "ai_model").id
    request_id = Map.fetch!(attrs, "request_id")
    chat_id = Map.get(attrs, "chat_id")
    temp_id = Map.get(attrs, "temp_id")
    image_ai_model = Map.fetch!(attrs, "image_ai_model")

    case Chats.create_assistant_message(%{
      user_id: current_user.id,
      chat_id: chat_id,
      ai_model_id: ai_model_id,
      request_id: request_id,
      content: content,
      role: "assistant",
      is_aborted: false,
      tokens_prompt: Map.get(usage, "prompt_tokens", 0),
      tokens_completion: Map.get(usage, "completion_tokens", 0),
      tokens_total: Map.get(usage, "total_tokens", 0),
      cost_prompt: Map.get(usage, "cost_prompt", 0.0),
      cost_completion: Map.get(usage, "cost_completion", 0.0),
      cost_total: Map.get(usage, "cost", 0.0)
    }) do
      {:ok, %{message: inserted_message}} ->
        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{current_user.id}:lobby",
          {:ai_orchestrator_done, %{
            chat_id: chat_id,
            message_id: inserted_message.id,
            ai_model_id: inserted_message.ai_model_id
          }}
        )

        ImageGeneration.start_generation(current_user, %{
          "image_ai_model" => image_ai_model,
          "image_prompt" => content,
          "message_id" => inserted_message.id,
          "chat_id" => chat_id
        })

      {:error, changeset} ->
        send_error_to_lobby(current_user.id, chat_id, "DB error: #{inspect(changeset.errors)}")
    end
  end

  # Запрос упал с ошибкой
  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:chat_title_error, %{chat_id: chat_id, reason: reason}}
    )
  end

end
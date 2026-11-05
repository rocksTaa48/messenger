defmodule Messenger.Ai.CreateOrchestratorMessage do
  alias Messenger.Ai.{Retry, OpenRouterClient}
  alias Messenger.Chats
  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_generation(attrs) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn -> run(attrs) end)
  end


  defp run(attrs) do
    client_attrs = %{
      "content" => Map.fetch!(attrs, "content"),
      "ai_profile" => Map.fetch!(attrs, "ai_profile"),
      "ai_model" => Map.fetch!(attrs, "ai_model").openrouter_model_id
    }

    action = Retry.call(fn -> OpenRouterClient.call_orchestrator(client_attrs) end)

    case action do
      {:ok, %{content: content, usage: usage}} ->
        successful_transaction(attrs, content, usage)

      {:error, reason} ->
        send_error_to_lobby(Map.fetch!(attrs, "user_id"), Map.get(attrs, "chat_id"), reason)
    end
  end

  # Запрос состоялся, удачная транзакция
  defp successful_transaction(attrs, content, usage) do
    ai_model = Map.fetch!(attrs, "ai_model")
    user_id = Map.fetch!(attrs, "user_id")
    request_id = Map.fetch!(attrs, "request_id")
    chat_id = Map.get(attrs, "chat_id")
    temp_id = Map.get(attrs, "temp_id")

    safe_title = String.slice(content, 0, 99)

    case Chats.create_assistant_image_session_message(%{
      user_id: user_id,
      chat_id: chat_id,
      ai_model_id: ai_model.id,
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
      {:ok, _chat} ->
        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:image_session_response_complete, %{chat_id: chat_id, title: safe_title}}
        )

      {:error, changeset} ->
        send_error_to_lobby(user_id, chat_id, "DB error: #{inspect(changeset.errors)}")
    end
  end

  # Запрос упал с ошибкой

end
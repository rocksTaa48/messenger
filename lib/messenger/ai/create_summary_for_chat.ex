defmodule Messenger.Ai.CreateSummaryForChat do
  require Logger
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
      "context" => Map.fetch!(attrs, "context"),
      "ai_profile" => Map.fetch!(attrs, "ai_profile"),
      "ai_model" => Map.fetch!(attrs, "ai_model").openrouter_model_id
    }

    action = Retry.call(fn -> OpenRouterClient.call_summary(client_attrs) end)

    case action do
      {:ok, %{content: content, usage: usage}} ->
        successful_transaction(current_user, attrs, content, usage)

      {:error, reason} ->
        log_error(current_user.id, Map.get(attrs, "chat_id"), reason)
    end
  end

  # Запрос состоялся, удачная транзакция
  defp successful_transaction(current_user, attrs, content, usage) do
    user_id = current_user.id
    chat_id = Map.get(attrs, "chat_id")
    ai_model = Map.fetch!(attrs, "ai_model")
    last_msg_id = Map.get(attrs, "last_msg_id")
    tokens_total = Map.get(usage, "total_tokens", 0)

    case Chats.create_summary(%{
      user_id: user_id,
      chat_id: chat_id,
      content: content,
      summarized_up_to_message_id: last_msg_id,
      tokens_prompt: Map.get(usage, "prompt_tokens", 0),
      tokens_completion: Map.get(usage, "completion_tokens", 0),
      tokens_total: tokens_total,
      cost_prompt: Map.get(usage, "cost_prompt", 0.0),
      cost_completion: Map.get(usage, "cost_completion", 0.0),
      cost_total: Map.get(usage, "cost", 0.0)
    }) do
      {:ok, _summary} ->
        Logger.info("Summary AI successful user=#{user_id} chat=#{chat_id} tokens=#{tokens_total}")

      {:error, changeset} ->
        log_error(user_id, chat_id, "changeset: #{inspect(changeset.errors)}")
    end
  end

  # Логирование ошибок.
  defp log_error(user_id, chat_id, reason) do
    Logger.error("Summary AI error user=#{user_id} chat=#{chat_id}: #{reason}")
  end

end
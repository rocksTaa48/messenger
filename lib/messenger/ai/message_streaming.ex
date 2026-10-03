defmodule Messenger.Ai.MessageStreaming do
  alias Messenger.Ai.{Retry, OpenRouterClient}
  alias Messenger.Chats

  @doc """
  Точка входа. Запускает задачу в фоне. (user_id, chat_id, ai_model, ai_profile, context, summaries, temp_id)
  """
  def start_generation(attrs) do
    user_id = Map.get(attrs, "user_id")
    chat_id = Map.get(attrs, "chat_id")
    # Проверяем, не запущена ли уже задача для этого chat_id
    case Registry.lookup(Messenger.AgentRegistry, {:chat, chat_id}) do
      [{_pid, _}] ->
        {:error, :already_generating}
      [] ->
        # Запускаем задачу только если чат свободен
        Task.Supervisor.start_child(Messenger.TaskSupervisor, fn -> run(user_id, chat_id, attrs) end)
    end
  end

  def stop_generation(chat_id) do
    case Registry.lookup(Messenger.AgentRegistry, {:chat, chat_id}) do
      [] ->
        {:error, :not_found}
      [{pid, _}] ->
        send(pid, :stop)
        :ok
    end
  end

  defp run(user_id, chat_id, attrs) do
    context = Map.fetch!(attrs, "context")
    ai_model = Map.fetch!(attrs, "ai_model")
    ai_profile = Map.fetch!(attrs, "ai_profile")
    summaries = Map.get(attrs, "summaries")
    temp_id = Map.fetch!(attrs, "temp_id")


    case Registry.register(Messenger.AgentRegistry, {:chat, chat_id}, true) do
      {:error, {:already_registered, _}} ->
        # Падаем, потому что занято!
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_error, %{chat_id: chat_id, ai_model: ai_model.id, reason: :already_registered}}
        )

      {:ok, _} ->
        system_prompt = ai_profile.prompt.content
        messages = [%{role: "system", content: system_prompt <> "\n\n" <> summaries} | context]

        all_text =
          messages
          |> Enum.map(fn msg -> msg.content end)
          |> Enum.join("\n")

        # -----------------------------------> Грубо считаем токены на вход модели <------------------------------------
        estimated_prompt_tokens = ceil(String.length(all_text) / 2) || 0
        prompt_tokens_dec = Decimal.new(estimated_prompt_tokens) || "0.0"
        cost_per_1m_input = ai_model.cost_per_1m_input || "0.0"
        estimated_prompt_cost = Decimal.div(Decimal.mult(cost_per_1m_input, prompt_tokens_dec), Decimal.new(1_000_000))

        # Для логов!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        IO.inspect(estimated_prompt_tokens, label: "Грубая оценка -------------> #{estimated_prompt_tokens}")
        IO.inspect(prompt_tokens_dec, label: "Грубая оценка -------------> #{prompt_tokens_dec}")
        IO.inspect(cost_per_1m_input, label: "Грубая оценка -------------> #{cost_per_1m_input}")
        IO.inspect(estimated_prompt_cost, label: "Грубая оценка -------------> #{estimated_prompt_cost}")

        on_token = fn token ->
          Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
            {:ai_token, %{
              chat_id: to_string(chat_id),
              ai_model_id: ai_model.id,
              client_msg_id: temp_id,
              token: token
            }}
          )
        end

        client_attrs = %{
          "ai_profile" => Map.fetch!(attrs, "ai_profile"),
          "ai_model" => Map.fetch!(attrs, "ai_model").openrouter_model_id,
          "summaries" => Map.get(attrs, "summaries"),
          "context" => Map.get(attrs, "context")
        }

        action = Retry.call(fn -> OpenRouterClient.call_streaming(client_attrs, on_token) end)

        case action do
          {:ok, %{content: content, usage: usage}} ->
            successful_transaction(user_id, chat_id, ai_model, content, usage, temp_id)

          {:halted, content} ->
            IO.inspect(content, label: "HALTED <--------------------------------------------------")
            save_aborted_message(user_id, chat_id, ai_model, content, temp_id, estimated_prompt_tokens, estimated_prompt_cost)

          {:error, reason} ->
            send_error_to_lobby(user_id, chat_id, ai_model.id, reason)
        end
    end
  end

  defp successful_transaction(user_id, chat_id, ai_model, content, usage, temp_id) do
    case Chats.create_assistant_message(%{
      user_id: user_id,
      chat_id: chat_id,
      ai_model_id: ai_model.id,
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
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, message_id: inserted_message.id, ai_model_id: inserted_message.ai_model_id, content: content, last_message: String.slice(content, 0, 100)}}
        )
      {:error, reason} ->
        IO.inspect(reason, label: "DB Save Error")
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, client_msg_id: temp_id, content: content}}
        )
    end
  end

  defp save_aborted_message(user_id, chat_id, ai_model, content, temp_id, estimated_prompt_tokens, estimated_prompt_cost) do

    estimated_completion_tokens = ceil(String.length(content) / 2) || 0
    completion_tokens_dec = Decimal.new(estimated_completion_tokens) || "0.0"
    cost_per_1m_output = ai_model.cost_per_1m_output || Decimal.new(0) || "0.0"
    estimated_cost_completion = Decimal.div(Decimal.mult(cost_per_1m_output, completion_tokens_dec), Decimal.new(1_000_000)) || "0.0"
    estimated_cost_total = Decimal.add(estimated_prompt_cost, estimated_cost_completion)
    IO.inspect(user_id, label: "Сам метод SaveAbortedMessage<--------------------------------------------------")

    case Chats.create_assistant_message(%{
      user_id: user_id,
      chat_id: chat_id,
      ai_model_id: ai_model.id,
      content: content,
      role: "assistant",
      tokens_prompt: estimated_prompt_tokens,
      tokens_completion: estimated_completion_tokens,
      tokens_total: estimated_prompt_tokens + estimated_completion_tokens,
      cost_prompt: estimated_prompt_cost,
      cost_completion: estimated_cost_completion || 0.0,
      cost_total: estimated_cost_total || 0.0,
      is_aborted: true
    }) do
      {:ok, %{message: inserted_message}} ->
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, client_msg_id: temp_id, message_id: inserted_message.id, ai_model_id: inserted_message.ai_model_id, content: content, last_message: String.slice(content, 0, 100), is_aborted: true}}
        )
      {:error, reason} ->
        IO.inspect(reason, label: "😡 ОШИБКА СОХРАНЕНИЯ В БД ПРИ ОТМЕНЕ ГЕНЕРАЦИИ")
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, ai_model_id: ai_model.id, client_msg_id: temp_id, content: content, is_aborted: true}}
        )
    end
  end

  defp send_error_to_lobby(user_id, chat_id, ai_model_id, reason) do
    Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
      {:ai_stream_error, %{chat_id: chat_id, ai_model_id: ai_model_id, reason: reason}}
    )
  end
end
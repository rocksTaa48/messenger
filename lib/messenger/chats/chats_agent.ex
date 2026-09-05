defmodule Messenger.Chats.ChatsAgent do
  alias Messenger.Chats

  use GenServer

  @idle_timeout :timer.minutes(15) # Таймаут простоя, после которого агент завершает работу

  # --- Публичный API ---

  def start_link(chat_id) do
    GenServer.start_link(__MODULE__, chat_id, name: via_tuple(chat_id))
  end

  # Запуск процесса (если не запущен) и отправка сообщения в очередь
  def start_and_process(user_id, chat_id, ai_profile, context) do
    ensure_started(chat_id)
    send_message(user_id, chat_id, ai_profile, context)
  end

  # Постановка сообщения в очередь GenServer
  def send_message(user_id, chat_id, ai_profile, context) do
    GenServer.cast(via_tuple(chat_id), {:process, user_id, ai_profile, context})
  end

  defp via_tuple(chat_id), do: {:via, Registry, {Messenger.AgentRegistry, chat_id}}

  # --- GenServer Callbacks ---

  @impl true
  def init(chat_id) do
    {:ok, %{chat_id: chat_id, queue: :queue.new(), processing: false}, @idle_timeout}
  end

  @impl true
  def handle_cast({:process, user_id, ai_profile, context}, state) do
    new_queue = :queue.in({user_id, ai_profile, context}, state.queue)

    new_state =
      if state.processing do
        IO.inspect("⏳ Уже идет обработка, добавили сообщение в очередь")
        %{state | queue: new_queue}
      else
        IO.inspect("🚀 Запускаем обработку из очереди")
        process_next_message(%{state | queue: new_queue, processing: true})
      end

    {:noreply, new_state, @idle_timeout}
  end

  @impl true
  def handle_cast(:next, state) do
    # Сигнал от Task, что текущий запрос завершен (успешно или с ошибкой)
    {:noreply, process_next_message(%{state | processing: false}), @idle_timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    if state.processing do
      {:noreply, state, @idle_timeout}
    else
      IO.inspect("💤 Простой 15 минут, тушим процесс чата #{state.chat_id}")
      {:stop, :normal, state}
    end
  end

  # --- Логика очереди и изоляция в Task ---

  defp process_next_message(%{queue: queue, chat_id: chat_id} = state) do
    case :queue.out(queue) do
      {{:value, {user_id, ai_profile, context}}, new_queue} ->
        # Запускаем асинхронный Task, передавая chat_id из аргументов функции
        DynamicSupervisor.start_child(
          Messenger.AiSupervisor,
          {Task, fn ->
            try do
              process_stream(user_id, chat_id, ai_profile, context)
            rescue
              e ->
                IO.inspect(e, label: "💥 Критический сбой при обработке запроса")
                send_error_to_lobby(user_id, chat_id, "Внутренняя ошибка бэкенда")
            after
              # Гарантированно пинаем GenServer взять следующее сообщение из очереди
              GenServer.cast(via_tuple(chat_id), :next)
            end
          end}
        )

        %{state | queue: new_queue}

      {:empty, new_queue} ->
        %{state | queue: new_queue, processing: false}
    end
  end

  # --- Твоя проверенная логика работы с Req (4 аргумента) ---

  defp process_stream(user_id, chat_id, ai_profile, context) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    body = %{
             model: ai_profile.openrouter_model_id,
             # Весь контекст истории вместе с новым сообщением уже внутри context
             messages: context,
             temperature: ai_profile.temperature,
             top_p: ai_profile.top_p,
             frequency_penalty: ai_profile.frequency_penalty,
             presence_penalty: ai_profile.presence_penalty,
             max_tokens: ai_profile.max_completion_tokens,
           }
           |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
           |> Enum.into(%{})

    case Req.post(url,
           json: body,
           auth: {:bearer, api_key},
           finch: [name: Messenger.OpenRouterFinch],
           receive_timeout: 30_000,
           headers: [
             {"HTTP-Referer", "https://your-monorepo-app.com"},
             {"X-Title", "Phoenix Svelte Chat"}
           ]
         ) do
      {:ok, %Req.Response{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _], "usage" => usage}}} ->
        cost_details = usage["cost_details"] || %{}
        {:ok, _} = Chats.create_assistant_message(%{
          chat_id: chat_id,
          content: content,
          role: "assistant",
          # Токены
          tokens_prompt: usage["prompt_tokens"],
          tokens_completion: usage["completion_tokens"],
          tokens_total: usage["total_tokens"],

          # Стоимость USD
          cost_prompt: cost_details["upstream_inference_prompt_cost"],
          cost_completion: cost_details["upstream_inference_completions_cost"],
          cost_total: usage["cost"]
        })
        IO.inspect(usage, label: "USAGE")
        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id}}
        )

      {:ok, %Req.Response{status: status, body: error_body}} ->
        IO.inspect({status, error_body}, label: "OpenRouter HTTP Error")
        send_error_to_lobby(user_id, chat_id, "API ошибка: #{status}")

      {:error, error} ->
        IO.inspect(error, error_handler_label: "OpenRouter Network Error")
        send_error_to_lobby(user_id, chat_id, "Сетевая ошибка")
    end
  end

  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_stream_error, %{chat_id: chat_id, reason: reason}}
    )
  end

  # --- Вспомогательный запуск супервизора ---

  defp ensure_started(chat_id) do
    case Registry.lookup(Messenger.AgentRegistry, chat_id) do
      [{_pid, _}] -> :ok
      [] ->
        DynamicSupervisor.start_child(Messenger.AiSupervisor, {__MODULE__, chat_id})
        :ok
    end
  end
end

defmodule Messenger.Chats.ChatsAgent do
  alias Messenger.Chats

  use GenServer

  @idle_timeout :timer.minutes(15)

  # Точка входа в API ---

  def start_link(chat_id) do
    GenServer.start_link(__MODULE__, chat_id, name: via_tuple(chat_id))
  end

  def start_and_process(user_id, chat_id, model, profile, context, summaries, temp_id) do
    case ensure_started(chat_id) do
      :ok ->
        send_message(user_id, chat_id, model, profile, context, summaries, temp_id)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_message(user_id, chat_id, model, profile, context, summaries, temp_id) do
    GenServer.cast(via_tuple(chat_id), {:process, user_id, model, profile, context, summaries, temp_id})
  end

  def stop_generation(chat_id) do
    GenServer.cast(via_tuple(chat_id), :stop_generation)
  end

  defp via_tuple(chat_id), do: {:via, Registry, {Messenger.AgentRegistry, chat_id}}

  # GenServer Callbacks

  @impl true
  def init(chat_id) do
    {:ok, %{
      chat_id: chat_id,
      queue: :queue.new(),
      processing: false,
      current_task_pid: nil,
      task_ref: nil
    }, @idle_timeout}
  end

  @impl true
  def handle_cast({:process, user_id, model, profile, context, summaries, temp_id}, state) do
    new_queue = :queue.in({user_id, model, profile, context, summaries, temp_id}, state.queue)

    new_state =
      if state.processing do
        IO.inspect("⏳ Уже идет обработка, добавили сообщение в очередь")
        %{state | queue: new_queue}
      else
        IO.inspect("🚀 Запускаем обработку из очереди")
        process_next_message(%{state | queue: new_queue})
      end

    {:noreply, new_state, @idle_timeout}
  end

  @impl true
  def handle_cast(:stop_generation, state) do
    if state.processing && state.current_task_pid do
      IO.inspect("🛑 Посылаем команду :stop в Task")
      send(state.current_task_pid, :stop)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:next, state) do
    {:noreply, process_next_message(state), @idle_timeout}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    if state.task_ref == ref do
      IO.inspect("🥳 Task завершен (штатно или остановлен). Сбрасываем состояние.")

      new_state = %{state |
        processing: false,
        current_task_pid: nil,
        task_ref: nil
      }

      {:noreply, process_next_message(new_state), @idle_timeout}
    else
      {:noreply, state, @idle_timeout}
    end
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

  @doc"""
  HELPER ---------------------------------> Логика очереди
  """
  defp process_next_message(%{queue: queue, chat_id: chat_id} = state) do
    case :queue.out(queue) do
      {{:value, {user_id, model, profile, context, summaries, temp_id}}, new_queue} ->
        case DynamicSupervisor.start_child(
               Messenger.AiSupervisor,
               {Task, fn ->
                 try do
                   process_stream(user_id, chat_id, model, profile, context, summaries, temp_id)
                 rescue
                   e ->
                     IO.inspect(e, label: "🤬 Критический сбой при обработке запроса")
                     send_error_to_lobby(user_id, chat_id, model.id, "😮 Внутренняя ошибка бэкенда")
                 after
                   GenServer.cast(via_tuple(chat_id), :next)
                 end
               end}
             ) do
          {:ok, task_pid} ->
            ref = Process.monitor(task_pid)

            %{state |
              queue: new_queue,
              processing: true,
              current_task_pid: task_pid,
              task_ref: ref
            }

          {:error, reason} ->
            IO.inspect(reason, label: "😕 Не удалось запустить Task")
            send_error_to_lobby(user_id, chat_id, model.id, " 😕 Не удалось запустить обработку")
            process_next_message(%{state | queue: new_queue})
        end

      {:empty, new_queue} ->
        %{state | queue: new_queue, processing: false}
    end
  end

  @doc"""
  PROCESS STREAM ---------------------------------> Главная функция стрима! Единоразово try...after на весь процесс
  """

  defp process_stream(user_id, chat_id, model, profile, context, summaries, temp_id) do
    # Инициализируем состояние в начале
    Process.put(:sse_buffer, "")
    Process.put(:full_content, "")
    Process.put(:final_usage, %{})
    Process.put(:status, :streaming)

    # Собираем весь текст промпта (system prompt + context messages) и считаем его длину для грубого подсчета токенов
    system_prompt = profile.prompt.content

    all_text =
      [%{role: "system", content: system_prompt <> "\n\n" <> summaries} | context]
      |> Enum.map(fn msg -> msg.content end)
      |> Enum.join("\n")

    # ========================> Считаем токены на вход модели
    estimated_prompt_tokens = ceil(String.length(all_text) / 2) || 0
    prompt_tokens_dec = Decimal.new(estimated_prompt_tokens) || "0.0"
    cost_per_1m_input = model.cost_per_1m_input || "0.0"
    estimated_prompt_cost = Decimal.div(Decimal.mult(cost_per_1m_input, prompt_tokens_dec), Decimal.new(1_000_000))

    # Для логов!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    IO.inspect(estimated_prompt_tokens, label: "Грубая оценка -------------> #{estimated_prompt_tokens}")
    IO.inspect(prompt_tokens_dec, label: "Грубая оценка -------------> #{prompt_tokens_dec}")
    IO.inspect(cost_per_1m_input, label: "Грубая оценка -------------> #{cost_per_1m_input}")
    IO.inspect(estimated_prompt_cost, label: "Грубая оценка -------------> #{estimated_prompt_cost}")

    # Сохраняем в Process dictionary
    Process.put(:estimated_prompt_tokens, estimated_prompt_tokens)
    Process.put(:estimated_prompt_cost, estimated_prompt_cost)


    # Запускаем цикл с retry. Он вернет результат. Потом добавлю фолбэк на смену модели и разобью этого монстра на несколько частей
    final_result = fetch_with_retry(user_id, chat_id, model, profile, context, summaries, temp_id, 1)

    try do
      case final_result do
        {:ok, full_content, usage} ->
          Process.put(:status, :completed)
          save_completed_message(user_id, chat_id, model, full_content, usage, temp_id)

        {:halted, full_content} ->
          # Пользователь нажал "Стоп"
          if String.length(full_content || "") > 0 do
            save_aborted_message(user_id, chat_id, model, full_content, temp_id)
          else
            send_aborted_empty(user_id, chat_id, model, temp_id)
          end

        {:error, reason} ->
          IO.inspect(reason, label: "OpenRouter streaming error")
          send_error_to_lobby(user_id, chat_id, model.id, reason)
      end
    after
      # Сработает единожды в конце, после всех попыток
      Process.delete(:sse_buffer)
      Process.delete(:full_content)
      Process.delete(:final_usage)
      Process.delete(:status)
    end
  end

  @doc"""
  HELPER ---------------------------------> Цикл повторных попыток отправки запроса
  """
  defp fetch_with_retry(user_id, chat_id, model, profile, context, summaries, temp_id, attempt) do
    max_attempts = 3

    case single_request(user_id, chat_id, model, profile, context, summaries, temp_id) do
      {:retry, reason} ->
        if attempt < max_attempts do
          delay = :timer.seconds(:math.pow(2, attempt - 1) |> round())
          IO.inspect("⚠️ #{reason}. Retry #{attempt}/#{max_attempts} через #{delay}ms")
          Process.sleep(delay)

          # Очищаем буферы перед новой попыткой, чтобы старые данные не смешивались
          Process.put(:sse_buffer, "")
          Process.put(:full_content, "")
          Process.put(:final_usage, %{})

          fetch_with_retry(user_id, chat_id, model, profile, context, summaries, temp_id, attempt + 1)
        else
          IO.inspect("❌ Превышен лимит retry: #{reason}")
          {:error, "Сервис временно недоступен. Попробуйте позже."}
        end

      {:ok, full_content, usage} ->
        {:ok, full_content, usage}

      {:halted, full_content} ->
        {:halted, full_content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc"""
  HELPER ---------------------------------> Запрос к поставщику услуг
  """
  defp single_request(user_id, chat_id, model, profile, context, summaries, temp_id) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]
    system_prompt = profile.prompt.content

    body = %{
             model: model.openrouter_model_id,
             messages: [%{role: "system", content: system_prompt <> "\n\n" <> summaries} | context],
             temperature: profile.temperature,
             top_p: profile.top_p,
             frequency_penalty: profile.frequency_penalty,
             presence_penalty: profile.presence_penalty,
             max_tokens: profile.max_completion_tokens,
             stream: true,
             stream_options: %{include_usage: true}
           }
           |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
           |> Enum.into(%{})

    try do
      response = Req.post!(url,
        json: body,
        auth: {:bearer, api_key},
        finch: [name: Messenger.OpenRouterFinch],
        receive_timeout: 30_000,
        headers: [
          {"HTTP-Referer", "https://your-monorepo-app.com"},
          {"X-Title", "Phoenix Svelte Chat"}
        ],
        into: fn
          {:data, data}, {req, resp} ->
            receive do
              :stop ->
                IO.inspect("🛑 Получена команда :stop в into callback. Останавливаем Req.")
                :halt
            after
              0 ->
                buffer = Process.get(:sse_buffer, "") <> data
                parts = String.split(buffer, "\n\n")
                {events, rest} = Enum.split(parts, -1)
                Process.put(:sse_buffer, List.first(rest) || "")

                Enum.each(events, &process_sse_event(&1, user_id, chat_id, model, temp_id))
                {:cont, {req, resp}}
            end

          _, {req, resp} ->
            {:cont, {req, resp}}
        end
      )

      cond do
        response.status == 429 or (response.status >= 500 and response.status < 600) ->
          {:retry, "HTTP #{response.status}"}

        response.status == 200 ->
          full_content = Process.get(:full_content, "")
          if String.trim(full_content) == "" do
            {:retry, "Пустой ответ от модели"}
          else
            {:ok, full_content, Process.get(:final_usage, %{})}
          end

        true ->
          {:error, "Неожиданный HTTP статус: #{response.status}"}
      end
    rescue
      e in ArgumentError ->
        # Чекнем а был ли это штатный :halt от команды :stop
        if Process.get(:status) == :streaming do
          {:halted, Process.get(:full_content, "")}
        else
          {:error, "ArgumentError при стриминге: #{inspect(e)}"}
        end
      e ->
        {:error, "Ошибка при стриминге: #{inspect(e)}"}
    end
  end

  @doc"""
  HELPER ---------------------------------> Сохраняет завершившийся удачей запрос
  """
  defp save_completed_message(user_id, chat_id, model, full_content, usage, temp_id) do
    cost_details = usage["cost_details"] || %{}

    case Chats.create_assistant_message(%{
      chat_id: chat_id,
      ai_model_id: model.id,
      content: full_content,
      role: "assistant",
      tokens_prompt: usage["prompt_tokens"] || 0,
      tokens_completion: usage["completion_tokens"] || 0,
      tokens_total: usage["total_tokens"] || 0,
      cost_prompt: cost_details["upstream_inference_prompt_cost"] || 0.0,
      cost_completion: cost_details["upstream_inference_completions_cost"] || 0.0,
      cost_total: usage["cost"] || 0.0,
      is_aborted: false,
    }) do
      {:ok, %{message: inserted_message}} ->
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, message_id: inserted_message.id, ai_model_id: inserted_message.ai_model_id, content: full_content, last_message: String.slice(full_content, 0, 100)}}
        )
      {:error, reason} ->
        IO.inspect(reason, label: "DB Save Error")
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, client_msg_id: temp_id, content: full_content}}
        )
    end
  end


  @doc"""
  HELPER ---------------------------------> Сохраняет завершившийся неудачей запрос
  """
  defp save_aborted_message(user_id, chat_id, model, full_content, temp_id) do
    estimated_prompt_tokens = Process.get(:estimated_prompt_tokens, 0)
    estimated_prompt_cost = Process.get(:estimated_prompt_cost, 0.0)

    estimated_completion_tokens = ceil(String.length(full_content) / 2) || 0
    completion_tokens_dec = Decimal.new(estimated_completion_tokens) || "0.0"
    cost_per_1m_output = model.cost_per_1m_output || Decimal.new(0) || "0.0"
    estimated_cost_completion = Decimal.div(Decimal.mult(cost_per_1m_output, completion_tokens_dec), Decimal.new(1_000_000)) || "0.0"
    estimated_cost_total = Decimal.add(estimated_prompt_cost, estimated_cost_completion)

    case Chats.create_assistant_message(%{
      chat_id: chat_id,
      ai_model_id: model.id,
      content: full_content,
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
          {:ai_stream_done, %{chat_id: chat_id, client_msg_id: temp_id, message_id: inserted_message.id, ai_model_id: inserted_message.ai_model_id, content: full_content, last_message: String.slice(full_content, 0, 100), is_aborted: true}}
        )
      {:error, reason} ->
        IO.inspect(reason, label: "😡 ОШИБКА СОХРАНЕНИЯ В БД ПРИ ОТМЕНЕ ГЕНЕРАЦИИ")
        Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: chat_id, ai_model_id: model.id, client_msg_id: temp_id, content: full_content, is_aborted: true}}
        )
    end
  end

  defp send_aborted_empty(user_id, chat_id, model, temp_id) do
    Phoenix.PubSub.broadcast(Messenger.PubSub, "user:#{user_id}:lobby",
      {:ai_stream_done, %{chat_id: chat_id, client_msg_id: temp_id, ai_model_id: model.id, content: "", is_aborted: true, error: true}}
    )
  end


  @doc"""
  HELPER ---------------------------------> Процесс стрима на фронт чанков ответа модели
  """
  defp process_sse_event(event, user_id, chat_id, model, temp_id) do
    event = String.trim(event)

    cond do
      String.starts_with?(event, "data: ") ->
        data = String.replace_prefix(event, "data: ", "")

        case Jason.decode(data) do
          {:ok, json} ->
            if usage = json["usage"] do
              Process.put(:final_usage, %{
                "prompt_tokens" => usage["prompt_tokens"],
                "completion_tokens" => usage["completion_tokens"],
                "total_tokens" => usage["total_tokens"],
                "cost_details" => usage["cost_details"],
                "cost" => usage["cost"]
              })
            end

            choices = json["choices"] || []

            case choices do
              [%{"delta" => %{"content" => content}} | _] when is_binary(content) ->
                current = Process.get(:full_content, "")
                new_content = current <> content
                Process.put(:full_content, new_content)

                Phoenix.PubSub.broadcast(
                  Messenger.PubSub,
                  "user:#{user_id}:lobby",
                  {:ai_token, %{chat_id: to_string(chat_id), ai_model_id: model.id, client_msg_id: temp_id, token: content}}
                )

              _ ->
                :ok
            end

          {:error, _} ->
            :ok
        end

      event == "data: [DONE]" ->
        :ok

      true ->
        :ok
    end
  end

  defp send_error_to_lobby(user_id, chat_id, ai_model_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_stream_error, %{chat_id: chat_id, ai_model_id: ai_model_id, reason: reason}}
    )
  end

  defp ensure_started(chat_id) do
    case Registry.lookup(Messenger.AgentRegistry, chat_id) do
      [{_pid, _}] ->
        :ok

      [] ->
        case DynamicSupervisor.start_child(Messenger.AiSupervisor, {__MODULE__, chat_id}) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            IO.inspect(reason, label: "😭 Не удалось запустить ChatsAgent")
            {:error, reason}
        end
    end
  end
end
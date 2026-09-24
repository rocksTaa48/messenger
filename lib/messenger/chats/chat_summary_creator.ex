defmodule Messenger.Chats.ChatSummaryCreator do
  require Logger

  alias Messenger.Chats

  @max_attempts 3

  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_generation(user_id, chat_id, ai_model, ai_profile, %{context: context, last_msg_id: last_msg_id}) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(user_id, chat_id, ai_model, ai_profile, %{
        context: context,
        last_msg_id: last_msg_id
      })
    end)
  end

  # Основной оркестратор процесса.
  defp process_generation(user_id, chat_id, ai_model, ai_profile, %{
    context: context,
    last_msg_id: last_msg_id
  }) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    prompt_content = ai_profile.prompt.content
    model = ai_model.openrouter_model_id

    body =
      %{
        model: model,
        messages: [%{role: "system", content: prompt_content} | context],
        temperature: ai_profile.temperature,
        top_p: ai_profile.top_p,
        frequency_penalty: ai_profile.frequency_penalty,
        presence_penalty: ai_profile.presence_penalty,
        max_tokens: ai_profile.max_completion_tokens
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case fetch_with_retry(url, api_key, body, 1) do
      {:ok, summary_content, usage} ->
        handle_successful_generation(user_id, chat_id, summary_content, usage, last_msg_id)

      {:error, {:max_retries_exceeded, reason}} ->
        log_error(user_id, chat_id, "не удалось после #{@max_attempts} попыток: #{reason}")

      {:error, {:no_content, finish_reason}} ->
        log_error(
          user_id,
          chat_id,
          "модель вернула пустой content (finish_reason=#{finish_reason}). " <>
          "Увеличь max_completion_tokens или смени модель на не-reasoning"
        )

      {:error, reason} ->
        log_error(user_id, chat_id, "ошибка: #{inspect(reason)}")
    end
  end

  # Рекурсивный HTTP-запрос с ретраями (1с, 2с).
  # Ретраим только 429, 5xx и сетевые ошибки.
  defp fetch_with_retry(url, api_key, body, attempt) do
    case Req.post(url, req_options(api_key, body)) do
      # Успешный ответ OpenRouter — берём content и usage
      {:ok,
        %Req.Response{
          status: 200,
          body: %{
            "choices" => [%{"message" => %{"content" => content}} | _],
            "usage" => usage
          }
        }}
      when is_binary(content) and content != "" ->
        {:ok, content, usage}

      # 200, но content пустой/отсутствует — смотрим finish_reason
      {:ok,
        %Req.Response{
          status: 200,
          body: %{"choices" => [%{"finish_reason" => finish_reason} | _]}
        }} ->
        {:error, {:no_content, finish_reason}}

      # 200, но структура тела совсем другая
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:error, {:unexpected_response, body}}

      # 429 — слишком много запросов
      {:ok, %Req.Response{status: 429}} ->
        handle_retry(url, api_key, body, attempt, "HTTP 429 Too Many Requests")

      # 5xx — серверные ошибки
      {:ok, %Req.Response{status: status}} when status in 500..599 ->
        handle_retry(url, api_key, body, attempt, "HTTP #{status}")

      # Остальные 4xx — ретраить бессмысленно
      {:ok, %Req.Response{status: status}} when status in 400..499 ->
        {:error, "HTTP #{status}"}

      # Сетевые ошибки и таймауты
      {:error, reason} ->
        handle_retry(url, api_key, body, attempt, "Network error: #{inspect(reason)}")
    end
  end

  # Повторные вызовы.
  defp handle_retry(url, api_key, body, attempt, reason_msg) do
    if attempt < @max_attempts do
      delay = attempt * 1000
      Logger.warning("ChatSummaryCreator: #{reason_msg}. Retry #{attempt}/#{@max_attempts} через #{delay}мс")
      Process.sleep(delay)
      fetch_with_retry(url, api_key, body, attempt + 1)
    else
      Logger.error("ChatSummaryCreator: превышен лимит попыток (#{@max_attempts}). Последняя причина: #{reason_msg}")
      {:error, {:max_retries_exceeded, reason_msg}}
    end
  end

  # Опции для Req.
  defp req_options(api_key, body) do
    [
      json: body,
      auth: {:bearer, api_key},
      finch: [name: Messenger.OpenRouterFinch],
      receive_timeout: 30_000,
      headers: [
        {"HTTP-Referer", "https://your-monorepo-app.com"},
        {"X-Title", "Phoenix Svelte Chat"}
      ]
    ]
  end

  # Сохранение в БД и лог.
  defp handle_successful_generation(user_id, chat_id, summary_content, usage, last_msg_id) do
    # Безопасно извлекаем значения, подставляя нули если нет значения
    prompt_tokens = Map.get(usage, "prompt_tokens", 0)
    completion_tokens = Map.get(usage, "completion_tokens", 0)
    total_tokens = Map.get(usage, "total_tokens", 0)

    # OpenRouter может и не вернуть нихрена ставим дефолт 0.0
    cost_prompt = Map.get(usage, "cost_prompt", 0.0)
    cost_completion = Map.get(usage, "cost_completion", 0.0)
    cost_total = Map.get(usage, "cost", 0.0)

    case Chats.create_summary(%{
      chat_id: chat_id,
      content: summary_content,
      summarized_up_to_message_id: last_msg_id,
      tokens_prompt: prompt_tokens,
      tokens_completion: completion_tokens,
      tokens_total: total_tokens,
      cost_prompt: cost_prompt,
      cost_completion: cost_completion,
      cost_total: cost_total
    }) do
      {:ok, _summary} ->
        Logger.info("Summary AI successful user=#{user_id} chat=#{chat_id} tokens=#{total_tokens}")

      {:error, changeset} ->
        log_error(user_id, chat_id, "changeset: #{inspect(changeset.errors)}")
    end
  end

  # Логирование ошибок.
  defp log_error(user_id, chat_id, reason) do
    Logger.error("Summary AI error user=#{user_id} chat=#{chat_id}: #{reason}")
  end
end
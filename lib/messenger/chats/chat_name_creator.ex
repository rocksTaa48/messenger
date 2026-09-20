defmodule Messenger.Chats.ChatNameCreator do
  alias Messenger.Chats

  @max_attempts 3

  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_generation(user_id, chat_id, ai_model, ai_profile, text) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(user_id, chat_id, ai_model, ai_profile, text)
    end)
  end

  @doc """
  HELPER Основной оркестратор процесса.
  """
  defp process_generation(user_id, chat_id, ai_model, ai_profile, text) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]
    content = ai_profile.prompt.content

    body =
      %{
        model: ai_model.openrouter_model_id,
        messages: [
          %{role: "system", content: content},
          %{role: "user", content: text}
        ],
        temperature: ai_profile.temperature,
        top_p: ai_profile.top_p,
        frequency_penalty: ai_profile.frequency_penalty,
        presence_penalty: ai_profile.presence_penalty,
        max_tokens: ai_profile.max_completion_tokens
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case fetch_with_retry(url, api_key, body, 1) do
      {:ok, generated_title} ->
        handle_successful_generation(user_id, chat_id, generated_title)

      {:error, {:max_retries_exceeded, reason}} ->
        send_error_to_lobby(
          user_id,
          chat_id,
          "Не удалось после #{@max_attempts} попыток: #{reason}"
        )

      {:error, reason} ->
        send_error_to_lobby(user_id, chat_id, "Ошибка: #{inspect(reason)}")
    end
  end

  @doc """
  HELPER Рекурсивный HTTP-запрос с ретраями (1с, 2с).
  Ретраим только 429, 5xx и сетевые ошибки.
  """
  defp fetch_with_retry(url, api_key, body, attempt) do
    case Req.post(url, req_options(api_key, body)) do
      # Успешный ответ OpenRouter
      {:ok, %Req.Response{
        status: 200,
        body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}
      }

      when is_binary(content) -> # is_binary это доп проверка что в content лежит строка или конструкция
        {:ok, content}

      # Успешный статус, но ответ неожиданный
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:error, {:unexpected_response, body}}

      # 429 — слишком много запросов, ретраим
      {:ok, %Req.Response{status: 429}} ->
        handle_retry(url, api_key, body, attempt, "HTTP 429 Too Many Requests")

      # 5xx — серверные ошибки, ретраим
      {:ok, %Req.Response{status: status}} when status in 500..599 ->
        handle_retry(url, api_key, body, attempt, "HTTP #{status}")

      # Остальные 4xx — ретраить бессмысленно
      {:ok, %Req.Response{status: status}} when status in 400..499 ->
        {:error, "HTTP #{status}"}

      # Сетевые ошибки и таймауты — ретраим
      {:error, reason} ->
        handle_retry(url, api_key, body, attempt, "Network error: #{inspect(reason)}")
    end
  end

  @doc """
  HELPER Повторные вызовы.
  """
  defp handle_retry(url, api_key, body, attempt, reason_msg) do
    if attempt < @max_attempts do
      delay = attempt * 1000
      IO.inspect("😮 ChatNameCreator: #{reason_msg}. Retry #{attempt}/#{@max_attempts} через #{delay}мс")
      Process.sleep(delay)
      fetch_with_retry(url, api_key, body, attempt + 1)
    else
      IO.inspect("🤬 ChatNameCreator: превышен лимит попыток (#{@max_attempts}). Последняя причина: #{reason_msg}")
      {:error, {:max_retries_exceeded, reason_msg}}
    end
  end

  @doc """
  HELPER Формирует опции для Req.
  """
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

  @doc """
  HELPER Сохранение в БД и уведомление на фронт.
  """
  defp handle_successful_generation(user_id, chat_id, generated_title) do
    safe_title = String.slice(generated_title, 0, 99)

    case Chats.update_chat(chat_id, user_id, %{title: safe_title}) do
      {:ok, _chat} ->
        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:chat_title_update, %{chat_id: chat_id, title: safe_title}}
        )

      {:error, changeset} ->
        send_error_to_lobby(user_id, chat_id, "DB error: #{inspect(changeset.errors)}")
    end
  end

  @doc """
  HELPER Уведомление об ошибке.
  """
  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:chat_title_error, %{chat_id: chat_id, reason: reason}}
    )
  end
end
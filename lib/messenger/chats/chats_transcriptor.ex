defmodule Messenger.Chats.ChatsTranscriptor do
alias Messenger.AiProfiles
alias Messenger.Chats
  @max_retries 3
  @doc """
  Точка входа. Запускает задачу в фоне.
  """
  def start_transcription(current_user, chat_id, ai_model, temp_id, base64, format) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(current_user, chat_id, ai_model, temp_id, base64, format)
    end)
  end

  @doc """
  HELPER Основной оркестратор процесса.
  """
  defp process_generation(current_user, chat_id, ai_model, temp_id, base64, format) do
    url = "https://openrouter.ai/api/v1/audio/transcriptions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    body = %{
      model: ai_model.openrouter_model_id,
      input_audio: %{
        data: base64,
        format: format
      }
    }

    case fetch_with_retry(url, api_key, body, 1) do
      {:ok, text} ->
        handle_successful_transcription(current_user, chat_id, ai_model, temp_id, text)

      {:error, :max_retries_exceeded, status} ->
        send_error_to_lobby(current_user.id, chat_id, "API ошибка после #{@max_retries} попыток (HTTP #{status})")

      {:error, reason} ->
        send_error_to_lobby(current_user.id, chat_id, "Сетевая ошибка: #{inspect(reason)}")
    end
  end

  @doc """
  HELPER Рекурсивный HTTP-запрос с ретраями (1с, 2с, 3с). Обрабатывает 4xx, 5xx и таймауты.
  """
  defp fetch_with_retry(url, api_key, body, attempt) do
    case Req.post(url, req_options(api_key, body)) do
      # Если успешный ответ
      {:ok, %Req.Response{status: 200, body: %{"text" => text}}} ->
        {:ok, text}

      # Если ошибки HTTP (4xx, 5xx)
      {:ok, %Req.Response{status: status}} when status in 400..599 ->
        handle_retry(url, api_key, body, attempt, "HTTP #{status}")

      # Если пошли сетевые ошибки и таймауты или Req ошибки
      {:error, reason} ->
        handle_retry(url, api_key, body, attempt, "Network error: #{inspect(reason)}")
    end
  end

  @doc """
  HELPER Повторный вызовы.
  """
  defp handle_retry(url, api_key, body, attempt, reason_msg) do
    if attempt < @max_retries do
      delay = attempt * 1000 # 1000, 2000, 3000 мс
      IO.inspect("⚠️ Транскрипция: #{reason_msg}. Retry #{attempt}/#{@max_retries} через #{delay}мс")
      Process.sleep(delay)
      # Рекурсивный вызов с увеличенным счетчиком попыток
      fetch_with_retry(url, api_key, body, attempt + 1)
    else
      IO.inspect("❌ Транскрипция: Превышен лимит ретраев (#{@max_retries}). Последняя причина: #{reason_msg}")
      {:error, :max_retries_exceeded, reason_msg}
    end
  end

  @doc """
  HELPER Формирует опции для Req, немного разгрузим основную функцию.
  """
  defp req_options(api_key, body) do
    [
      json: body,
      auth: {:bearer, api_key},
      finch: [name: Messenger.OpenRouterFinch],
      receive_timeout: 90_000,
      headers: [
        {"HTTP-Referer", "https://your-monorepo-app.com"},
        {"X-Title", "Phoenix Svelte Chat"}
      ]
    ]
  end

  @doc """
  HELPER Сохранение в БД и уведомление на фронт.
  """
  defp handle_successful_transcription(current_user, chat_id, ai_model, temp_id, text) do
    action =
      if is_nil(chat_id) do
        Chats.ChatsBuilder.create_first_message(current_user, %{"text" => text, "temp_id" => temp_id})
      else
        Chats.ChatsBuilder.create_message_in_chat(current_user, %{"text" => text, "chat_id" => chat_id, "temp_id" => temp_id})
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
            text: text,
            ai_model_id: ai_model.id
          }}
        )

      {:error, changeset} ->
        IO.inspect(changeset, label: "🚨 Ecto Error при сохранении транскрипции")
        send_error_to_lobby(current_user.id, chat_id, "Ошибка сохранения в базу данных")
    end
  end

  @doc """
  HELPER Уведомление об ошибке.
  """
  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_transcript_error, %{chat_id: chat_id, reason: reason}}
    )
  end
end
defmodule Messenger.Chats.ChatSummaryCreator do
  alias Messenger.Chats

  def start_generation(user_id, chat_id, ai_profile, context) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(user_id, chat_id, ai_profile, context)
    end)
  end

  defp process_generation(user_id, chat_id, ai_profile, context) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    body = %{
             model: ai_profile.openrouter_model_id,
             messages: [%{role: "system", content: "Твоя задача — создать краткое, структурированное резюме (Summary)
              для передачи контекста другому ассистенту или для следующей сессии.
              Требования к резюме:
              1. Определи основную цель диалога (чего хочет пользователь).
              2. Перечисли важные данные, имена, даты, цифры или технические детали, которые упоминались.
              3. Опиши, к чему пришли стороны (если решения были).
              4. На каком этапе находится задача/разговор прямо сейчас?
              5. Что нужно сделать дальше? (Если это указано или очевидно).
              Игнорируй 'воду', приветствия и нерелевантные отступления. Пиши от третьего лица.
              Старайся уложиться 9 - 12 предложений."},
               %{role: "user", content: context}],
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
      {:ok, %Req.Response{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}}]}}} ->
        {:ok, _} = Chats.update_chat( chat_id, user_id, %{ summary: content })

        {:ok, %{chat_id: chat_id, summary: content} }

      {:ok, %Req.Response{status: status, body: body}} ->
        IO.inspect({status, body}, label: "OpenRouter HTTP Error")
        send_error_to_lobby(user_id, chat_id, "API ошибка: #{status}")

      {:error, error} ->
        IO.inspect(error, label: "OpenRouter Network Error")
        send_error_to_lobby(user_id, chat_id, "Сетевая ошибка")
    end
  end

  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:chat_title_error, %{chat_id: chat_id, reason: reason}}
    )
  end
end
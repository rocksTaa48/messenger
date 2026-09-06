defmodule Messenger.Chats.ChatNameCreator do
  alias Messenger.Chats

  def start_generation(user_id, chat_id, ai_profile, text) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(user_id, chat_id, ai_profile, text)
    end)
  end

  defp process_generation(user_id, chat_id, ai_profile, text) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    body = %{
             model: ai_profile.openrouter_model_id,
             messages: [%{role: "system", content: "Ты — ассистент для создания названий чатов.
              Проанализируй первое сообщение пользователя.
               Придумай короткое название чата (максимум 3-5 слов).
                Не используй кавычки, не пиши 'Чат о...', просто суть.
                Язык используй тот же на котором написан текст пользователя."},
               %{role: "user", content: text}],
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
        {:ok, _} = Chats.update_chat( chat_id, user_id, %{ title: content })

        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:chat_title_update, %{chat_id: chat_id, title: content}}
        )

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
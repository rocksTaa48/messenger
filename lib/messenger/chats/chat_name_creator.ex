defmodule Messenger.Chats.ChatNameCreator do
  alias Messenger.Chats

  def start_generation(user_id, chat_id, model, ai_profile, text) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(user_id, chat_id, model, ai_profile, text)
    end)
  end

  defp process_generation(user_id, chat_id, model, ai_profile, text) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]
    content = ai_profile.prompt.content

    body = %{
             model: model.openrouter_model_id,
             messages: [%{role: "system", content: content},
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
        safe_title = String.slice(content, 0, 99) # <---- Режем на всякий случай что бы экто не упал
        {:ok, _} = Chats.update_chat( chat_id, user_id, %{ title: safe_title })

        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:chat_title_update, %{chat_id: chat_id, title: safe_title}}
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
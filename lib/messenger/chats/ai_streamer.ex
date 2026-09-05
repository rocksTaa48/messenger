defmodule Messenger.Chats.AiStreamer do
  alias Messenger.Chats

  def start_streaming(user_id, ai_profile, chat, message, context) do
    DynamicSupervisor.start_child(
      Messenger.AiSupervisor,
      {Task, fn -> process_stream(user_id, ai_profile, chat, message, context) end}
    )
  end

  defp process_stream(user_id, ai_profile, chat, message, context) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    body = %{
             model: ai_profile.openrouter_model_id,
             messages: context ++ [%{role: "user", content: message.content}],
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
        {:ok, _} = Chats.create_assistant_message(%{
          chat_id: message.chat_id,
          content: content,
          role: "assistant",
          prompt_tokens: usage["prompt_tokens"],
          completion_tokens: usage["completion_tokens"],
          total_tokens: usage["total_tokens"]
        })

        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: message.chat_id}}
        )

      {:ok, %Req.Response{status: status, body: body}} ->
        IO.inspect({status, body}, label: "OpenRouter HTTP Error")
        send_error_to_lobby(user_id, message.chat_id, "API ошибка: #{status}")

      {:error, error} ->
        IO.inspect(error, label: "OpenRouter Network Error")
        send_error_to_lobby(user_id, message.chat_id, "Сетевая ошибка")
    end
  end

  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_stream_error, %{chat_id: chat_id, reason: reason}}
    )
  end
end
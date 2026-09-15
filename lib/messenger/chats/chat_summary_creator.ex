defmodule Messenger.Chats.ChatSummaryCreator do
  alias Messenger.Chats


  def start_generation(user_id, chat_id, ai_profile, %{summary: summary, context: context, last_msg_id: last_msg_id}) do
    Task.Supervisor.start_child(Messenger.TaskSupervisor, fn ->
      process_generation(user_id, chat_id, ai_profile, %{summary: summary, context: context, last_msg_id: last_msg_id})
    end)
  end

  defp process_generation(user_id, chat_id, ai_profile, %{summary: summary, context: context, last_msg_id: last_msg_id}) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]
    prompt_content = ai_profile.prompt.content
    model = ai_profile.ai_model.openrouter_model_id

    dialogue_text =
      context
      |> Enum.map_join("\n\n", fn m -> "#{m.role}: #{m.content}" end)

    user_content = """
    === СТАРОЕ САММАРИ ===
    #{summary || "(нет)"}
    === КОНЕЦ ===

    === ДИАЛОГ ДЛЯ СЖАТИЯ ===
    #{dialogue_text}
    === КОНЕЦ ===

    Обнови саммари с учётом старого саммари и новых сообщений выше.
    Верни ТОЛЬКО текст обновлённого саммари, без преамбул и вопросов.
    """
    complete_context = [
      %{role: "system", content: prompt_content},
      %{role: "user",   content: user_content}
    ]


    body = %{
             model: model,
             messages: complete_context,
             temperature: ai_profile.temperature,
             top_p: ai_profile.top_p,
             frequency_penalty: ai_profile.frequency_penalty,
             presence_penalty: ai_profile.presence_penalty,
             max_tokens: ai_profile.max_completion_tokens,
           }
           |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
           |> Enum.into(%{})
    IO.inspect(complete_context, label: "CONTEXT SUMMARY")

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
        {:ok, _} = Chats.update_chat( chat_id, user_id, %{ summary: content, summarized_up_to_message_id: last_msg_id })
        {:ok, %{chat_id: chat_id, summary: content} }
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Summary AI error #{status}: #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Summary AI request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
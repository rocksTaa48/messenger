defmodule Messenger.Ai.Stereamer do
  def initial_state, do: %{buffer: "", content: "", usage: %{}}
  @doc """
  Принимает состояние и сырой чанк байтов, возвращает
  {new_state, tokens} — где tokens может быть пустым списком.
  """
  def feed(state, chunk) when is_binary(chunk) do
    buffer = state.buffer <> chunk
    parts = String.split(buffer, "\n\n")
    {events, [rest]} = Enum.split(parts, -1)

    {tokens, usage, append} =
      Enum.reduce(events, {[], state.usage, ""}, &handle_event/2)

    new_state = %{
      state
    | buffer: rest,
      usage: usage,
      content: state.content <> append
    }

    {new_state, Enum.reverse(tokens)}
  end

  defp handle_event(raw, {tokens, usage, append}) do
    case String.trim(raw) do
      "data: [DONE]"      -> {tokens, usage, append}
      "data: " <> payload -> parse(payload, tokens, usage, append)
      _                   -> {tokens, usage, append}
    end
  end

  defp parse(payload, tokens, usage, append) do
    case Jason.decode(payload) do
      {:ok, json} ->
        usage = extract_usage(json, usage)

        case json do
          %{"choices" => [%{"delta" => %{"content" => content}} | _]}
          when is_binary(content) and content != "" ->
            {[content | tokens], usage, append <> content}

          _ ->
            {tokens, usage, append}
        end

      {:error, _} ->
        {tokens, usage, append}
    end
  end

  defp extract_usage(%{"usage" => u}, _prev) when is_map(u) do
    %{
      "prompt_tokens"     => u["prompt_tokens"],
      "completion_tokens" => u["completion_tokens"],
      "total_tokens"      => u["total_tokens"],
      "cost_details"      => u["cost_details"],
      "cost"              => u["cost"]
    }
  end
  defp extract_usage(_, prev), do: prev
end
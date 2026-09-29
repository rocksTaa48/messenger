defmodule Messenger.Ai.Error do
  @moduledoc"""
  Принимает на вход ответ клиента и сериализует его
  """
  # ----------------------------------------------------JSON------------------------------------------------------------
  def classify(%Req.Response{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]} = body})
      when is_binary(content) and content != "" do
    {:ok, %{content: content, usage: body["usage"] || %{}}}
  end
  def classify(%Req.Response{status: 200, body: body}), do: {:error, {:empty_response, body}}
  def classify(resp), do: classify_http(resp)


  # --------------------------------------------------STREAM------------------------------------------------------------
  def classify_stream(%Req.Response{status: 200}, %{halted: false, content: content, usage: usage})
      when is_binary(content) and content != "" do
    {:ok, %{content: content, usage: usage || %{}}}
  end
  def classify_stream(%Req.Response{status: 200}, %{halted: true, content: content})
      when is_binary(content) and content != "" do
    {:halted, content}
  end
  def classify_stream(%Req.Response{status: 200}, %{halted: true}), do: {:halted, ""}
  def classify_stream(%Req.Response{status: 200}, _state), do: {:retry, :empty_response}
  def classify_stream(resp), do: classify_http(resp)
  # -------------------------------------------TRANSCRIPTION------------------------------------------------------------
  def classify_transcription(%Req.Response{status: 200, body: %{"text" => text} = body})
      when is_binary(text) and text != "" do
    {:ok, %{content: text, usage: body["usage"] || %{}}}
  end
  def classify_transcription(%Req.Response{status: 200, body: body}), do: {:error, {:empty_response, body}}
  def classify_transcription(resp), do: classify_http(resp)


  # -----------------------------------------------HTTP-статусы---------------------------------------------------------
  defp classify_http(%Req.Response{status: 429}), do: {:retry, :rate_limited}
  defp classify_http(%Req.Response{status: s}) when s in 500..599, do: {:retry, :server_error}
  defp classify_http(%Req.Response{status: s}) when s in 400..499, do: {:error, {:http, s}}
  defp classify_http({:error, reason}), do: {:retry, {:network_error, reason}}
end
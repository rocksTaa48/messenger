defmodule MessengerWeb.TranscriptionController do
  alias Messenger.Chats
  alias Messenger.AiProfiles
  use MessengerWeb, :controller
    require Logger

  def upload(conn, %{"audio" => %Plug.Upload{} = upload} = params) do
    current_user = conn.assigns.current_user
    temp_id = params["temp_id"]
    chat_id = params["chat_id"]

    ai_model = AiProfiles.get_ai_model(9)
    binary = File.read!(upload.path)
    base64 = Base.encode64(binary)

    format = case upload.content_type do
      "audio/webm" <> _ -> "webm"
      "audio/mp4" <> _  -> "m4a"
      "audio/ogg" <> _  -> "ogg"
      "audio/wav" <> _  -> "wav"
      _ -> "webm"
    end

    case Chats.ChatsTranscriptor.start_transcription(current_user, chat_id, ai_model, temp_id, base64, format) do
      {:ok, pid} ->
        Logger.info("Transcription task started: #{inspect(pid)}")
      {:error, reason} ->
        Logger.error("Failed to start transcription task: #{inspect(reason)}")
    end

    json(conn, %{status: "ok", text: "Endpoint done"})
  end

end
defmodule MessengerWeb.TranscriptionController do
  alias Messenger.Chats.PayloadParams
  alias Messenger.Ai.MessageTranscript
  alias Messenger.AiProfiles
  use MessengerWeb, :controller
    require Logger

  def upload(conn, %{"audio" => %Plug.Upload{} = upload} = params) do
    current_user = conn.assigns.current_user
    is_image_session =
      case Map.get(params, "is_image_session") do
        "true" -> true
        _ -> false
      end
    ai_transcript_model = AiProfiles.get_ai_model(9)
    binary = File.read!(upload.path)
    base64 = Base.encode64(binary)

    format = case upload.content_type do
      "audio/webm" <> _ -> "webm"
      "audio/mp4" <> _  -> "m4a"
      "audio/ogg" <> _  -> "ogg"
      "audio/wav" <> _  -> "wav"
      _ -> "webm"
    end

    profile_overrides = case Map.get(params, "profile_overrides") do
      map when is_map(map) -> map
      string when is_binary(string) -> Jason.decode!(string)
      _ -> %{}
    end

    precompleted_params = %{
      "temp_id"             => params["temp_id"],
      "chat_id"             => params["chat_id"],
      "ai_model_id"         => params["ai_model_id"],
      "is_audio"            => true,
      "is_image_session"    => is_image_session,
      "base64"              => base64,
      "format"              => format,
      "ai_transcript_model_id" => ai_transcript_model.id,
      "profile_overrides"   => profile_overrides
    }

    with {:ok, data} <- PayloadParams.build(precompleted_params),
         {:ok, pid} <- MessageTranscript.start_generation(current_user, data) do
        Logger.info("Transcription task started: #{inspect(pid)}")
        json(conn, %{status: "ok", text: "Endpoint done"})
    else
      {:error, %Ecto.Changeset{} = cs} ->
        Logger.error("Invalid params: #{inspect(cs.errors)}")
        conn |> put_status(422) |> json(%{status: "error", errors: cs.errors})
      {:error, reason} ->
        Logger.error("Failed to start transcription: #{inspect(reason)}")
        conn |> put_status(500) |> json(%{status: "error"})
    end
  end
end
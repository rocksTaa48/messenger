defmodule MessengerWeb.ImageController do
  use MessengerWeb, :controller
  alias Messenger.Telegram.Client

  def download(conn, %{"filepath" => filepath}) do
    filename = List.last(filepath)

    base = Application.fetch_env!(:messenger, :uploads_dir)

    file_path = Path.join(base, filename)

    if File.regular?(file_path) do
      conn
      |> put_resp_content_type(content_type(filename))
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_file(200, file_path)
    else
      send_resp(conn, 404, "Not found: #{file_path}")
    end
  end

  def send_to_telegram(conn, %{"image_url" => image_url}) do
    user = conn.assigns[:current_user]

    if user && user.telegram_id do
      full_url =
        if String.starts_with?(image_url, "http"),
           do: image_url,
           else: "https://simplemessenger.serveousercontent.com#{image_url}"

      case Client.send_photo(user.telegram_id, full_url) do
        :ok ->
          json(conn, %{status: "ok", message: "Изображение отправлено в Telegram"})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: "Не удалось отправить изображение", details: inspect(reason)})
      end
    else
      conn
      |> put_status(401)
      |> json(%{error: "Unauthorized"})
    end
  end

  defp content_type(name) do
    case Path.extname(name) do
      ".webp" -> "image/webp"
      ".png"  -> "image/png"
      ".jpg"  -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      _       -> "application/octet-stream"
    end
  end
end
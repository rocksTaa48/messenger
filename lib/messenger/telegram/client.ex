defmodule Messenger.Telegram.Client do


  def send_photo(telegram_id, image_url_path) do
    bot_token = Application.get_env(:messenger, :telegram)[:bot_token]
    base_url = "https://api.telegram.org/bot#{bot_token}"
    filename = Path.basename(image_url_path)
    base_dir = Application.fetch_env!(:messenger, :uploads_dir)
    file_path = Path.join(base_dir, filename)

    unless File.exists?(file_path) do
      IO.inspect(file_path, label: "❌ ФАЙЛ НЕ НАЙДЕН НА ДИСКЕ")
      # Явно возвращаем ошибку, чтобы не продолжать выполнение
      throw({:error, "Файл не найден на сервере"})
    end

    url = "#{base_url}/sendPhoto"

    file_binary = File.read!(file_path)

    multipart_form = [
      {"chat_id", to_string(telegram_id)},
      {"caption", "Вот ваше изображение 🎨"},
      {"photo", {file_binary, [filename: filename, content_type: content_type(filename)]}}
    ]

    case Req.post(url, form_multipart: multipart_form) do
      {:ok, %{status: 200, body: %{"ok" => true}}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        IO.inspect(body, label: "❌ ОШИБКА ОТ TELEGRAM API")
        {:error, body["description"] || "Unknown Telegram error"}

      {:error, reason} ->
        IO.inspect(reason, label: "❌ ОШИБКА HTTP ЗАПРОСА (Req)")
        {:error, reason}
    end
  end

  defp content_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".webp" -> "image/webp"
      ".png"  -> "image/png"
      ".jpg"  -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      _       -> "application/octet-stream"
    end
  end
end
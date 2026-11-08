defmodule Messenger.Storage do
  @thumbnail_max_side 1024
  @thumbnail_quality 70
  defp base_dir, do: Application.fetch_env!(:messenger, :uploads_dir)

  def save_image(binary, media_type) do
    storage_key = Ecto.UUID.generate() <> ext_from(media_type)
    path = Path.join(base_dir(), storage_key)

    with :ok <- File.mkdir_p(base_dir()),
         :ok <- File.write(path, binary) do
      {:ok, %{
        storage_key: storage_key,
        path: path,
        url: "/images/generated/#{storage_key}",
        media_type: media_type
      }}
    end
  end

  def save_thumbnail(binary, _media_type) do
    case Image.from_binary(binary) do
      {:ok, image} ->
        try do
          thumb = Image.thumbnail!(image, @thumbnail_max_side)

          thumb_w = Image.width(thumb)
          thumb_h = Image.height(thumb)

          case Image.write(thumb, :memory, suffix: ".webp", quality: @thumbnail_quality) do
            {:ok, webp_binary} ->
              save_image(webp_binary, "image/webp")
              |> case do
                   {:ok, meta} ->
                     {:ok, Map.merge(meta, %{width: thumb_w, height: thumb_h})}
                   {:error, reason} ->
                     {:error, {:webp_encode, reason}}
                 end
            {:error, reason} ->
              {:error, {:webp_encode, reason}}
          end
        rescue
          e -> {:error, {:thumbnail, Exception.message(e)}}
        end

      {:error, reason} ->
        {:error, {:decode, reason}}
    end
  end

  defp ext_from("image/jpeg"), do: ".jpg"
  defp ext_from("image/webp"), do: ".webp"
  defp ext_from("image/png"), do: ".png"
  defp ext_from(_), do: ".png"
end
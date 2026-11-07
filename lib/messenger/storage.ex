defmodule Messenger.Storage do
  @base_dir Path.join([:code.priv_dir(:messenger), "static", "images", "generated"])

  def save_image(binary, media_type) do
    storage_key = Ecto.UUID.generate() <> ext_from(media_type)
    path = Path.join(@base_dir, storage_key)

    with :ok <- File.mkdir_p(@base_dir),
         :ok <- File.write(path, binary) do
      {:ok, %{
        storage_key: storage_key,
        path: path,
        url: "/images/generated/#{storage_key}",
        media_type: media_type
      }}
    end
  end

  defp ext_from("image/jpeg"), do: ".jpg"
  defp ext_from("image/webp"), do: ".webp"
  defp ext_from("image/png"), do: ".png"
  defp ext_from(_), do: ".png"
end
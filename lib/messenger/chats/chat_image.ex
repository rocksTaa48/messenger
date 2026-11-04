defmodule Messenger.Chats.ChatImage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_images" do
    field :metadata, :map, default: %{}
    field :storage_key, :string
    belongs_to :message, Messenger.Chats.Message
    field :parent_image_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_image, attrs) do
    chat_image
    |> cast(attrs, [:metadata, :message_id, :parent_image_id, :storage_key])
    |> validate_required([:storage_key, :message_id])
  end
end

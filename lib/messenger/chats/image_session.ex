defmodule Messenger.Chats.ImageSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "image_sessions" do
    field :overrides, :map, default: %{}
    belongs_to :chat, Messenger.Chats.Chat
    belongs_to :ai_model, Messenger.AiProfiles.AiModel
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(image_session, attrs) do
    image_session
    |> cast(attrs, [:ai_model_id, :chat_id, :overrides])
    |> validate_required([:ai_model_id, :chat_id])
  end
end

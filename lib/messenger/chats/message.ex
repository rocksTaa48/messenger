defmodule Messenger.Chats.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :role, :string
    field :content, :string
    field :status, :string, default: "pending"
    field :error, :string
    field :is_aborted, :boolean
    field :is_audio, :boolean
    field :metadata, :map, default: %{}

    belongs_to :chat, Messenger.Chats.Chat
    belongs_to :ai_model, Messenger.AiProfiles.AiModel

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :role,
      :content,
      :chat_id,
      :ai_model_id,
      :is_aborted,
      :is_audio,
      :metadata])
    |> validate_required([:role, :content, :chat_id, :ai_model_id])
    |> validate_inclusion(:role, ["system", "user", "assistant"])
    |> validate_inclusion(:status, ["pending", "send", "error"])
    |> validate_length(:content, min: 1, max: 16384)
    |> foreign_key_constraint(:chat_id)
  end
end

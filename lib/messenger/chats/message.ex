defmodule Messenger.Chats.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :role, :string
    field :content, :string

    belongs_to :chat, Messenger.Chats.Chat

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :chat_id])
    |> validate_required([:role, :content, :chat_id])
    |> validate_inclusion(:role, ["system", "user", "assistant"])
    |> validate_length(:content, min: 1, max: 1000)
    |> foreign_key_constraint(:chat_id)
  end
end

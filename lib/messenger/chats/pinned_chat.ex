defmodule Messenger.Chats.PinnedChat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pinned_chats" do
    belongs_to :user, Messenger.Accounts.User
    belongs_to :chat, Messenger.Chats.Chat
    belongs_to :group, Messenger.Chats.Group

    timestamps(type: :utc_datetime)
  end

  def changeset(pinned_chat, attrs) do
    pinned_chat
    |> cast(attrs, [:user_id, :chat_id, :group_id])
    |> validate_required([:user_id, :chat_id]) # group_id не чекаем т.к. она может быть nil
    |> foreign_key_constraint(:chat_id)
    |> foreign_key_constraint(:group_id)
  end
end

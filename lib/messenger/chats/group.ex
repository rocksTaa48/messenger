defmodule Messenger.Chats.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "groups" do
    field :title, :string
    belongs_to :user, Messenger.Accounts.User
    has_many :chats, Messenger.Chats.Chat
    has_many :pinned_chats, Messenger.Chats.PinnedChat


    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:title, :user_id])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 1, max: 30)
    |> foreign_key_constraint(:user_id)
  end
end

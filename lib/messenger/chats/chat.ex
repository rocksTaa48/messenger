defmodule Messenger.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chats" do
    field :title, :string
    field :model_name, :string

    belongs_to :user, Messenger.Accounts.User
    belongs_to :ai_profile, Messenger.AiProfiles.AiProfile
    has_many :messages, Messenger.Chats.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:title, :model_name, :user_id, :ai_profile_id])
    |> validate_required([:title, :model_name, :user_id, :ai_profile_id])
    |> validate_length(:title, min: 1, max: 100)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:ai_profile_id)
  end
end

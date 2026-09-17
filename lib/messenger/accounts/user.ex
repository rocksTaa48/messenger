defmodule Messenger.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :telegram_id, :integer
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :role, :string
    field :status, :string, default: "free"
    field :raw_data, :map, default: %{}
    field :profile_overrides, :map, default: %{}

    has_many :groups, Messenger.Chats.Group
    has_many :chats, Messenger.Chats.Chat
    has_many :pinned_chats, Messenger.Chats.PinnedChat
    belongs_to :ai_model, Messenger.AiProfiles.AiModel

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:telegram_id, :username, :first_name, :last_name, :ai_model_id, :phone, :role, :status, :raw_data, :profile_overrides])
    |> validate_required([:telegram_id, :role, :status])
    |> unique_constraint(:telegram_id)
  end
end

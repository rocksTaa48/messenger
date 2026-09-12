defmodule Messenger.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chats" do
    field :title, :string
    field :model_name, :string
    field :summary, :string
    field :summarized_up_to_message_id, :integer
    field :last_message, :string


    belongs_to :user, Messenger.Accounts.User
    belongs_to :ai_profile, Messenger.AiProfiles.AiProfile
    belongs_to :group, Messenger.Chats.Group
    has_many :messages, Messenger.Chats.Message
    has_many :pinned_chats, Messenger.Chats.PinnedChat

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:title,
      :model_name,
      :user_id,
      :ai_profile_id,
      :group_id,
      :summary,
      :summarized_up_to_message_id,
      :last_message,
    ])
    |> validate_required([:user_id])
    |> validate_length(:title, min: 0, max: 100)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:ai_profile_id)
    |> foreign_key_constraint(:group_id)
  end

  def changeset_for_update_last_message(chat, attrs) do
    chat
    |> cast(attrs, [:last_message])
    |> validate_length(:last_message, max: 5000)
  end

  def changeset_for_update_summary(chat, attrs) do
    chat
    |> cast(attrs, [:summary, :summarized_up_to_message_id])
    |> validate_length(:summary, min: 10, max: 8000)
  end
end

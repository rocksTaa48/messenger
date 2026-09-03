defmodule Messenger.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chats" do
    field :title, :string
    field :model_name, :string
    field :summary, :string
    field :summarized_up_to_message_id, :integer

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
    ])
    |> validate_required([:model_name, :user_id, :ai_profile_id])
    |> validate_length(:title, min: 0, max: 100)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:ai_profile_id)
    |> foreign_key_constraint(:group_id)
  end
end

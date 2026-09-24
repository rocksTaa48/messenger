defmodule Messenger.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chats" do
    field :title, :string
    field :summarized_up_to_message_id, :integer
    field :last_message, :string
    field :profile_overrides, :map, default: %{}


    belongs_to :user, Messenger.Accounts.User
    belongs_to :group, Messenger.Chats.Group
    belongs_to :ai_model, Messenger.AiProfiles.AiModel
    has_many :messages, Messenger.Chats.Message
    has_many :pinned_chats, Messenger.Chats.PinnedChat
    has_many :chat_summaries, Messenger.Chats.ChatSummary

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:title,
      :user_id,
      :group_id,
      :ai_model_id,
      :summarized_up_to_message_id,
      :last_message,
      :profile_overrides,
    ])
    |> validate_required([:user_id])
    |> validate_length(:title, min: 0, max: 100)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:group_id)
  end

  def changeset_for_update_last_message_or_model(chat, attrs) do
    chat
    |> cast(attrs, [:last_message, :ai_model_id])
    |> validate_length(:last_message, max: 5000)
  end


  def changeset_for_update_summary(chat, attrs) do
    chat
    |> cast(attrs, [:summarized_up_to_message_id])
  end
end

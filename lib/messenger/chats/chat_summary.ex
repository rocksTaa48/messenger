defmodule Messenger.Chats.ChatSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_summaries" do
    field :metadata, :map
    field :content, :string
    belongs_to :chat, Messenger.Chats.Chat

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_summary, attrs) do
    chat_summary
    |> cast(attrs, [:chat_id, :metadata, :content])
    |> validate_required([:chat_id, :content])
  end
end

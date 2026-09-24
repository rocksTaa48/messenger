defmodule Messenger.Chats.ChatSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_summaries" do
    field :tokens_prompt, :integer
    field :tokens_completion, :integer
    field :tokens_total, :integer
    field :cost_prompt, :decimal
    field :cost_completion, :decimal
    field :cost_total, :decimal
    field :metadata, :map
    field :content, :string
    belongs_to :chat, Messenger.Chats.Chat

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_summary, attrs) do
    chat_summary
    |> cast(attrs, [:chat_id, :tokens_prompt, :tokens_completion, :tokens_total, :cost_prompt, :cost_completion, :cost_total, :metadata, :content])
    |> validate_required([:chat_id, :tokens_prompt, :tokens_completion, :tokens_total, :cost_prompt, :cost_completion, :cost_total, :content])
  end
end

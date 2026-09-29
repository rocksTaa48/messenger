defmodule Messenger.Accounts.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :tokens_prompt, :integer
    field :tokens_completion, :integer
    field :tokens_total, :integer
    field :cost_prompt, :decimal
    field :cost_completion, :decimal
    field :cost_total, :decimal
    field :metadata, :map
    belongs_to :user, Messenger.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:user_id, :tokens_prompt, :tokens_completion, :tokens_total, :cost_prompt, :cost_completion, :cost_total, :metadata])
    |> validate_required([:user_id, :tokens_total])
  end
end

defmodule Messenger.Accounts.Ledger do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ledgers" do
    field :type, :string
    field :amount_credits, :decimal
    field :description, :string
    field :metadata, :map
    belongs_to :user, Messenger.Accounts.User


    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:type, :amount_credits, :description, :metadata])
    |> validate_required([:user_id, :type, :amount_credits])
  end
end

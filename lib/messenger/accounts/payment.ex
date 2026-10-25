defmodule Messenger.Accounts.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payments" do
    field :provider, :string
    field :external_order_id, :string
    field :tx_hash, :string
    field :amount_original, :decimal
    field :currency_original, :string
    field :amount_credits, :decimal
    field :status, :string
    field :metadata, :map
    belongs_to :user, Messenger.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:user_id, :provider, :external_order_id, :tx_hash, :amount_original, :currency_original, :amount_credits, :status, :metadata])
    |> validate_required([:user_id, :provider, :amount_original, :currency_original, :amount_credits, :status])
  end
end

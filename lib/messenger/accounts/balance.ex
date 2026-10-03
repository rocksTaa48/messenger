defmodule Messenger.Accounts.Balance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "balances" do
    field :available, :decimal
    field :reserved, :string
    field :currency_units, :integer
    field :status, :string
    field :metadata, :map
    belongs_to :user, Messenger.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:available, :user_id, :reserved, :currency_units, :status, :metadata])
    |> validate_required([:available])
  end
end

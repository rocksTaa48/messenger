defmodule Messenger.Accounts.Balance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "balances" do
    field :available_credits, :decimal
    field :reserved_credits, :decimal
    field :min_value, :decimal
    field :status, :string
    field :metadata, :map
    belongs_to :user, Messenger.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:available_credits, :user_id, :reserved_credits, :min_value, :status, :metadata])
    |> validate_required([:user_id, :available])
  end
end

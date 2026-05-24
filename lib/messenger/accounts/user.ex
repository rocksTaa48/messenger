defmodule Messenger.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :telegram_id, :integer
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :role, :string
    field :raw_data, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:telegram_id, :username, :first_name, :last_name, :phone, :role, :raw_data])
    |> validate_required([:telegram_id, :role])
    |> unique_constraint(:telegram_id)
  end
end

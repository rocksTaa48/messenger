defmodule Messenger.Repo.Migrations.CreateBalances do
  use Ecto.Migration

  def change do
    create table(:balances) do
      add :available, :decimal, precision: 10, scale: 6
      add :reserved, :decimal, precision: 10, scale: 6
      add :currency_units, :integer, default: 1000 # 1_USDT = 1000_UNITS
      add :status, :string, null: false, default: "enable" # 'enable', 'disable', 'mute'
      add :metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:balances, [:user_id])
  end
end

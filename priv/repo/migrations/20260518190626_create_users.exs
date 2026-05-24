defmodule Messenger.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :telegram_id, :bigint, null: false
      add :username, :string
      add :first_name, :string
      add :last_name, :string
      add :phone, :string
      add :role, :string, null: false, default: "pending"
      add :raw_data, :jsonb

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:telegram_id])
  end
end

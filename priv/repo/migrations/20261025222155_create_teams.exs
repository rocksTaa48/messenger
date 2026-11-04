defmodule Messenger.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false # TEAM_OWNER
      add :title, :string
      add :status, :string
      add :available, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end
    create index(:teams, [:user_id])
    create index(:teams, [:status])
    create index(:teams, [:available])
  end
end

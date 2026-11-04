defmodule Messenger.Repo.Migrations.CreateTeamMembers do
  use Ecto.Migration

  def change do
    create table(:team_members) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :team_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string
      add :spending_limit_credits, :decimal, precision: 16, scale: 8  # Лимит от овнера
      add :spent_amount_credits, :decimal, precision: 16, scale: 8    # Сколько уже потратил

      timestamps(type: :utc_datetime)
    end
    create unique_index(:team_members, [:team_id, :user_id])
    create index(:team_members, [:user_id, :status]) # в каких я командах
    create index(:team_members, [:team_id, :status]) # кто активен в команде
  end
end

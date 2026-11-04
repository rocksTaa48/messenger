defmodule Messenger.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :team_member_id, references(:team_members, on_delete: :nilify_all), null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profiles, [:user_id], where: "team_member_id IS NULL", name: :profiles_one_personal_per_user)
    create index(:profiles, [:team_member_id])
  end
end

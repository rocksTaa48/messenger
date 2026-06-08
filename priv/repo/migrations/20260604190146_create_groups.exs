defmodule Messenger.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :title, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:groups, [:user_id])

    alter table(:chats) do
      add :group_id, references(:groups, on_delete: :delete_all), null: true
    end

    create index(:chats, [:group_id])
  end
end

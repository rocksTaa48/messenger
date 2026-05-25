defmodule Messenger.Repo.Migrations.CreateAiProfiles do
  use Ecto.Migration

  def change do
    create table(:ai_profiles) do
      add :provider, :string
      add :api_key, :string
      add :url, :string
      add :extra, :string
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ai_profiles, [:user_id, :provider])
  end
end

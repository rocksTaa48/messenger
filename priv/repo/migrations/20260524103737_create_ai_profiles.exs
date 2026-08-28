defmodule Messenger.Repo.Migrations.CreateAiProfiles do
  use Ecto.Migration

  def change do
    create table(:ai_profiles) do
      add :name, :string, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :api_key, :binary, null: false
      add :base_url, :string
      add :config, :map, default: %{}

      timestamps(type: :utc_datetime)
    end
  end
end

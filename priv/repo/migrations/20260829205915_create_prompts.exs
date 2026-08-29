defmodule Messenger.Repo.Migrations.CreatePrompts do
  use Ecto.Migration

  def change do
    create table(:prompts) do
      add :name, :string
      add :description, :string
      add :content, :text
      add :version, :integer
      add :is_active, :boolean, default: false, null: false
      add :metadata, :map, default: %{}
      add :ai_profile_id, references(:ai_profiles, on_delete: :nilify_all )


      timestamps(type: :utc_datetime)
    end
    create index(:prompts, [:ai_profile_id])
  end
end

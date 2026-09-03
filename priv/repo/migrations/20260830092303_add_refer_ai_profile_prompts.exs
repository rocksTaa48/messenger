defmodule Messenger.Repo.Migrations.AddReferAiProfilePrompts do
  use Ecto.Migration

  def change do
    alter table(:ai_profiles) do
      add :prompt_id, references(:prompts, on_delete: :nilify_all), null: true
    end
    create index(:ai_profiles, [:prompt_id])
  end
end

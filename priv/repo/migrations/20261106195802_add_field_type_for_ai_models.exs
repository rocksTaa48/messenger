defmodule Messenger.Repo.Migrations.AddFieldTypeForAiModels do
  use Ecto.Migration

  def change do
    alter table(:ai_models) do
      add :type, :string, default: "llm", null: false
    end
    create index(:ai_models, [:type])
  end
end

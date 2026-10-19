defmodule Messenger.Repo.Migrations.AddReferenceMessageAssistantMessageAndColorForAiModel do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :request_id, references(:messages), null: true
    end
    create index(:messages, [:request_id])

    alter table(:ai_models) do
      add :display_color, :string # Типа #000000
    end

  end
end

defmodule Messenger.Repo.Migrations.AddAiModelReferenceToTransactions do
  use Ecto.Migration
  def change do
    alter table(:transactions) do
      add :ai_model_id, references(:ai_models, on_delete: :nilify_all), null: true
    end
    create index(:transactions, [:ai_model_id]) # Индекс для поиска
  end
end

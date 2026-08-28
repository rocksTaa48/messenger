defmodule Messenger.Repo.Migrations.EditMessagesForOpenrouter do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      # Статус
      add :status, :string, default: "pending"
      add :error, :text

      # Токены для учета, только на ответы от модели
      add :tokens_prompt, :integer           # Входные токены
      add :tokens_completion, :integer       # Выходные токены
      add :tokens_total, :integer            # Сумма

      # Стоимость в условных еденицах
      add :cost_prompt, :decimal, precision: 10, scale: 6
      add :cost_completion, :decimal, precision: 10, scale: 6
      add :cost_total, :decimal, precision: 10, scale: 6

      # Метаданные
      add :metadata, :map, default: %{}
    end
    create index(:messages, [:tokens_total])         # Для аналитики
  end
end

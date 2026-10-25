defmodule Messenger.Repo.Migrations.CreateLedgers do
  use Ecto.Migration

  def change do
    create table(:ledgers) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :type, :string # Тип операции
        # "welcome_bonus" - приветственные кредиты
        # "top_up"        - пополнение через крипто или звезды
        # "ai_generation" - списание за использование ИИ
        # "refund"        - возврат... изза ошибки например
        # "bonus"         - промо-начисления, бонусы
      add :amount_credits, :decimal, precision: 16, scale: 8
      add :description, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end
    create index(:ledgers, [:user_id])
    create index(:ledgers, [:type])
    create index(:ledgers, [:inserted_at])
  end
end

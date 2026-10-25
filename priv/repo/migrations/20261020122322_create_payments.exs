defmodule Messenger.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :provider, :string            # "cluster_pay", "ton_pay", "telegram_stars", "manual"
      add :external_order_id, :string   # Внешние идентификаторы ID от шлюза или ID платежа (charge_id) от Telegram
      add :tx_hash, :string
      add :amount_original, :decimal, precision: 16, scale: 8 # 10.00 (USDT) или 500 (Stars)
      add :currency_original, :string                         # Валюта платежа ("USDT", "XTR" для Stars)
      add :amount_credits, :decimal, precision: 16, scale: 8  # Итоговая сумма в кредитах, которую начислим
      add :status, :string
        # Статус жизненного цикла платежа
        # "pending"    - создан, ждем действий от юзера/сети
        # "processing" - крипта в сети / Stars подтверждены ТГ
        # "completed"  - успешно, кредиты начислены в ledgers
        # "failed"     - ошибка шлюза / сети
        # "expired"    - время жизни инвойса вышло
      add :metadata, :map, default: %{}                        # Ну тут может сырые или не очень важные данные

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:external_order_id])      # Один ордер на один паймент
    create index(:payments, [:user_id])
    create index(:payments, [:status])

    alter table(:balances) do
      add :available_credits, :decimal, precision: 16, scale: 8
      add :reserved_credits, :decimal, precision: 16, scale: 8
      add :min_value, :decimal, precision: 16, scale: 8, default: "0.01"
      remove :available
      remove :reserved
      remove :currency_units
    end
    create index(:balances, [:available_credits])
  end
end

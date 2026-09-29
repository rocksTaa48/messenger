defmodule Messenger.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :tokens_prompt, :integer
      add :tokens_completion, :integer
      add :tokens_total, :integer
      add :cost_prompt, :decimal, precision: 10, scale: 6
      add :cost_completion, :decimal, precision: 10, scale: 6
      add :cost_total, :decimal, precision: 10, scale: 6
      add :metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end
    create index(:transactions, [:user_id])

    alter table(:messages) do
      remove :tokens_prompt, :integer
      remove :tokens_completion, :integer
      remove :tokens_total, :integer
      remove :cost_prompt, :decimal, precision: 10, scale: 6
      remove :cost_completion, :decimal, precision: 10, scale: 6
      remove :cost_total, :decimal, precision: 10, scale: 6
    end

    alter table(:chat_summaries) do
      remove :tokens_prompt, :integer
      remove :tokens_completion, :integer
      remove :tokens_total, :integer
      remove :cost_prompt, :decimal, precision: 10, scale: 6
      remove :cost_completion, :decimal, precision: 10, scale: 6
      remove :cost_total, :decimal, precision: 10, scale: 6
    end
  end
end

defmodule Messenger.Repo.Migrations.CreateChatSummaries do
  use Ecto.Migration

  def change do
    create table(:chat_summaries) do
      add :tokens_prompt, :integer
      add :tokens_completion, :integer
      add :tokens_total, :integer
      add :cost_prompt, :decimal
      add :cost_completion, :decimal
      add :cost_total, :decimal
      add :metadata, :map, default: %{}
      add :content, :text, null: false
      add :version_count, :integer
      add :chat_id, references(:chats, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_summaries, [:chat_id])

    alter table(:chats) do
      remove :summary
    end
  end
end

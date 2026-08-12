defmodule Messenger.Repo.Migrations.AddChatsFieldsSummaryAndSummarizedMessageId do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      add :summary, :text, null: true
      add :summarized_up_to_message_id, :bigint, null: true
    end
  end
end

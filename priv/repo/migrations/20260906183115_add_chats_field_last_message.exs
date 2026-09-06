defmodule Messenger.Repo.Migrations.AddChatsFieldLastMessage do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      add :last_message, :text
    end
  end
end

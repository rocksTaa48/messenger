defmodule Messenger.Repo.Migrations.CreatePinnedChats do
  use Ecto.Migration

  def change do
    create table(:pinned_chats, primary_key: false) do
      add :id, :bigserial, primary_key: true

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :chat_id, references(:chats, on_delete: :delete_all, type: :bigint), null: false
      add :group_id, references(:groups, on_delete: :delete_all, type: :bigint), null: true #null true - исп-ся для лобби :ALL

      timestamps(type: :utc_datetime)
    end

    # Индекс для закрепа внутри конкретной ПАПКИ
    create unique_index(:pinned_chats, [:user_id, :chat_id, :group_id],
             where: "group_id IS NOT NULL",
             name: :pinned_chats_group_unique_index)

    # Индекс для глобального закрепа
    create unique_index(:pinned_chats, [:user_id, :chat_id],
             where: "group_id IS NULL",
             name: :pinned_chats_global_unique_index)

    create index(:pinned_chats, [:user_id, :group_id, :inserted_at])
  end
end

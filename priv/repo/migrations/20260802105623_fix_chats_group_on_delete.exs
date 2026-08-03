defmodule Messenger.Repo.Migrations.FixChatsGroupOnDelete do
  use Ecto.Migration

  def change do
      # Удаляем старый внешний ключ
      drop constraint(:chats, "chats_group_id_fkey")

      # Накатываем мод
      alter table(:chats) do
        modify :group_id, references(:groups, on_delete: :nilify_all), null: true
      end
    end
end

defmodule Messenger.Repo.Migrations.CreateChatImages do
  use Ecto.Migration

  def change do
    create table(:chat_images) do
      add :metadata, :map, default: %{}
      add :storage_key, :string
      add :message_id, references(:messages, on_delete: :delete_all)
      add :parent_image_id, references(:chat_images, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_images, [:message_id])
    create index(:chat_images, [:parent_image_id])
  end
end

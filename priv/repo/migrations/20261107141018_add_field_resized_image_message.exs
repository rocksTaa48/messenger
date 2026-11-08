defmodule Messenger.Repo.Migrations.AddFieldResizedImageMessage do
  use Ecto.Migration

  def change do
    alter table(:chat_images) do
      add :thumb_storage_key, :string, default: ""
    end
    create index(:chat_images, [:thumb_storage_key])
  end
end

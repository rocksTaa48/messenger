defmodule Messenger.Repo.Migrations.CreateImageSessions do
  use Ecto.Migration

  def change do
    create table(:image_sessions) do
      add :overrides, :map, default: %{}
      add :chat_id, references(:chats, on_delete: :delete_all)
      add :ai_model_id, references(:ai_models, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end
    create unique_index(:image_sessions, [:chat_id])

    alter table(:chats) do
      add :is_image_session, :boolean, default: false, null: false
    end
    create index(:chats, [:is_image_session])
  end
end

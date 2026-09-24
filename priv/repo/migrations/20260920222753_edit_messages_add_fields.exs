defmodule Messenger.Repo.Migrations.EditMessagesAddFields do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :is_aborted, :boolean, default: false
      add :is_audio, :boolean, default: false
    end
  end
end

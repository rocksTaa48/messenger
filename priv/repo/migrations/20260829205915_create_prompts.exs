defmodule Messenger.Repo.Migrations.CreatePrompts do
  use Ecto.Migration

  def change do
    create table(:prompts) do
      add :name, :string
      add :description, :string
      add :content, :text
      add :version, :integer
      add :is_active, :boolean, default: false, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end
  end
end

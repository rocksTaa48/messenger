defmodule Messenger.Repo.Migrations.CreateAiModels do
  use Ecto.Migration

  def change do
    create table(:ai_models) do
      # Информация о модели
      add :provider, :string            # Служебное поле
      add :model_name, :string          # Служебное имя типа "mistral"
      add :tier, :string, default: "free" # "free" | "premium" | "enterprise"
      add :is_default, :boolean, default: false, null: false
      add :display_name, :string        # Например "GPT-4o Mini"
      add :display_description, :text   # Можно добавить что то вроде "Быстрая и дешевая модель для генерации текстов"
      add :display_icon, :string        # Линк на иконку или название в паршале иконок
      add :openrouter_model_id, :string # Линк на адрес модели в опен роутер
      add :is_active, :boolean, default: false, null: false
      # Стоимость модели
      add :cost_per_1m_input, :decimal, precision: 10, scale: 6, default: 0.0
      add :cost_per_1m_output, :decimal, precision: 10, scale: 6, default: 0.0
      add :cost_currency, :string, default: "USD"
      add :cost_updated_at, :utc_datetime
      add :config, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ai_models, [:provider, :model_name])
    create index(:ai_models, [:openrouter_model_id])
    create index(:ai_models, [:is_active])

    drop unique_index(:ai_profiles, [:provider, :model])
    drop index(:ai_profiles, [:openrouter_model_id])

    alter table(:ai_profiles) do
      remove :openrouter_model_id, :string
      remove :cost_per_1m_input, :decimal, precision: 10, scale: 6, default: 0.0
      remove :cost_per_1m_output, :decimal, precision: 10, scale: 6, default: 0.0
      remove :cost_currency, :string, default: "USD"
      remove :cost_updated_at, :utc_datetime
      remove :provider, :string, null: false
      remove :model, :string, null: false
      remove :is_default_for_tier, :boolean, null: false
      add :is_default, :boolean, null: false, default: false
      add :purpose, :string, default: "public_chats", null: false # Предназначение профиля, для общих чатов, для суммаризации, для нейминга итд
    end
    create index(:ai_profiles, [:purpose, :is_active])
    drop index(:chats, [:ai_profile_id])

    alter table(:chats) do
      remove :model_name, :string
      remove :ai_profile_id, :string
      add :profile_overrides, :map, default: %{}
      add :ai_model_id, references(:ai_models, on_delete: :nilify_all), null: true
    end
    create index(:chats, [:ai_model_id])


    alter table(:messages) do
      add :ai_model_id, references(:ai_models, on_delete: :nilify_all), null: true
    end
    create index(:messages, [:ai_model_id])

    alter table(:users) do
      add :profile_overrides, :map, default: %{}
      add :ai_model_id, references(:ai_models, on_delete: :nilify_all), null: true
    end
    create index(:users, [:ai_model_id])
  end
end

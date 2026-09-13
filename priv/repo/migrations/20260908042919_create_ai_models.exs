defmodule Messenger.Repo.Migrations.CreateAiModels do
  use Ecto.Migration

  def change do
    create table(:ai_models) do
      # Информация о модели
      add :provider, :string
      add :model_name, :string
      add :openrouter_model_id, :string
      add :is_active, :boolean, default: false, null: false
      add :icon, :string
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
      add :ai_model_id, references(:ai_models, on_delete: :nilify_all), null: true
      add :purpose, :string, default: "system_prompt", null: false # Предназначение профиля, для общих чатов, для суммаризации, для нейминга итд
    end

    create index(:ai_profiles, [:ai_model_id])
    create index(:ai_profiles, [:purpose, :is_active])
  end
end

defmodule Messenger.Repo.Migrations.EditAiProfilesForOpenrouter do
  use Ecto.Migration

  def change do
    alter table(:ai_profiles) do
        # Техничка
      add :openrouter_model_id, :string # Уникальный код модели в опенроутере "gpt4o_mini", "claude_35_sonnet"
      add :display_name, :string        # Например "GPT-4o Mini"
      add :display_description, :text   # Можно добавить что то вроде "Быстрая и дешевая модель для генерации текстов"
      add :display_icon, :string        # Линк на иконку или название в паршале иконок
      # Тарифы
      add :tier, :string, default: "free" # "free" | "premium" | "enterprise"
      add :is_default_for_tier, :boolean, default: false
      add :is_active, :boolean, default: true # Активна - Не активна (Для отключения/включения в админке)
      add :is_public, :boolean, default: true # Видна ли модель в UI для пользователя
      # Параметры генерации
      add :temperature, :float, default: 0.6 # Креативность модели
      add :top_p, :float, default: 0.7 # Невероятность/Вероятность слов в ответе
      add :frequency_penalty, :float, default: 0.4 # Штраф за повторяемость слов
      add :presence_penalty, :float, default: 0.4 # Штраф за повторяемость предложений
      add :context_length, :integer, default: 8192 # Максимальное количество токенов в запросе
      add :max_completion_tokens, :integer, null: false, default: 4096 # Максимальное количество токенов в ответе
      # Стоимость модели (подтягиваем воркером)
      add :cost_per_1m_input, :decimal, precision: 10, scale: 6, default: 0.0
      add :cost_per_1m_output, :decimal, precision: 10, scale: 6, default: 0.0
      add :cost_currency, :string, default: "USD"
      add :cost_updated_at, :utc_datetime
      # Если что то не влезло
      add :metadata, :map, default: %{}
      # Удаляем ненужные более поля
      remove :api_key, :binary, null: false
      remove :base_url, :string
      remove :config, :map, default: %{}
    end
    # Добавляем новый уникальный индекс на provider + model что бы один и тот же провайдер не имел одинаковые модели
    create unique_index(:ai_profiles, [:provider, :model])
    # Добавляем индексы для поиска по тарифам и по фйдишнику в роутере типа gpt4o_mini
    create index(:ai_profiles, [:tier, :is_active])
    create index(:ai_profiles, [:openrouter_model_id])
  end
end

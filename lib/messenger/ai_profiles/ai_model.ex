defmodule Messenger.AiProfiles.AiModel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_models" do
    field :provider, :string
    field :model_name, :string
    field :openrouter_model_id, :string
    field :is_active, :boolean, default: false
    field :cost_per_1m_input, :decimal
    field :cost_per_1m_output, :decimal
    field :cost_currency, :string
    field :cost_updated_at, :string
    field :config, :map, default: %{}
    field :tier, :string, default: "free" # "free" | "premium" | "enterprise"
    field :is_default, :boolean, default: false
    field :display_name, :string        # Например "GPT-4o Mini"
    field :display_description, :string   # Можно добавить что то вроде "Быстрая и дешевая модель для генерации текстов"
    field :display_icon, :string        # Линк на иконку или название в паршале иконок

    has_many :messages, Messenger.Chats.Message
    has_many :chats, Messenger.Chats.Chat
    has_many :users, Messenger.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ai_model, attrs) do
    ai_model
    |> cast(attrs, [
      :provider,
      :display_icon,
      :display_name,
      :display_description,
      :tier,
      :is_default,
      :model_name,
      :openrouter_model_id,
      :is_active,
      :cost_per_1m_input,
      :cost_per_1m_output,
      :cost_currency,
      :cost_updated_at,
      :config])
    |> validate_required([:model_name, :openrouter_model_id, :is_active, :tier])
    |> unique_constraint([:provider, :model_name], name: :ai_models_provider_model_name_index)

  end
end

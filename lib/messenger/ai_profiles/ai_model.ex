defmodule Messenger.AiProfiles.AiModel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_models" do
    field :provider, :string
    field :icon, :string, default: ""
    field :model_name, :string
    field :openrouter_model_id, :string
    field :is_active, :boolean, default: false
    field :cost_per_1m_input, :decimal
    field :cost_per_1m_output, :decimal
    field :cost_currency, :string
    field :cost_updated_at, :string
    field :config, :map, default: %{}
    has_many :ai_profiles, Messenger.AiProfiles.AiProfile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ai_model, attrs) do
    ai_model
    |> cast(attrs, [
      :provider,
      :icon,
      :model_name,
      :openrouter_model_id,
      :is_active,
      :cost_per_1m_input,
      :cost_per_1m_output,
      :cost_currency,
      :cost_updated_at,
      :config])
    |> validate_required([:model_name, :openrouter_model_id, :is_active])
    |> unique_constraint([:provider, :model_name], name: :ai_models_provider_model_name_index)

  end
end

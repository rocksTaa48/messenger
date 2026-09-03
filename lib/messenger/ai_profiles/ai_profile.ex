defmodule Messenger.AiProfiles.AiProfile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_profiles" do
    field :name, :string
    field :provider, :string
    field :model, :string
    field :openrouter_model_id, :string
    field :display_name, :string
    field :display_description, :string
    field :display_icon, :string
    field :tier, :string, default: "free"
    field :is_default_for_tier, :boolean, default: false
    field :is_active, :boolean, default: true
    field :is_public, :boolean, default: false
    field :temperature, :float, default: 0.6
    field :top_p, :float, default: 0.7
    field :frequency_penalty, :float, default: 0.4
    field :presence_penalty, :float, default: 0.4
    field :context_length, :integer, default: 8192
    field :max_completion_tokens, :integer, default: 4096
    field :cost_per_1m_input, :decimal
    field :cost_per_1m_output, :decimal
    field :cost_currency, :string, default: "USD"
    field :cost_updated_at, :utc_datetime
    field :metadata, :map, default: %{}

    has_many :chats, Messenger.Chats.Chat
    belongs_to :prompt, Messenger.AiProfiles.Prompt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ai_profile, attrs) do
    changeset =
      ai_profile
      |> cast(attrs, [:name,
        :provider,
        :model,
        :openrouter_model_id,
        :display_name,
        :display_description,
        :display_icon,
        :tier,
        :is_default_for_tier,
        :is_active,
        :is_public,
        :temperature,
        :top_p,
        :frequency_penalty,
        :presence_penalty,
        :context_length,
        :max_completion_tokens,
        :cost_per_1m_input,
        :cost_per_1m_output,
        :cost_currency,
        :cost_updated_at,
        :prompt_id,
        :metadata
      ])

      |> validate_required([:name, :provider, :model, :openrouter_model_id])
      |> validate_length(:name, min: 1, max: 50)
      |> validate_length(:display_description, min: 1, max: 1000)
      |> validate_inclusion(:tier, ["free", "premium", "ultimate"])
      |> unique_constraint([:provider, :model], name: :ai_profiles_provider_model_index)
  end

end

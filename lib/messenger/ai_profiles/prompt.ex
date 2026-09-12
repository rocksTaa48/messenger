defmodule Messenger.AiProfiles.Prompt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "prompts" do
    field :name, :string
    field :description, :string
    field :content, :string
    field :version, :integer
    field :is_active, :boolean, default: false
    field :metadata, :map, default: %{}
    has_many :ai_profiles, Messenger.AiProfiles.AiProfile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(prompt, attrs) do
    prompt
    |> cast(attrs, [:name, :description, :content, :is_active, :version, :metadata])
    |> validate_required([:name, :description, :content, :is_active])
  end
end

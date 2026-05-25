defmodule Messenger.AiProfiles.AiProfile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_prfiles" do
    field :provider, :string
    field :api_key, :string
    field :user_id, :id
    field :url, :string
    field :extra, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ai_profile, attrs) do
    ai_profile
    |> cast(attrs, [:provider, :api_key, :url, :extra])
    |> validate_required([:provider, :api_key])
  end
end

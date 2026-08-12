defmodule Messenger.AiProfiles.AiProfile do
  use Ecto.Schema
  import Ecto.Changeset
  alias Messenger.AiProfiles.AiList

  schema "ai_profiles" do
    field :name, :string
    field :provider, :string
    field :model, :string
    field :api_key, Messenger.EncryptedString
    field :base_url, :string
    field :config, :map, default: %{}

    belongs_to :user, Messenger.Accounts.User
    has_many :chats, Messenger.Chats.Chat


    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ai_profile, attrs) do
    changeset =
      ai_profile
      |> cast(attrs, [:name, :provider, :model, :api_key, :base_url, :config])
      |> validate_required([:name, :provider, :model, :api_key])
      |> validate_inclusion(:provider, AiList.providers())
    validate_change(changeset, :model, fn :model, model ->
      provider = get_field(changeset, :provider)

      if AiList.valid_model?(provider, model) do
        []
      else
        [model: {"is not supported by this provider", [validation: :inclusion]}]
      end
    end)
    |> unique_constraint([:user_id, :provider], name: :ai_profiles_user_id_provider_index)
  end

end

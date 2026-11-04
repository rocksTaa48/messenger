defmodule Messenger.Teams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :title, :string
    field :status, :string
    field :available, :boolean, default: true
    belongs_to :user, Messenger.Accounts.User
    has_many :team_members, Messenger.Teams.TeamMember

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:user_id, :title, :status, :available])
    |> validate_required([:available])
  end
end

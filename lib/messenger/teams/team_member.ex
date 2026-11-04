defmodule Messenger.Teams.TeamMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_members" do
    field :status, :string
    field :spending_limit_credits, :decimal
    field :spent_amount_credits, :decimal
    belongs_to :team, Messenger.Teams.Team
    belongs_to :user, Messenger.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team_member, attrs) do
    team_member
    |> cast(attrs, [:user_id, :team_id, :status, :spending_limit, :spent_amount])
    |> validate_required([:spending_limit, :spent_amount])
  end
end

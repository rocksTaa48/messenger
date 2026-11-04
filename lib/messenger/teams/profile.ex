defmodule Messenger.Teams.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do

    belongs_to :user, Messenger.Accounts.User
    belongs_to :team_member, Messenger.Teams.TeamMember
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:user_id, :team_member_id])
    |> validate_required([:user_id, :team_member_id])
  end
end

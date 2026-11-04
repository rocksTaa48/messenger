defmodule Messenger.TeamsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Messenger.Teams` context.
  """

  @doc """
  Generate a team.
  """
  def team_fixture(attrs \\ %{}) do
    {:ok, team} =
      attrs
      |> Enum.into(%{
        available: true,
        status: "some status",
        title: "some title"
      })
      |> Messenger.Teams.create_team()

    team
  end

  @doc """
  Generate a team_member.
  """
  def team_member_fixture(attrs \\ %{}) do
    {:ok, team_member} =
      attrs
      |> Enum.into(%{
        spending_limit: "120.5",
        spent_amount: "120.5",
        status: "some status"
      })
      |> Messenger.Teams.create_team_member()

    team_member
  end

  @doc """
  Generate a profile.
  """
  def profile_fixture(attrs \\ %{}) do
    {:ok, profile} =
      attrs
      |> Enum.into(%{

      })
      |> Messenger.Teams.create_profile()

    profile
  end
end

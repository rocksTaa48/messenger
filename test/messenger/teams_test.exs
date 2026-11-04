defmodule Messenger.TeamsTest do
  use Messenger.DataCase

  alias Messenger.Teams

  describe "teams" do
    alias Messenger.Teams.Team

    import Messenger.TeamsFixtures

    @invalid_attrs %{status: nil, title: nil, available: nil}

    test "list_teams/0 returns all teams" do
      team = team_fixture()
      assert Teams.list_teams() == [team]
    end

    test "get_team!/1 returns the team with given id" do
      team = team_fixture()
      assert Teams.get_team!(team.id) == team
    end

    test "create_team/1 with valid data creates a team" do
      valid_attrs = %{status: "some status", title: "some title", available: true}

      assert {:ok, %Team{} = team} = Teams.create_team(valid_attrs)
      assert team.status == "some status"
      assert team.title == "some title"
      assert team.available == true
    end

    test "create_team/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Teams.create_team(@invalid_attrs)
    end

    test "update_team/2 with valid data updates the team" do
      team = team_fixture()
      update_attrs = %{status: "some updated status", title: "some updated title", available: false}

      assert {:ok, %Team{} = team} = Teams.update_team(team, update_attrs)
      assert team.status == "some updated status"
      assert team.title == "some updated title"
      assert team.available == false
    end

    test "update_team/2 with invalid data returns error changeset" do
      team = team_fixture()
      assert {:error, %Ecto.Changeset{}} = Teams.update_team(team, @invalid_attrs)
      assert team == Teams.get_team!(team.id)
    end

    test "delete_team/1 deletes the team" do
      team = team_fixture()
      assert {:ok, %Team{}} = Teams.delete_team(team)
      assert_raise Ecto.NoResultsError, fn -> Teams.get_team!(team.id) end
    end

    test "change_team/1 returns a team changeset" do
      team = team_fixture()
      assert %Ecto.Changeset{} = Teams.change_team(team)
    end
  end

  describe "team_members" do
    alias Messenger.Teams.TeamMember

    import Messenger.TeamsFixtures

    @invalid_attrs %{status: nil, spending_limit: nil, spent_amount: nil}

    test "list_team_members/0 returns all team_members" do
      team_member = team_member_fixture()
      assert Teams.list_team_members() == [team_member]
    end

    test "get_team_member!/1 returns the team_member with given id" do
      team_member = team_member_fixture()
      assert Teams.get_team_member!(team_member.id) == team_member
    end

    test "create_team_member/1 with valid data creates a team_member" do
      valid_attrs = %{status: "some status", spending_limit: "120.5", spent_amount: "120.5"}

      assert {:ok, %TeamMember{} = team_member} = Teams.create_team_member(valid_attrs)
      assert team_member.status == "some status"
      assert team_member.spending_limit == Decimal.new("120.5")
      assert team_member.spent_amount == Decimal.new("120.5")
    end

    test "create_team_member/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Teams.create_team_member(@invalid_attrs)
    end

    test "update_team_member/2 with valid data updates the team_member" do
      team_member = team_member_fixture()
      update_attrs = %{status: "some updated status", spending_limit: "456.7", spent_amount: "456.7"}

      assert {:ok, %TeamMember{} = team_member} = Teams.update_team_member(team_member, update_attrs)
      assert team_member.status == "some updated status"
      assert team_member.spending_limit == Decimal.new("456.7")
      assert team_member.spent_amount == Decimal.new("456.7")
    end

    test "update_team_member/2 with invalid data returns error changeset" do
      team_member = team_member_fixture()
      assert {:error, %Ecto.Changeset{}} = Teams.update_team_member(team_member, @invalid_attrs)
      assert team_member == Teams.get_team_member!(team_member.id)
    end

    test "delete_team_member/1 deletes the team_member" do
      team_member = team_member_fixture()
      assert {:ok, %TeamMember{}} = Teams.delete_team_member(team_member)
      assert_raise Ecto.NoResultsError, fn -> Teams.get_team_member!(team_member.id) end
    end

    test "change_team_member/1 returns a team_member changeset" do
      team_member = team_member_fixture()
      assert %Ecto.Changeset{} = Teams.change_team_member(team_member)
    end
  end

  describe "profiles" do
    alias Messenger.Teams.Profile

    import Messenger.TeamsFixtures

    @invalid_attrs %{}

    test "list_profiles/0 returns all profiles" do
      profile = profile_fixture()
      assert Teams.list_profiles() == [profile]
    end

    test "get_profile!/1 returns the profile with given id" do
      profile = profile_fixture()
      assert Teams.get_profile!(profile.id) == profile
    end

    test "create_profile/1 with valid data creates a profile" do
      valid_attrs = %{}

      assert {:ok, %Profile{} = profile} = Teams.create_profile(valid_attrs)
    end

    test "create_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Teams.create_profile(@invalid_attrs)
    end

    test "update_profile/2 with valid data updates the profile" do
      profile = profile_fixture()
      update_attrs = %{}

      assert {:ok, %Profile{} = profile} = Teams.update_profile(profile, update_attrs)
    end

    test "update_profile/2 with invalid data returns error changeset" do
      profile = profile_fixture()
      assert {:error, %Ecto.Changeset{}} = Teams.update_profile(profile, @invalid_attrs)
      assert profile == Teams.get_profile!(profile.id)
    end

    test "delete_profile/1 deletes the profile" do
      profile = profile_fixture()
      assert {:ok, %Profile{}} = Teams.delete_profile(profile)
      assert_raise Ecto.NoResultsError, fn -> Teams.get_profile!(profile.id) end
    end

    test "change_profile/1 returns a profile changeset" do
      profile = profile_fixture()
      assert %Ecto.Changeset{} = Teams.change_profile(profile)
    end
  end
end

defmodule Messenger.AiProfilesTest do
  use Messenger.DataCase

  alias Messenger.AiProfiles

  describe "ai_prfiles" do
    alias Messenger.AiProfiles.AiProfile

    import Messenger.AiProfilesFixtures

    @invalid_attrs %{api_key: nil, provider: nil}

    test "list_ai_prfiles/0 returns all ai_prfiles" do
      ai_profile = ai_profile_fixture()
      assert AiProfiles.list_ai_prfiles() == [ai_profile]
    end

    test "get_ai_profile!/1 returns the ai_profile with given id" do
      ai_profile = ai_profile_fixture()
      assert AiProfiles.get_ai_profile!(ai_profile.id) == ai_profile
    end

    test "create_ai_profile/1 with valid data creates a ai_profile" do
      valid_attrs = %{api_key: "some api_key", provider: "some provider"}

      assert {:ok, %AiProfile{} = ai_profile} = AiProfiles.create_ai_profile(valid_attrs)
      assert ai_profile.api_key == "some api_key"
      assert ai_profile.provider == "some provider"
    end

    test "create_ai_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = AiProfiles.create_ai_profile(@invalid_attrs)
    end

    test "update_ai_profile/2 with valid data updates the ai_profile" do
      ai_profile = ai_profile_fixture()
      update_attrs = %{api_key: "some updated api_key", provider: "some updated provider"}

      assert {:ok, %AiProfile{} = ai_profile} = AiProfiles.update_ai_profile(ai_profile, update_attrs)
      assert ai_profile.api_key == "some updated api_key"
      assert ai_profile.provider == "some updated provider"
    end

    test "update_ai_profile/2 with invalid data returns error changeset" do
      ai_profile = ai_profile_fixture()
      assert {:error, %Ecto.Changeset{}} = AiProfiles.update_ai_profile(ai_profile, @invalid_attrs)
      assert ai_profile == AiProfiles.get_ai_profile!(ai_profile.id)
    end

    test "delete_ai_profile/1 deletes the ai_profile" do
      ai_profile = ai_profile_fixture()
      assert {:ok, %AiProfile{}} = AiProfiles.delete_ai_profile(ai_profile)
      assert_raise Ecto.NoResultsError, fn -> AiProfiles.get_ai_profile!(ai_profile.id) end
    end

    test "change_ai_profile/1 returns a ai_profile changeset" do
      ai_profile = ai_profile_fixture()
      assert %Ecto.Changeset{} = AiProfiles.change_ai_profile(ai_profile)
    end
  end
end

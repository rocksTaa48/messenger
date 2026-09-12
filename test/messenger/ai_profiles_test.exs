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

  describe "prompts" do
    alias Messenger.AiProfiles.Prompt

    import Messenger.AiProfilesFixtures

    @invalid_attrs %{name: nil, version: nil, description: nil, metadata: nil, content: nil, is_active: nil}

    test "list_prompts/0 returns all prompts" do
      prompt = prompt_fixture()
      assert AiProfiles.list_prompts() == [prompt]
    end

    test "get_prompt!/1 returns the prompt with given id" do
      prompt = prompt_fixture()
      assert AiProfiles.get_prompt!(prompt.id) == prompt
    end

    test "create_prompt/1 with valid data creates a prompt" do
      valid_attrs = %{name: "some name", version: 42, description: "some description", metadata: %{}, content: "some content", is_active: true}

      assert {:ok, %Prompt{} = prompt} = AiProfiles.create_prompt(valid_attrs)
      assert prompt.name == "some name"
      assert prompt.version == 42
      assert prompt.description == "some description"
      assert prompt.metadata == %{}
      assert prompt.content == "some content"
      assert prompt.is_active == true
    end

    test "create_prompt/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = AiProfiles.create_prompt(@invalid_attrs)
    end

    test "update_prompt/2 with valid data updates the prompt" do
      prompt = prompt_fixture()
      update_attrs = %{name: "some updated name", version: 43, description: "some updated description", metadata: %{}, content: "some updated content", is_active: false}

      assert {:ok, %Prompt{} = prompt} = AiProfiles.update_prompt(prompt, update_attrs)
      assert prompt.name == "some updated name"
      assert prompt.version == 43
      assert prompt.description == "some updated description"
      assert prompt.metadata == %{}
      assert prompt.content == "some updated content"
      assert prompt.is_active == false
    end

    test "update_prompt/2 with invalid data returns error changeset" do
      prompt = prompt_fixture()
      assert {:error, %Ecto.Changeset{}} = AiProfiles.update_prompt(prompt, @invalid_attrs)
      assert prompt == AiProfiles.get_prompt!(prompt.id)
    end

    test "delete_prompt/1 deletes the prompt" do
      prompt = prompt_fixture()
      assert {:ok, %Prompt{}} = AiProfiles.delete_prompt(prompt)
      assert_raise Ecto.NoResultsError, fn -> AiProfiles.get_prompt!(prompt.id) end
    end

    test "change_prompt/1 returns a prompt changeset" do
      prompt = prompt_fixture()
      assert %Ecto.Changeset{} = AiProfiles.change_prompt(prompt)
    end
  end

  describe "ai_models" do
    alias Messenger.AiProfiles.AiModel

    import Messenger.AiProfilesFixtures

    @invalid_attrs %{config: nil, provider: nil, model_name: nil, openrouter_model_id: nil, is_active: nil, cost_per_1m_input: nil, cost_per_1m_output: nil, cost_currency: nil, cost_updated_at: nil}

    test "list_ai_models/0 returns all ai_models" do
      ai_model = ai_model_fixture()
      assert AiProfiles.list_ai_models() == [ai_model]
    end

    test "get_ai_model!/1 returns the ai_model with given id" do
      ai_model = ai_model_fixture()
      assert AiProfiles.get_ai_model!(ai_model.id) == ai_model
    end

    test "create_ai_model/1 with valid data creates a ai_model" do
      valid_attrs = %{config: %{}, provider: "some provider", model_name: "some model_name", openrouter_model_id: "some openrouter_model_id", is_active: true, cost_per_1m_input: "120.5", cost_per_1m_output: "120.5", cost_currency: "some cost_currency", cost_updated_at: "some cost_updated_at"}

      assert {:ok, %AiModel{} = ai_model} = AiProfiles.create_ai_model(valid_attrs)
      assert ai_model.config == %{}
      assert ai_model.provider == "some provider"
      assert ai_model.model_name == "some model_name"
      assert ai_model.openrouter_model_id == "some openrouter_model_id"
      assert ai_model.is_active == true
      assert ai_model.cost_per_1m_input == Decimal.new("120.5")
      assert ai_model.cost_per_1m_output == Decimal.new("120.5")
      assert ai_model.cost_currency == "some cost_currency"
      assert ai_model.cost_updated_at == "some cost_updated_at"
    end

    test "create_ai_model/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = AiProfiles.create_ai_model(@invalid_attrs)
    end

    test "update_ai_model/2 with valid data updates the ai_model" do
      ai_model = ai_model_fixture()
      update_attrs = %{config: %{}, provider: "some updated provider", model_name: "some updated model_name", openrouter_model_id: "some updated openrouter_model_id", is_active: false, cost_per_1m_input: "456.7", cost_per_1m_output: "456.7", cost_currency: "some updated cost_currency", cost_updated_at: "some updated cost_updated_at"}

      assert {:ok, %AiModel{} = ai_model} = AiProfiles.update_ai_model(ai_model, update_attrs)
      assert ai_model.config == %{}
      assert ai_model.provider == "some updated provider"
      assert ai_model.model_name == "some updated model_name"
      assert ai_model.openrouter_model_id == "some updated openrouter_model_id"
      assert ai_model.is_active == false
      assert ai_model.cost_per_1m_input == Decimal.new("456.7")
      assert ai_model.cost_per_1m_output == Decimal.new("456.7")
      assert ai_model.cost_currency == "some updated cost_currency"
      assert ai_model.cost_updated_at == "some updated cost_updated_at"
    end

    test "update_ai_model/2 with invalid data returns error changeset" do
      ai_model = ai_model_fixture()
      assert {:error, %Ecto.Changeset{}} = AiProfiles.update_ai_model(ai_model, @invalid_attrs)
      assert ai_model == AiProfiles.get_ai_model!(ai_model.id)
    end

    test "delete_ai_model/1 deletes the ai_model" do
      ai_model = ai_model_fixture()
      assert {:ok, %AiModel{}} = AiProfiles.delete_ai_model(ai_model)
      assert_raise Ecto.NoResultsError, fn -> AiProfiles.get_ai_model!(ai_model.id) end
    end

    test "change_ai_model/1 returns a ai_model changeset" do
      ai_model = ai_model_fixture()
      assert %Ecto.Changeset{} = AiProfiles.change_ai_model(ai_model)
    end
  end
end

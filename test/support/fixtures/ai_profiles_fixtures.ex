defmodule Messenger.AiProfilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Messenger.AiProfiles` context.
  """

  @doc """
  Generate a ai_profile.
  """
  def ai_profile_fixture(attrs \\ %{}) do
    {:ok, ai_profile} =
      attrs
      |> Enum.into(%{
        api_key: "some api_key",
        provider: "some provider"
      })
      |> Messenger.AiProfiles.create_ai_profile()

    ai_profile
  end

  @doc """
  Generate a prompt.
  """
  def prompt_fixture(attrs \\ %{}) do
    {:ok, prompt} =
      attrs
      |> Enum.into(%{
        content: "some content",
        description: "some description",
        is_active: true,
        metadata: %{},
        name: "some name",
        version: 42
      })
      |> Messenger.AiProfiles.create_prompt()

    prompt
  end
end

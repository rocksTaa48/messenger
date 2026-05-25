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
end

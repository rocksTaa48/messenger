defmodule Messenger.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Messenger.Accounts` context.
  """

  @doc """
  Generate a unique user telegram_id.
  """
  def unique_user_telegram_id, do: System.unique_integer([:positive])

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        first_name: "some first_name",
        telegram_id: unique_user_telegram_id(),
        username: "some username"
      })
      |> Messenger.Accounts.create_user()

    user
  end
end

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

  @doc """
  Generate a transaction.
  """
  def transaction_fixture(attrs \\ %{}) do
    {:ok, transaction} =
      attrs
      |> Enum.into(%{
        cost_completion: "120.5",
        cost_prompt: "120.5",
        cost_total: "120.5",
        metadata: %{},
        tokens_completion: 42,
        tokens_prompt: 42,
        tokens_total: 42
      })
      |> Messenger.Accounts.create_transaction()

    transaction
  end
end

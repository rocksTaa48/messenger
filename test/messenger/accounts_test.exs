defmodule Messenger.AccountsTest do
  use Messenger.DataCase

  alias Messenger.Accounts

  describe "users" do
    alias Messenger.Accounts.User

    import Messenger.AccountsFixtures

    @invalid_attrs %{username: nil, telegram_id: nil, first_name: nil}

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{username: "some username", telegram_id: 42, first_name: "some first_name"}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.username == "some username"
      assert user.telegram_id == 42
      assert user.first_name == "some first_name"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{username: "some updated username", telegram_id: 43, first_name: "some updated first_name"}

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.username == "some updated username"
      assert user.telegram_id == 43
      assert user.first_name == "some updated first_name"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "transactions" do
    alias Messenger.Accounts.Transaction

    import Messenger.AccountsFixtures

    @invalid_attrs %{metadata: nil, tokens_prompt: nil, tokens_completion: nil, tokens_total: nil, cost_prompt: nil, cost_completion: nil, cost_total: nil}

    test "list_transactions/0 returns all transactions" do
      transaction = transaction_fixture()
      assert Accounts.list_transactions() == [transaction]
    end

    test "get_transaction!/1 returns the transaction with given id" do
      transaction = transaction_fixture()
      assert Accounts.get_transaction!(transaction.id) == transaction
    end

    test "create_transaction/1 with valid data creates a transaction" do
      valid_attrs = %{metadata: %{}, tokens_prompt: 42, tokens_completion: 42, tokens_total: 42, cost_prompt: "120.5", cost_completion: "120.5", cost_total: "120.5"}

      assert {:ok, %Transaction{} = transaction} = Accounts.create_transaction(valid_attrs)
      assert transaction.metadata == %{}
      assert transaction.tokens_prompt == 42
      assert transaction.tokens_completion == 42
      assert transaction.tokens_total == 42
      assert transaction.cost_prompt == Decimal.new("120.5")
      assert transaction.cost_completion == Decimal.new("120.5")
      assert transaction.cost_total == Decimal.new("120.5")
    end

    test "create_transaction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_transaction(@invalid_attrs)
    end

    test "update_transaction/2 with valid data updates the transaction" do
      transaction = transaction_fixture()
      update_attrs = %{metadata: %{}, tokens_prompt: 43, tokens_completion: 43, tokens_total: 43, cost_prompt: "456.7", cost_completion: "456.7", cost_total: "456.7"}

      assert {:ok, %Transaction{} = transaction} = Accounts.update_transaction(transaction, update_attrs)
      assert transaction.metadata == %{}
      assert transaction.tokens_prompt == 43
      assert transaction.tokens_completion == 43
      assert transaction.tokens_total == 43
      assert transaction.cost_prompt == Decimal.new("456.7")
      assert transaction.cost_completion == Decimal.new("456.7")
      assert transaction.cost_total == Decimal.new("456.7")
    end

    test "update_transaction/2 with invalid data returns error changeset" do
      transaction = transaction_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_transaction(transaction, @invalid_attrs)
      assert transaction == Accounts.get_transaction!(transaction.id)
    end

    test "delete_transaction/1 deletes the transaction" do
      transaction = transaction_fixture()
      assert {:ok, %Transaction{}} = Accounts.delete_transaction(transaction)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_transaction!(transaction.id) end
    end

    test "change_transaction/1 returns a transaction changeset" do
      transaction = transaction_fixture()
      assert %Ecto.Changeset{} = Accounts.change_transaction(transaction)
    end
  end
end

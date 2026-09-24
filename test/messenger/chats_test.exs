defmodule Messenger.ChatsTest do
  use Messenger.DataCase

  alias Messenger.Chats

  describe "chats" do
    alias Messenger.Chats.Chat

    import Messenger.ChatsFixtures

    @invalid_attrs %{title: nil, provider: nil}

    test "list_chats/0 returns all chats" do
      chat = chat_fixture()
      assert Chats.list_chats() == [chat]
    end

    test "get_chat!/1 returns the chat with given id" do
      chat = chat_fixture()
      assert Chats.get_chat!(chat.id) == chat
    end

    test "create_chat/1 with valid data creates a chat" do
      valid_attrs = %{title: "some title", provider: "some provider"}

      assert {:ok, %Chat{} = chat} = Chats.create_chat(valid_attrs)
      assert chat.title == "some title"
      assert chat.provider == "some provider"
    end

    test "create_chat/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chats.create_chat(@invalid_attrs)
    end

    test "update_chat/2 with valid data updates the chat" do
      chat = chat_fixture()
      update_attrs = %{title: "some updated title", provider: "some updated provider"}

      assert {:ok, %Chat{} = chat} = Chats.update_chat(chat, update_attrs)
      assert chat.title == "some updated title"
      assert chat.provider == "some updated provider"
    end

    test "update_chat/2 with invalid data returns error changeset" do
      chat = chat_fixture()
      assert {:error, %Ecto.Changeset{}} = Chats.update_chat(chat, @invalid_attrs)
      assert chat == Chats.get_chat!(chat.id)
    end

    test "delete_chat/1 deletes the chat" do
      chat = chat_fixture()
      assert {:ok, %Chat{}} = Chats.delete_chat(chat)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_chat!(chat.id) end
    end

    test "change_chat/1 returns a chat changeset" do
      chat = chat_fixture()
      assert %Ecto.Changeset{} = Chats.change_chat(chat)
    end
  end

  describe "messages" do
    alias Messenger.Chats.Message

    import Messenger.ChatsFixtures

    @invalid_attrs %{role: nil, content: nil}

    test "list_messages/0 returns all messages" do
      message = message_fixture()
      assert Chats.list_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Chats.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = %{role: "some role", content: "some content"}

      assert {:ok, %Message{} = message} = Chats.create_message(valid_attrs)
      assert message.role == "some role"
      assert message.content == "some content"
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chats.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = message_fixture()
      update_attrs = %{role: "some updated role", content: "some updated content"}

      assert {:ok, %Message{} = message} = Chats.update_message(message, update_attrs)
      assert message.role == "some updated role"
      assert message.content == "some updated content"
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Chats.update_message(message, @invalid_attrs)
      assert message == Chats.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Chats.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Chats.change_message(message)
    end
  end

  describe "groups" do
    alias Messenger.Chats.Group

    import Messenger.ChatsFixtures

    @invalid_attrs %{title: nil}

    test "list_groups/0 returns all groups" do
      group = group_fixture()
      assert Chats.list_groups() == [group]
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Chats.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      valid_attrs = %{title: "some title"}

      assert {:ok, %Group{} = group} = Chats.create_group(valid_attrs)
      assert group.title == "some title"
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chats.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()
      update_attrs = %{title: "some updated title"}

      assert {:ok, %Group{} = group} = Chats.update_group(group, update_attrs)
      assert group.title == "some updated title"
    end

    test "update_group/2 with invalid data returns error changeset" do
      group = group_fixture()
      assert {:error, %Ecto.Changeset{}} = Chats.update_group(group, @invalid_attrs)
      assert group == Chats.get_group!(group.id)
    end

    test "delete_group/1 deletes the group" do
      group = group_fixture()
      assert {:ok, %Group{}} = Chats.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset" do
      group = group_fixture()
      assert %Ecto.Changeset{} = Chats.change_group(group)
    end
  end

  describe "chat_summaries" do
    alias Messenger.Chats.ChatSummary

    import Messenger.ChatsFixtures

    @invalid_attrs %{metadata: nil, tokens_prompt: nil, tokens_completion: nil, tokens_total: nil, cost_prompt: nil, cost_completion: nil, cost_total: nil, content: nil}

    test "list_chat_summaries/0 returns all chat_summaries" do
      chat_summary = chat_summary_fixture()
      assert Chats.list_chat_summaries() == [chat_summary]
    end

    test "get_chat_summary!/1 returns the chat_summary with given id" do
      chat_summary = chat_summary_fixture()
      assert Chats.get_chat_summary!(chat_summary.id) == chat_summary
    end

    test "create_chat_summary/1 with valid data creates a chat_summary" do
      valid_attrs = %{metadata: %{}, tokens_prompt: 42, tokens_completion: 42, tokens_total: 42, cost_prompt: "120.5", cost_completion: "120.5", cost_total: "120.5", content: "some content"}

      assert {:ok, %ChatSummary{} = chat_summary} = Chats.create_chat_summary(valid_attrs)
      assert chat_summary.metadata == %{}
      assert chat_summary.tokens_prompt == 42
      assert chat_summary.tokens_completion == 42
      assert chat_summary.tokens_total == 42
      assert chat_summary.cost_prompt == Decimal.new("120.5")
      assert chat_summary.cost_completion == Decimal.new("120.5")
      assert chat_summary.cost_total == Decimal.new("120.5")
      assert chat_summary.content == "some content"
    end

    test "create_chat_summary/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chats.create_chat_summary(@invalid_attrs)
    end

    test "update_chat_summary/2 with valid data updates the chat_summary" do
      chat_summary = chat_summary_fixture()
      update_attrs = %{metadata: %{}, tokens_prompt: 43, tokens_completion: 43, tokens_total: 43, cost_prompt: "456.7", cost_completion: "456.7", cost_total: "456.7", content: "some updated content"}

      assert {:ok, %ChatSummary{} = chat_summary} = Chats.update_chat_summary(chat_summary, update_attrs)
      assert chat_summary.metadata == %{}
      assert chat_summary.tokens_prompt == 43
      assert chat_summary.tokens_completion == 43
      assert chat_summary.tokens_total == 43
      assert chat_summary.cost_prompt == Decimal.new("456.7")
      assert chat_summary.cost_completion == Decimal.new("456.7")
      assert chat_summary.cost_total == Decimal.new("456.7")
      assert chat_summary.content == "some updated content"
    end

    test "update_chat_summary/2 with invalid data returns error changeset" do
      chat_summary = chat_summary_fixture()
      assert {:error, %Ecto.Changeset{}} = Chats.update_chat_summary(chat_summary, @invalid_attrs)
      assert chat_summary == Chats.get_chat_summary!(chat_summary.id)
    end

    test "delete_chat_summary/1 deletes the chat_summary" do
      chat_summary = chat_summary_fixture()
      assert {:ok, %ChatSummary{}} = Chats.delete_chat_summary(chat_summary)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_chat_summary!(chat_summary.id) end
    end

    test "change_chat_summary/1 returns a chat_summary changeset" do
      chat_summary = chat_summary_fixture()
      assert %Ecto.Changeset{} = Chats.change_chat_summary(chat_summary)
    end
  end
end

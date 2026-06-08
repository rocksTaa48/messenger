defmodule Messenger.ChatsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Messenger.Chats` context.
  """

  @doc """
  Generate a chat.
  """
  def chat_fixture(attrs \\ %{}) do
    {:ok, chat} =
      attrs
      |> Enum.into(%{
        provider: "some provider",
        title: "some title"
      })
      |> Messenger.Chats.create_chat()

    chat
  end

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        content: "some content",
        role: "some role"
      })
      |> Messenger.Chats.create_message()

    message
  end

  @doc """
  Generate a group.
  """
  def group_fixture(attrs \\ %{}) do
    {:ok, group} =
      attrs
      |> Enum.into(%{
        title: "some title"
      })
      |> Messenger.Chats.create_group()

    group
  end
end

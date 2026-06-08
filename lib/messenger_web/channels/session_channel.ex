defmodule MessengerWeb.SessionChannel do
  # Этот модуль является каналом
  use MessengerWeb, :channel
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer
  alias MessengerWeb.Actions.{BaseActions, ChatActions, UserActions}

  @doc """
  Это главный джоин, реализацию я определил в один канал, тоетсь в гостинную 'session:lobby' здесь и будут происходить
  все изменения, движение данных, один канал на все, со временем я реализую 'DELTA' изменения, что бы не отдавать
  каждый раз ПОЛНЫЙ стейт. Это компромиссное решение в виду моей не охоты управлять лапшой из каналов,
  которая потом обязательно будет ':chats, :messages, :settings etc' и потом можно будет утонуть в сторах
  на фронте, а так как я не силен во фронтенде, мне этой лишней работы не нужно.
  """
  def join("session:lobby", _payload, socket) do
    current_user = socket.assigns.current_user
    groups = Chats.list_user_groups(current_user.id)
    chats = Chats.list_user_chats(current_user.id)
    formatted_groups = Enum.map(groups, &Serializer.group_serialize/1)
    formatted_chats = Enum.map(chats, &Serializer.chat_serialize/1)

    Phoenix.PubSub.subscribe(Messenger.PubSub, "user:#{current_user.id}:lobby")
    # Собираем единое Дерево Стейта, это то что полетит на фронт, все данные, важно попозже добавить ДЕЛЬТУ
    # Что бы не слать весь стейт заново, придумать методы отправки только точечных изменений $append $delete $prepend
    initial_tree_state = %{
      "current_screen" => "chats",
      "user" => %{
        "id" => current_user.id,
        "telegram_id" => current_user.telegram_id,
        "username" => current_user.username,
        "first_name" => current_user.first_name,
        "last_name" => current_user.first_name,
        "role" => current_user.role
      },
      "groups" => formatted_groups,
      "chats_list" => formatted_chats,
      "has_more_chats" => length(formatted_chats) == 15,
      "active_chat" => nil
      # "settings" => %{"theme" => "dark", "lang" => "ru"}
    }
    authorized_socket = assign(socket, :state, initial_tree_state)
    {:ok, initial_tree_state, authorized_socket}
  end

  # Все общие экшены перенаправляем в BaseActions
  def handle_in("base:" <> event, payload, socket) do
    BaseActions.handle_in(event, payload, socket)
  end

  # Все экшены чата перенаправляем в ChatActions
  def handle_in("chat:" <> event, payload, socket) do
    ChatActions.handle_in(event, payload, socket)
  end

  # Все экшены пользователя перенаправляем в UserActions
  def handle_in("user:" <> event, payload, socket) do
    UserActions.handle_in(event, payload, socket)
  end









end

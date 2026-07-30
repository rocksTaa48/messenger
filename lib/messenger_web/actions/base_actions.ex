defmodule MessengerWeb.Actions.BaseActions do
  import Phoenix.Channel, only: [push: 3]
  import Phoenix.Socket, only: [assign: 3]
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer

  @doc"""
  Юзер нажал кнопку "Назад" из любого экрана, чтобы вернуться к списку чатов
  """
  def handle_in("click_nav_chats", payload, socket) do
    # Подгружаем свежий список чатов из базы для экрана 'chats'
    IO.inspect(payload, label: "\n📥 [FRONTEND -> BACKEND] СЫРОЙ PAYLOAD")

    group_id = Map.get(payload, "group_id")

    # 2. СМОТРИМ, КАКОЙ ТИП ДАННЫХ У GROUP_ID (String, Integer или nil)
    IO.inspect(group_id, label: "🔍 [CONVERTED] ИЗВЛЕЧЕННЫЙ GROUP_ID")
    IO.inspect(is_binary(group_id), label: "❓ ЯВЛЯЕТСЯ ЛИ СТРОКОЙ")
    updated_chats = Chats.list_user_chats(socket.assigns.current_user.id, options: %{"group_id" => group_id})
    formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)
    IO.inspect(payload, label: "\n📥 [LOG FROM FRONTEND]")

    new_state =
      socket.assigns.state

      |> Map.put("chats_list", formatted_chats)
      |> Map.put("group_id", group_id)
      |> Map.delete("active_chat") # Уходим из чата — чистим память от тяжелых сообщений

    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end


  @doc """
  Юзер при подключении уже подписался на свой PubSub: user:current_user.id:lobby
  Когда в систему прилетает событие, например: новое сообщение от агента или системное уведомление,
  Phoenix может вызвать handle_info/2
  """
  def handle_in({:new_message, incoming_msg}, socket) do
    current_state = socket.assigns.state

    # Проверяем: если у пользователя сейчас открыт именно ТОТ чат, куда пришло сообщение
    new_state = if current_state["current_screen"] == "Messenger" and
                   current_state["active_chat"]["id"] == incoming_msg.chat_id do

      # Дописываем новое сообщение прямо в массив открытого чата
      updated_messages = current_state["active_chat"]["messages"] ++ [incoming_msg]
      put_in(current_state, ["active_chat", "messages"], updated_messages)
    else

      # Если юзер на другом экране, просто инкрементим счетчик в списке чатов или ничего не делаем
      updated_chats = Enum.map(current_state["chats_list"], fn chat ->
        if chat["id"] == incoming_msg.chat_id, do: Map.put(chat, "unread", chat["unread"] + 1), else: chat
      end)
      put_in(current_state, ["chats_list"], updated_chats)
    end

    # Шлем обновленное дерево на фронтенд
    push(socket, "sync", new_state)

    # Сохраняем новое состояние в процессе сокета
    {:noreply, assign(socket, :state, new_state)}
  end

  # Если на фронте будут кнопки для перехода на экраны настроек
  def handle_in("settings", _payload, socket) do
    new_state = Map.put(socket.assigns.state, "current_screen", "Agents")
    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end


end
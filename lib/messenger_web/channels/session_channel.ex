defmodule MessengerWeb.SessionChannel do
  # Этот модуль является каналом
  use MessengerWeb, :channel
  alias Messenger.Chats

  @doc """
  Здесь описываются функции подключения и работы с гостинной чатов
  """
  #--------------------------------------------- Подключаемся к гостинной
  def join("session:lobby", _payload, socket) do

    current_user = socket.assigns.current_user
    chats = Chats.list_user_chats(current_user.id, 15)

    # Форматируем в чистый JSON-массив
    formatted_chats = Enum.map(chats, &format_chat/1)

    # Подписка на обновления
    Phoenix.PubSub.subscribe(Messenger.PubSub, "user:#{current_user.id}:lobby")

    user_data = %{
      id: current_user.id,
      telegram_id: current_user.telegram_id,
      username: current_user.username,
      first_name: current_user.first_name,
      role: current_user.role
    }

    # Отдаем пользователю данные
    {:ok, %{user: user_data, chats: formatted_chats}, socket}
  end

  #--------------------------------------------- Отправляем событие "добавить чат в список"
  def handle_info({:lobby_update, :new_chat, new_chat}, socket) do
    push(socket, "prepend_chat", format_chat(new_chat))
    # Увеличиваем счетчик загруженных
    {:noreply, update_in(socket.assigns.total_loaded, &(&1 + 1))}
  end

  #--------------------------------------------- Отправляем событие "удалить чат из списка"
  def handle_info({:lobby_update, :deleted_chat, chat_id}, socket) do
    push(socket, "remove_chat", %{chat_id: chat_id})
    # Уменьшаем счетчик
    {:noreply, update_in(socket.assigns.total_loaded, &(&1 - 1))}
  end



  @doc """
  Подключение к конкретному чату
  """
  def join("session:chat:" <> string_chat_id, _payload, socket) do
    chat_id = String.to_integer(string_chat_id)
    current_user = socket.assigns.current_user

    case Messenger.Chats.get_user_chat(chat_id, current_user.id) do
      %Messenger.Chats.Chat{} ->
        # Если чат найден и принадлежит юзеру — пускаем его в сокет и отдаем историю
        history = Messenger.Chats.get_ai_context(chat_id)

        {:ok, %{history: history}, assign(socket, :chat_id, chat_id)}

      nil ->
        # Если чат чужой или его нет бросаем ошибку
        {:error, %{reason: "Unauthorized access to this chat"}}
    end
  end


  @doc """
  Триггер от фронтенда, пользователь долистал до него
  """
  def handle_in("load_more_chats", %{"before_cursor" => before_cursor_str}, socket) do
    current_user = socket.assigns.current_user

    # Декодируем строку времени обратно в DateTime Elixir
    {:ok, before_cursor, _} = DateTime.from_iso8601(before_cursor_str)

    # Запрашиваем следующую порцию данных из базы
    next_chats = Chats.list_user_chats(current_user.id, 15, before_cursor)
    formatted_chats = Enum.map(next_chats, &format_chat/1)

    # Отвечаем фронтенду
    {:reply, {:ok, %{chats: formatted_chats}}, socket}
  end










  @doc """
  Обработка события создания чата с фронтенда.
  Прилетает только в топик "session:lobby".
  """
  def handle_in("create_chat", payload, socket) do
    current_user = socket.assigns.current_user

    # Собираем атрибуты для создания чата
    chat_attrs = %{
      "title" => Map.get(payload, "title", "Новый чат"),
      "model_name" => Map.get(payload, "model_name"),
      "ai_profile_id" => Map.get(payload, "ai_profile_id"),
      "user_id" => current_user.id
    }

    # Если пользователь передал стартовый системный промпт,
    # сразу записываем его как первое сообщение с ролью "system",
    # это довольно удобно, если сразу не задал, то чат будет обычным.
    case Chats.create_chat(chat_attrs) do
      {:ok, chat} ->
        if prompt = Map.get(payload, "system_prompt") do
          Chats.create_message(%{
            chat_id: chat.id,
            role: "system",
            content: prompt
          })
        end

        # Отвечаем фронтенду успехом и возвращаем ID созданного чата
        {:reply, {:ok, %{chat_id: chat.id, title: chat.title}}, socket}

      {:error, changeset} ->
        # Если сработал changeset и данные кривые, вываливаемся с ошибкой
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        {:reply, {:error, %{errors: errors}}, socket}
    end
  end




  # Хелпер для маппинга структуры Ecto в JSON для фронтенда
  defp format_chat(chat) do
    %{
      id: chat.id,
      title: chat.title,
      model_name: chat.model_name,
      inserted_at: DateTime.to_iso8601(chat.inserted_at)
    }
  end

end

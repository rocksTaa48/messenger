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
  def join("session:lobby", payload, socket) do
    current_user = socket.assigns.current_user
    # Извлекаем навигационный контекст, присланный фронтендом
    # Если это самый первый вход (или пустой payload), дефолтимся на "chats", если же нет ---->

    nav_context = Map.get(payload, "nav_context", %{"screen" => "chats"})
    screen = Map.get(nav_context, "screen", "chats")
    params = Map.get(nav_context, "params", %{})

    # Базовые данные, нужные всегда, такие как - профиль, группы, список профилей ИИ, может еще чего.
    groups = Chats.list_user_groups(current_user.id)
    ai_profiles = AiProfiles.available_user_profiles(current_user.status)

    formatted_groups = Enum.map(groups, &Serializer.group_serialize/1)
    formatted_profiles = Enum.map(ai_profiles, &Serializer.ai_profile_serialize/1)

    # Подписываемся на изменения обязательно!
    Phoenix.PubSub.subscribe(Messenger.PubSub, "user:#{current_user.id}:lobby")

    # Общая структура стейта передаваемого на фронт
    base_state = %{
      "user" => %{
        "id" => current_user.id,
        "telegram_id" => current_user.telegram_id,
        "username" => current_user.username,
        "first_name" => current_user.first_name,
        "last_name" => current_user.first_name,
        "role" => current_user.role
      },
      "groups" => formatted_groups,
      "ai_profiles" => formatted_profiles,
      "settings" => %{"theme" => "dark", "lang" => "ru"} # если нужно
    }

    # Здесь наполняем стейт !динамически! в зависимости от экрана восстановления
    initial_tree_state = build_state_for_screen(screen, params, base_state, current_user.id)

    authorized_socket = assign(socket, :state, initial_tree_state)
    {:ok, initial_tree_state, authorized_socket}
  end

  # --- Хелперы для сборки стейта под конкретный экран ---

  # Если: Юзер был на экране списков чатов
  defp build_state_for_screen("chats", params, base_state, user_id) do
    group_id = Map.get(params, "group_id")

    options = case group_id do
      "All" -> %{}
      nil   -> %{}
      id    -> %{"group_id" => id}
    end

    chats = Chats.list_user_chats(user_id, options: options)
    formatted_chats = Enum.map(chats, &Serializer.chat_serialize/1)

    base_state
    |> Map.put("chats_list", formatted_chats)
    |> Map.put("has_more_chats", length(formatted_chats) >= 15)
    |> Map.put("active_chat", nil)
  end

  # Если: Юзер был внутри конкретного чата, мы восстанавливаем его
  defp build_state_for_screen("inside_chat", params, base_state, user_id) do
    chat_id = Map.get(params, "chat_id")
    group_id = Map.get(params, "group_id")
    chat = Chats.get_chat(user_id, chat_id)

    # Загружаем сообщения активного чата
    active_chat_data = case Chats.get_chat_messages(chat_id, user_id) do
      nil -> nil
      chat -> Enum.map(chat, &Serializer.message_serialize/1) # Сериализация активного чата
    end

    base_state
    |> Map.put("active_chat", %{
      "id" => chat_id,
      "group_id" => chat.group_id,
      "messages" => active_chat_data,
      "has_more_messages" => length(active_chat_data) >= 15
    })
  end

  # Если: Юзер был в настройках
  defp build_state_for_screen("settings", _params, base_state, user_id) do
    chats = Chats.list_user_chats(user_id)
    formatted_chats = Enum.map(chats, &Serializer.chat_serialize/1)

    base_state
    |> Map.put("chats_list", formatted_chats)
    |> Map.put("has_more_chats", length(formatted_chats) >= 15)
    |> Map.put("active_chat", nil)
    # Тут нужно будет дополнить специфичными данными настроек, когда дело дойдет!!!
  end

  # Фоллбек на случай непредвиденного экрана
  defp build_state_for_screen(_, _params, base_state, user_id), do: build_state_for_screen("chats", %{}, base_state, user_id)

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


  @doc """
  Это участок принятия сообщений!!!
  """

  # 1. Пушим событие на фронтенд.
  @impl true
  def handle_info({:ai_token, %{chat_id: chat_id, token: token} = payload}, socket) do
    # Отправляем токен на фронтенд
    push(socket, "ai:token", payload)
    {:noreply, socket}
  end

  # 2. Ошибка при генерации AI
  @impl true
  def handle_info({:ai_stream_error, %{chat_id: chat_id, reason: reason} = payload}, socket) do
    push(socket, "ai:stream_error", payload)
    {:noreply, socket}
  end

  # 3. Стрим завершен команда done
  @impl true
  def handle_info({:ai_stream_done, payload}, socket) do
    push(socket, "ai:stream_done", payload)
    {:noreply, socket}
  end

  # 4. Пушим событие на фронтенд обновили название чата.
  @impl true
  def handle_info({:chat_title_update, %{chat_id: chat_id, title: title}}, socket) do
    push(socket, "chat_title_update", %{
      chat_id: to_string(chat_id),
      title: title
    })
    {:noreply, socket}
  end

  # 5. Пушим событие на фронтенд ошибка название чата.
  @impl true
  def handle_info({:chat_title_error, %{chat_id: chat_id, reason: reason}}, socket) do
    push(socket, "chat_title_error", %{
      chat_id: to_string(chat_id),
      reason: reason
    })
    {:noreply, socket}
  end

  # 4. Фолбэк от неожиданного сообщения
  @impl true
  def handle_info(msg, socket) do
    # Можно оставить просто IO.inspect для отладки, или вообще убрать, если не нужно.
    IO.inspect(msg, label: "⚠️ Неожиданное сообщение в SessionChannel (PubSub)")
    {:noreply, socket}
  end


end

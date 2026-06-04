defmodule MessengerWeb.SessionChannel do
  # Этот модуль является каналом
  use MessengerWeb, :channel
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer # Сериализатор для того что бы опредилить что отдавать в JASON

  @doc """
  Это главный джоин, реализацию я определил в один канал, тоетсь в гостинную 'session:lobby' здесь и будут происходить
  все изменения, движение данных, один канал на все, со временем я реализую 'DELTA' изменения, что бы не отдавать
  каждый раз ПОЛНЫЙ стейт. Это компромиссное решение в виду моей не охоты управлять лапшой из каналов,
  которая потом обязательно будет ':chats, :messages, :settings etc' и потом можно будет утонуть в сторах
  на фронте, а так как я не силен во фронтенде, мне этой лишней работы не нужно.
  """
  def join("session:lobby", _payload, socket) do
    current_user = socket.assigns.current_user
    chats = Chats.list_user_chats(current_user.id)
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
      "chats_list" => formatted_chats,
      "has_more_chats" => length(formatted_chats) == 15,
      "active_chat" => nil
      # "settings" => %{"theme" => "dark", "lang" => "ru"}
    }

    # а) Кладем стейт в socket через assign, чтобы Elixir его запомнил.
    # б) Возвращаем его фронтенду в кортеже {:ok, state, socket}.
    authorized_socket = assign(socket, :state, initial_tree_state)
    {:ok, initial_tree_state, authorized_socket}
  end



  @doc """
  Это функция пагинации, при скролинге и долистывании до таргета, с фронта прилетает запрос, после которого мы отдаем
  еще одну страницу чатов, что убережет нас от подгрузки тысяч чатов за раз, что уронит фронт.
  """
  def handle_in("load_more_chats", _payload, socket) do
    current_user = socket.assigns.current_user
    current_chats_list = socket.assigns.state["chats_list"]

    case List.last(current_chats_list) do
      nil ->
        {:noreply, socket}

      last_chat ->
        # Достаем таймстемп-курсор
        cursor = last_chat["cursor_timestamp"]

        # Вызываем твой контекст (limit = 15)
        next_chats = Chats.list_user_chats(current_user.id, 15, cursor)
        formatted_next = Enum.map(next_chats, &Serializer.chat_serialize/1)

        if Enum.empty?(formatted_next) do
          new_state = Map.put(socket.assigns.state, "has_more_chats", false)
          push(socket, "sync", new_state)
          {:reply, :ok, assign(socket, :state, new_state)}
        else
          # Склеиваем массивы чатов
          updated_chats_list = current_chats_list ++ formatted_next

          new_state = socket.assigns.state

                      |> Map.put("chats_list", updated_chats_list)
                      |> Map.put("has_more_chats", length(formatted_next) == 15)

          # Синхронизируем фронтенд
          push(socket, "sync", new_state)
          {:reply, :ok, assign(socket, :state, new_state)}
        end
    end
  end



  @doc """
  Пользователь нажал на кнопку 'Создать чат' метод NEW по рубишному
  """
  def handle_in("click:create_new_chat", _payload, socket) do
    current_user = socket.assigns.current_user
    ai_profiles = AiProfiles.list_user_ai_profiles(current_user.id)
    formated_profile = Enum.map(ai_profiles, &Serializer.ai_profile_serialize/1)

    # Оставляем screen - "chats", просто дополняем дерево массивом ai_profiles
    new_state = socket.assigns.state
                |> Map.put("ai_profiles", formated_profile)

    # Синхронизируем. Шторка на фронтенде тут же увидит $appState.ai_profiles и отрендерит список!
    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end



  @doc """
  Пользователь нажал на кнопку 'Submit' метод CREATE по рубишному
  """
  def handle_in("click:submit_new_chat", %{"ai_profile_id" => ai_profile_id, "system_prompt" => system_prompt}, socket) do
    current_user = socket.assigns.current_user

    final_prompt =
      case String.trim(system_prompt) do
        "" -> "Ты опытный и вежливый персональный помощник."
        valid_prompt -> valid_prompt
      end

    # Достаем профиль агента из БД, чтобы узнать имя его модели (gpt-4o, claude и т.д.)
    case AiProfiles.get_ai_profile(ai_profile_id) do
      nil ->
        {:reply, {:error, %{reason: "profile_not_found"}}, socket}

      profile ->
        generated_title =
          if String.length(final_prompt) > 35 do
            String.slice(final_prompt, 0, 35) <> "..."
          else
            final_prompt
          end

        # Передаем в контекст все необходимые поля
        db_result = Chats.create_chat_with_prompt(
          current_user.id,
          profile.id,
          profile.model,
          generated_title,
          final_prompt
        )

        case db_result do
          {:ok, %{chat: new_chat, system_message: system_message}} ->
            updated_chats = Chats.list_user_chats(current_user.id)
            formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)

            new_state =
              socket.assigns.state

              |> Map.put("current_screen", "Messenger")
              |> Map.put("chats_list", formatted_chats)
              |> Map.put("active_chat", %{
                "id" => to_string(new_chat.id),
                "ai_profile_id" => to_string(profile.id),
              })
              |> Map.delete("ai_profiles")

            push(socket, "sync", new_state)
            {:reply, :ok, assign(socket, :state, new_state)}

          {:error, _step, _changeset, _changes} ->
            {:reply, {:error, %{reason: "database_error"}}, socket}
        end
    end
  end



  # Юзер нажал кнопку "Назад" из практически любого экрана, чтобы вернуться к списку чатов
  def handle_in("nav_chats", _payload, socket) do
    # Подгружаем свежий список чатов из базы для экрана 'chats'
    updated_chats = Chats.list_user_chats(socket.assigns.current_user.id)
    formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)

    # Меняем экран в стейте на 'chats'
    new_state =
      socket.assigns.state

      |> Map.put("current_screen", "chats")
      |> Map.put("chats_list", formatted_chats)
      |> Map.delete("active_chat") # Уходим из чата — чистим память от тяжелых сообщений

    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end

  # Если на фронте будут кнопки для перехода на экраны настроек или агентов:
  def handle_in("nav_agents", _payload, socket) do
    # ... логика подгрузки ai_profiles ...
    new_state = Map.put(socket.assigns.state, "current_screen", "Agents")
    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end


  @doc"""
  Функция 'click_open_chat' открывает чат и показывает нам его содержимое
  """
  def handle_in("click_open_chat", %{"chat_id" => chat_id}, socket) do
    current_user = socket.assigns.current_user

    messages = Chats.get_chat_messages(chat_id, current_user.id)
    serialized_messages =
      case messages do
        {:error, _} -> []
        msgs -> Enum.map(msgs, &Serializer.message_serialize/1)
      end

    new_state = socket.assigns.state

                |> Map.put("current_screen", "Messenger")
                |> Map.put("active_chat", %{
      "id" => chat_id,
      "messages_list" => serialized_messages
    })

    # Шлем обновленный монолит-стейт во фронтенд
    push(socket, "sync", new_state)

    # Сохраняем обновленное состояние в процессе сокета
    {:reply, :ok, assign(socket, :state, new_state)}
  end



  @doc """
  Юзер при подключении уже подписался на свой PubSub: user:current_user.id:lobby
  Когда в систему прилетает событие, например: новое сообщение от агента или системное уведомление,
  Phoenix может вызвать handle_info/2
  """
  def handle_info({:new_message, incoming_msg}, socket) do
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

end

defmodule MessengerWeb.Actions.ChatActions do
  import Phoenix.Channel, only: [push: 3]
  import Phoenix.Socket, only: [assign: 3]
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer

  @doc"""
  SHOW:               Функция 'click_open' открывает чат и показывает нам его содержимое
  """
  def handle_in("click_open", %{"chat_id" => chat_id}, socket) do
    current_user = socket.assigns.current_user
    chat = Chats.get_chat(current_user.id, chat_id)

    messages = Chats.get_chat_messages(chat_id, current_user.id)

    serialized_messages =
      case messages do
        {:error, _} -> []
        msgs -> Enum.map(msgs, &Serializer.message_serialize/1)
      end

    new_state = socket.assigns.state

                |> Map.put("active_chat", %{
      "id" => chat_id,
      "group_id" => chat.group_id,
      "messages" => serialized_messages
    })

    IO.inspect(serialized_messages, label: "SERIALIZED MESSAGES")


    # Шлем обновленный монолит-стейт во фронтенд
    push(socket, "sync", new_state)

    # Сохраняем обновленное состояние в процессе сокета
    {:reply, :ok, assign(socket, :state, new_state)}
  end


  @doc"""
  NEW:                Функция 'click_new' подготавливает нам создание нового чата
  """
  def handle_in("click_new", _payload, socket) do
    current_user = socket.assigns.current_user
    ai_profiles = AiProfiles.available_user_profiles(current_user.status)
    formated_profile = Enum.map(ai_profiles, &Serializer.ai_profile_serialize/1)

    # Дополняем дерево массивом ai_profiles
    new_state = socket.assigns.state
                |> Map.put("ai_profiles", formated_profile)

    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end

  @doc"""
  CREATE_CHAT_AND_MESSAGE:    Мультифункция создает чат и сообщение в нем от пользователя
  """
  def handle_in("click_submit_message", payload, socket) do
    current_user = socket.assigns.current_user
    chat_id = Map.get(payload, "chat_id")
    content = Map.get(payload, "text")
    ai_profile_id = Map.get(payload, "ai_profile_id")
    # Проверяем есть ли чат? Тоесть будет выполнено добавление сообщения в текущий чат или создание нового
    chat = if chat_id, do: Chats.get_chat(current_user.id, chat_id), else: nil
    # Достаем AI профиль текущего чата, если таковой имеется
    chat_ai_profile_id = if chat, do: chat.ai_profile_id, else: nil

    available_user_ai_profiles = AiProfiles.available_user_profiles(current_user.status)
    available_ai_profiles_ids = Enum.map(available_user_ai_profiles, fn profile -> profile.id end)

    # Здесь может не красиво, зато наглядно мы ищем AI профиль,
    # 1) это введенный вручную, 2) закрепленный за чатом, 3) фоллбэк на пользовательский по умолчанию
    ai_profile =
      case ai_profile_id do
        nil -> nil
        profile_id ->
          if profile_id in available_ai_profiles_ids, do: AiProfiles.get_ai_profile(profile_id), else: nil
      end
      |> case do
           nil ->
             if chat_id && chat_ai_profile_id in available_ai_profiles_ids do
               AiProfiles.get_ai_profile(chat_ai_profile_id)
             else
               nil
             end
           profile -> profile
         end
      |> case do
           nil -> AiProfiles.get_default_ai_profile(current_user.status)
           profile -> profile
         end

    action =
      case chat do
        nil ->
          create_chat_and_first_message(current_user.id, ai_profile, content)
        existing_chat ->
          create_message_in_existing_chat(current_user.id, ai_profile, existing_chat, content)
      end

    case action do
      {:ok, chat, message} ->
        # Стейт не обновляем а только отдаем необходимое!
        {:reply, {:ok, %{
          "group_id" => chat.group_id, # Что бы при выходе < назад не падать в ебеня
          "chat_id" => chat.id, # Что бы знать что за чат вообще
          "message_id" => message.id}}, # Отдать реальный айдишник сообщения
          socket}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "failed_to_process_message"}}, socket}
    end
  end

  # Хелпер: создание нового сообщения в новом чате
  defp create_chat_and_first_message(user_id, ai_profile, content) do
    prompt = AiProfiles.get_system_prompt(ai_profile.prompt_id)

    case Chats.first_time_create_chat_and_message(
           user_id,
           ai_profile.id,
           ai_profile.openrouter_model_id,
           prompt.content,
           content
         ) do
      {:ok, %{chat: chat, content: message}} ->
        IO.inspect("✅ Чат создан, ID: #{chat.id}. Сейчас вызовем ChatAgent...", label: "DEBUG")
        context = Chats.get_ai_context(chat.id)
        Chats.ChatsAgent.start_and_process(user_id, chat.id, ai_profile, context)
        Chats.ChatNameCreator.start_generation(user_id, chat.id, ai_profile, content)
        {:ok, chat, message}
      {:error, _failed_step, _failed_value, _changesets} ->
        {:error, "db_insert_failed"}
    end
  end

  # Хелпер: создание нового сообщения в уже существующем чате
  defp create_message_in_existing_chat(user_id, ai_profile, chat, content) do

    case Chats.create_message(chat.id, content) do
      {:ok, message} ->
        context = Chats.get_ai_context(chat.id)
        Chats.ChatsAgent.start_and_process(user_id, chat.id, ai_profile, context)

        IO.inspect(context, label: "CONTEXT MESSAGES")

        {:ok, chat, message}
      {:error, _changeset} ->
        {:error, "message_insert_failed"}
    end
  end

  @doc"""
  UPDATE_CHAT:                Мультифункция обновляет чат
  """
  def handle_in("click_update_chat", payload, socket) do

    current_user = socket.assigns.current_user
    action = Map.get(payload, "action")
    group_id_raw = Map.get(payload, "group_id")
    chat_id = Map.get(payload, "chat_id")
    title = Map.get(payload, "title")
    chat = Chats.get_chat(current_user.id, chat_id)

    options = case group_id_raw do
      "All" -> %{}
      nil -> %{}
      id -> %{"group_id" => id}
    end

    group_id = if group_id_raw == "All", do: nil, else: group_id_raw


    # Перебираем экшены для апдейта
    # 1) обновить название чата 2) закрепить/открепить 3) удалить чат
    action_result =
      case action do
        "update_title" -> Chats.update_chat(chat_id, current_user.id, %{"title" => title})
        "toggle_pin"   -> Chats.update_chat_toggle(current_user.id, chat_id, group_id)
        "delete"       -> Chats.remove_chat(chat_id, current_user.id)
        unknown        -> {:error, "unknown_action"}
      end

    # Единый ответ для всех экшенов
    case action_result do
      {:ok, _} ->
        updated_chats = Chats.list_user_chats(current_user.id, options: options)
        formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)
        has_more = length(formatted_chats) >= 15

        new_state =
          socket.assigns.state
          |> Map.put("has_more_chats", has_more)
          |> Map.put("chats_list", formatted_chats)

        push(socket, "sync", new_state)
        {:reply, :ok, assign(socket, :state, new_state)}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "failed_to_execute_action"}}, socket}
    end
  end


  @doc """
  Это функция пагинации, при скролинге и долистывании до таргета, с фронта прилетает запрос, после которого мы отдаем
  еще одну страницу чатов, что убережет нас от подгрузки тысяч чатов за раз, что уронит фронт.
  """
  def handle_in("load_more_chats", payload, socket) do
    current_user = socket.assigns.current_user
    current_chats_list = socket.assigns.state["chats_list"]
    group_id = Map.get(payload, "group_id")

    options = case group_id do
      "All" -> %{}
      nil -> %{}
      id -> %{"group_id" => id}
    end

    case List.last(current_chats_list) do
      nil ->
        {:noreply, socket}

      last_chat ->
        # Достаем таймстамп-курсор
        cursor = last_chat["cursor_timestamp"]

        # Вызываем контекст (limit = 15)
        next_chats = Chats.list_user_chats(current_user.id, limit: 15, before_cursor: cursor, options: options)
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
                      |> Map.put("has_more_chats", length(formatted_next) >= 15)

          # Синхронизируем фронтенд
          push(socket, "sync", new_state)
          {:reply, :ok, assign(socket, :state, new_state)}
        end
    end
  end

  @doc"""
  ---------------------ПОДРАЗДЕЛ ОПЕРАЦИЙ С ГРУППАМИ (ПАПКАМИ) ЧАТОВ----------------------------
  """

  @doc"""
  SHOW_GROUP_CHATS:               Функция 'chat:click_go_to_group' показывает чаты конкретной группы
  """
  def handle_in("click_go_to_group", %{"group_id" => group_id}, socket) do
    current_user = socket.assigns.current_user
    chats = Chats.list_user_chats(current_user.id, options: %{"group_id" => group_id})

    formatted_chats =
      case chats do
        {:error, _} -> []
        chts -> Enum.map(chts, &Serializer.chat_serialize/1)
      end

    new_state =
      socket.assigns.state

      |> Map.put("group_id", group_id)
      |> Map.put("chats_list", formatted_chats)

    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end


  @doc"""
  CREATE_CHAT_GROUP:              Функция 'chat:click_submit_chat_group' создаем группу для чатов
  """
  def handle_in("click_submit_chat_group", %{"title" => title}, socket) do
    current_user = socket.assigns.current_user

    case Chats.create_group(%{user_id: current_user.id, title: title}) do
      {:ok, _new_group} ->
        updated_groups = Chats.list_user_groups(current_user.id)
        formatted_groups = Enum.map(updated_groups, &Serializer.group_serialize/1)

        new_state =
          socket.assigns.state

          |> Map.put("groups", formatted_groups)

        # Отправляем синхронизацию на фронтенд
        push(socket, "sync", new_state)
        {:reply, :ok, assign(socket, :state, new_state)}

      # Ловим стандартную ошибку
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "database_error"}}, socket}
    end
  end


  @doc"""
  UPDATE_CHAT_GROUP:              Функция обновляет группу для чатов, меняем название :UPDATE_TITLE
  """
  def handle_in("click_update_group", %{"group_id" => group_id, "title" => title, "action" => "update_title"}, socket) do
    current_user = socket.assigns.current_user

    case Chats.update_group(group_id, current_user.id, %{title: title}) do
      {:ok, _group} ->
        updated_groups = Chats.list_user_groups(current_user.id)
        formatted_groups = Enum.map(updated_groups, &Serializer.group_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("groups", formatted_groups )

        # Шлем обновленный монолит-стейт во фронтенд
        push(socket, "sync", new_state)

        # Сохраняем обновленное состояние в процессе сокета
        {:reply, :ok, assign(socket, :state, new_state)}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed_to_update_group"}}, socket}
    end
  end

  @doc"""
  UPDATE_CHAT_GROUP:              Функция обновляет группу, добавляя туда чат :ADD
  """
  def handle_in("click_update_chat_group", %{"chat_id" => chat_id, "group_id" => group_id, "action" => "add"}, socket) do
    current_user = socket.assigns.current_user

    case Chats.add_chat_to_group(chat_id, group_id, current_user.id) do
      {:ok, _group} ->
        updated_chats = Chats.list_user_chats(current_user.id, options: %{"group_id" => group_id})
        formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("chats_list", formatted_chats )

        # Шлем обновленный монолит-стейт во фронтенд
        push(socket, "sync", new_state)

        # Сохраняем обновленное состояние в процессе сокета
        {:reply, :ok, assign(socket, :state, new_state)}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed_to_add_chat"}}, socket}
    end
  end

  @doc"""
  UPDATE_CHAT_GROUP:              Функция обновляет группу, удаляя от туда чат :REMOVE
  """
  def handle_in("click_update_chat_group", %{"chat_id" => chat_id, "group_id" => group_id, "action" => "remove"}, socket) do
    current_user = socket.assigns.current_user

    options = case group_id do
      "All" -> %{}
      nil -> %{}
      id -> %{"group_id" => id}
    end

    case Chats.remove_chat_from_group(chat_id, current_user.id) do
      {:ok, _group} ->
        updated_chats = Chats.list_user_chats(current_user.id, options: options)
        formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("chats_list", formatted_chats )

        # Шлем обновленный монолит-стейт во фронтенд
        push(socket, "sync", new_state)

        # Сохраняем обновленное состояние в процессе сокета
        {:reply, :ok, assign(socket, :state, new_state)}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed_to_remove_chat_from_group"}}, socket}
    end
  end

  @doc"""
  REMOVE GROUP:               Функция удаляет группу :REMOVE GROUP
  """
  def handle_in("click_remove_group", %{"group_id" => group_id, "action" => "remove"}, socket) do
    current_user = socket.assigns.current_user

    case Chats.remove_group(group_id, current_user.id) do
      {:ok, _group} ->
        updated_groups = Chats.list_user_groups(current_user.id)
        formatted_groups = Enum.map(updated_groups, &Serializer.group_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("groups", formatted_groups )
                    |> Map.put("deleted_group_id", group_id)

        # Шлем обновленный монолит-стейт во фронтенд
        push(socket, "sync", new_state)

        # Сохраняем обновленное состояние в процессе сокета
        {:reply, :ok, assign(socket, :state, new_state)}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed_to_remove_group"}}, socket}
    end
  end

  @doc"""
  ---------------------ПОДРАЗДЕЛ ОПЕРАЦИЙ С СООБЩЕНИЯМИ ЧАТОВ----------------------------


  # SEND MESSAGE
  def handle_in("click_send_message", %{"chat_id" => chat_id, "content" => content}, socket) do
    current_user = socket.assigns.current_user

    case Chats.create_message(%{chat_id: chat_id, content: content, role: "user"}) do
        {:ok, user_message} ->
          formatted_message = Enum.map(user_message, &Serializer.message_serialize/1)

          new_state = socket.assigns.state
                      |> Map.put("messages", formatted_message )
          push(socket, "sync", new_state)

          # Сразу же запускаю джобу
          Task.start_link(fn ->
            generate_and_stream_ai_response(socket, chat_id, user_message)
          end)

          # Сохраняем обновленное состояние в процессе сокета
          {:reply, :ok, assign(socket, :state, new_state)}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed_to_send_message"}}, socket}
    end


  end
  """
end
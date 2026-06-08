defmodule MessengerWeb.Actions.ChatActions do
  import Phoenix.Channel, only: [push: 3]
  import Phoenix.Socket, only: [assign: 3]
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer

  @doc"""
  SHOW: Функция 'click_open' открывает чат и показывает нам его содержимое
  """
  def handle_in("click_open", payload, socket) do
    current_user = socket.assigns.current_user
    chat_id = Map.get(payload, "chat_id")


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


  @doc"""
  NEW: Функция 'click_new' подготавливает нам создание нового чата
  """
  def handle_in("click_new", _payload, socket) do
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


  @doc"""
  CREATE: Функция 'click_submit' создает - сохраняет в БД новый чат
  """
  def handle_in("click_submit", payload, socket) do
    current_user = socket.assigns.current_user
    ai_profile_id = Map.get(payload, "ai_profile_id")
    system_prompt = Map.get(payload, "system_prompt")

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
        # Достаем таймстамп-курсор
        cursor = last_chat["cursor_timestamp"]

        # Вызываем контекст (limit = 15)
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


  @doc"""
  SHOW_GROUP_CHATS: Функция 'chat:click_go_to_group' показывает чаты конкретной группы
  """
  def handle_in("click_go_to_group", payload, socket) do
    current_user = socket.assigns.current_user
    group_id = Map.get(payload, "group_id")
    chats = Chats.list_user_chats(current_user.id, options: %{"group_id" => group_id})

    formatted_chats =
      case chats do
        {:error, _} -> []
        chts -> Enum.map(chts, &Serializer.chat_serialize/1)
      end

    new_state =
      socket.assigns.state

      |> Map.put("current_screen", "chats")
      |> Map.put("chats_list", formatted_chats)

    push(socket, "sync", new_state)
    {:reply, :ok, assign(socket, :state, new_state)}
  end


  @doc"""
  CREATE_CHAT_GROUP: Функция 'chat:click_submit_chat_group' создаем группу для чатов
  """
  def handle_in("click_submit_chat_group", payload, socket) do
    current_user = socket.assigns.current_user
    title = Map.get(payload, "title")

    case Chats.create_group(%{user_id: current_user.id, title: title}) do
      {:ok, _new_group} ->
        updated_groups = Chats.list_user_groups(current_user.id)
        formatted_groups = Enum.map(updated_groups, &Serializer.group_serialize/1)

        new_state =
          socket.assigns.state

          |> Map.put("current_screen", "chats")
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
  UPDATE_CHAT_GROUP: Функция обновляет группу для чатов, меняем название :UPDATE_TITLE
  """
  def handle_in("click_update_chat_group", %{"group_id" => group_id, "title" => title}, socket) do
    current_user = socket.assigns.current_user

    case Chats.update_group(group_id, current_user.id, %{title: title}) do
      {:ok, _group} ->
        updated_groups = Chats.list_user_groups(current_user.id)
        formatted_groups = Enum.map(updated_groups, &Serializer.group_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("current_screen", "chats")
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
  UPDATE_CHAT_GROUP: Функция обновляет группу, добавляя туда чат :ADD
  """
  def handle_in("click_update_chat_group", %{"chat_id" => chat_id, "group_id" => group_id, "action" => "add"}, socket) do
    current_user = socket.assigns.current_user

    case Chats.add_chat_to_group(chat_id, group_id, current_user.id) do
      {:ok, _group} ->
        updated_chats = Chats.list_user_chats(current_user.id, options: %{"group_id" => group_id})
        formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("current_screen", "chats")
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
  UPDATE_CHAT_GROUP: Функция обновляет группу, удаляя от туда чат :REMOVE
  """
  def handle_in("click_update_chat_group", %{"chat_id" => chat_id, "group_id" => group_id, "action" => "remove"}, socket) do
    current_user = socket.assigns.current_user

    case Chats.remove_chat_from_group(chat_id, current_user.id) do
      {:ok, _group} ->
        updated_chats = Chats.list_user_chats(current_user.id, options: %{"group_id" => group_id})
        formatted_chats = Enum.map(updated_chats, &Serializer.chat_serialize/1)
        new_state = socket.assigns.state

                    |> Map.put("current_screen", "chats")
                    |> Map.put("chats_list", formatted_chats )

        # Шлем обновленный монолит-стейт во фронтенд
        push(socket, "sync", new_state)

        # Сохраняем обновленное состояние в процессе сокета
        {:reply, :ok, assign(socket, :state, new_state)}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed_to_remove_chat_from_group"}}, socket}
    end
  end

end
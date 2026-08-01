defmodule Messenger.Chats do
  import Ecto.Query
  alias Ecto.Multi
  alias Messenger.Repo
  alias Messenger.Chats.{Chat, Message, Group}

  @doc"""
  Функция достает все сообщения из текущего чата пользователя
  """
  def get_chat(user_id, chat_id) do
    Repo.get_by!(Chat, id: chat_id, user_id: user_id)
  end

  @doc """
  Функция get_ai_context это контекст для AI:
  - Если 1-е сообщение имеет роль "system" -> оно всегда идет головой + N последних сообщений
  - Если 1-го системного сообщения нет -> отдаются последние N сообщений
  """
  def get_ai_context(chat_id) do
    # 1) Проверяем первое сообщение в чате
    first_message =
      Message

      |> where(chat_id: ^chat_id)
      |> order_by(asc: :inserted_at)
      |> limit(1)

      |> Repo.one()

    # 2) Вытаскиваем хвост из последних 10 сообщений диалог user и assistant
    recent_messages =
      Message
      |> where(chat_id: ^chat_id)
      |> where([m], m.role in ["user", "assistant"]) # Исключаем system, защита от дублирования

      |> order_by(desc: :inserted_at)
      |> limit(10)
      |> Repo.all()

      |> Enum.reverse() # Разворачиваем хвост в хронологическом порядке

    # 3) Форматируем хвост для API
    formatted_tail = Enum.map(recent_messages, fn msg ->
      %{role: msg.role, content: msg.content}
    end)

    # 4. Формируем итоговый контекст в зависимости от первого сообщения
    case first_message do
      %Message{role: "system"} = sys_msg ->
        # Сценарий с промптом, обязательно ставим его в начало массива
        [%{role: "system", content: sys_msg.content} | formatted_tail]

      _other ->
        # Если без промпта, отдаем только последние сообщения диалога
        formatted_tail
    end
  end

  @doc"""
  Функция отдает список чатов с ограничением с пагинацией по курсору,
  Если before_cursor = nil, возвращаются самые свежие чаты - первая страница
  """
  def list_user_chats(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 15)
    before_cursor = Keyword.get(opts, :before_cursor)
    options = Keyword.get(opts, :options, %{})

    Chat

    |> where([c], c.user_id == ^user_id)
    |> filter_by_group(user_id, options)
    |> filter_by_cursor(before_cursor)

    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # Если group_id передан в строковых значениях с фронта
  defp filter_by_group(query, user_id, %{"group_id" => group_id}) when not is_nil(group_id) do
    query

    |> join(:inner, [c], g in assoc(c, :group))
    |> where([c, g], g.id == ^group_id and g.user_id == ^user_id)
  end

  # Если group_id передан в атомах
  defp filter_by_group(query, user_id, %{group_id: group_id}) when not is_nil(group_id) do
    query

    |> join(:inner, [c], g in assoc(c, :group))
    |> where([c, g], g.id == ^group_id and g.user_id == ^user_id)
  end

  # Если мапа пустая (%{}) или в ней нет нужного ключа
  defp filter_by_group(query, _user_id, _opts), do: query

  # Фильтр по курсору
  defp filter_by_cursor(query, before_cursor) when not is_nil(before_cursor) do
    where(query, [c], c.inserted_at < ^before_cursor)
  end

  defp filter_by_cursor(query, _), do: query



  @doc"""
  Функция забирает из БД сообщения пользователя в текущем чате
  """
  def get_chat_messages(chat_id, user_id, limit \\ 15, before_cursor \\ nil) do
    query = from m in Message,
                 join: c in Chat, on: m.chat_id == c.id,
                 where: c.id == ^chat_id and c.user_id == ^user_id,
                 order_by: [desc: m.inserted_at],
                 limit: ^limit

    query =
      if before_cursor do
        from m in query, where: m.inserted_at < ^before_cursor
      else
        query
      end

    case Repo.all(query) do
      [] -> {:error, :not_found}
      messages -> Enum.reverse(messages)
    end
  end


  @doc"""
  Функция Инициализирующая первое создание чата, запись в БД как Чата так и первое его сообщение с пометкой 'system'
  """
  def create_chat_with_prompt(user_id, ai_profile_id, model_name, title, group_id, system_prompt) do
    Multi.new()
    # 1: Создаем чат со всеми обязательными полями
    |> Multi.insert(:chat, Chat.changeset(%Chat{}, %{
      "user_id" => user_id,
      "group_id" => group_id,
      "ai_profile_id" => String.to_integer(to_string(ai_profile_id)),
      "title" => title,
      "model_name" => model_name
    }))
      # 2: Создаем системное сообщение
    |> Multi.insert(:system_message, fn %{chat: chat} ->
      Message.changeset(%Message{}, %{
        "chat_id" => chat.id,
        "content" => system_prompt,
        "role" => "system"
      })
    end)
    |> Repo.transaction()
  end

  @doc"""
  Обновляем чат
  """
  def update_chat(chat_id, user_id, attrs) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil -> # Если чат не обнаружен
        {:error, :not_found}
      chat ->
        chat
        |> Chat.changeset(attrs)
        |> Repo.update()
    end
  end

  def remove_chat(chat_id, user_id) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil -> {:error, :not_found}
      chat -> Repo.delete(chat)
    end
  end

  @doc"""
  Это участок работы с группами
  """
  # CREATE_GROUP
  def create_group(attrs) do
    %Group{}

    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  # GET_USER_GROUPS
  def list_user_groups(user_id) do
    Group

    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> limit(30)
    |> Repo.all()
  end

  # UPDATE_GROUP
  def update_group(group_id, user_id, attrs) do
    case Repo.get_by(Group, id: group_id, user_id: user_id) do
      nil -> {:error, :not_found}
      group ->
        group
        |> Group.changeset(attrs)
        |> Repo.update()
    end
  end

  # ADD_CHAT_TO_GROUP
  def add_chat_to_group(chat_id, group_id, user_id) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil -> {:error, :not_found}
      chat ->
        chat
        |> Chat.changeset(%{group_id: group_id})
        |> Repo.update()
    end
  end

  # REMOVE_CHAT_FROM_GROUP
  def remove_chat_from_group(chat_id, user_id) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil -> {:error, :not_found}
      chat ->
        chat
        |> Chat.changeset(%{group_id: nil})
        |> Repo.update()
    end
  end

end

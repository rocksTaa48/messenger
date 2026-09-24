defmodule Messenger.Chats do

  import Ecto.Query
  alias Ecto.Multi
  alias Messenger.Repo
  alias Messenger.Chats.{Chat, Message, Group, PinnedChat, ChatSummary}

  @doc"""
  Функция достает все сообщения из текущего чата пользователя
  """
  def get_chat(user_id, chat_id) do
    Repo.get_by!(Chat, id: chat_id, user_id: user_id)
  end

  @doc """
  Функция get_ai_context это контекст для AI:
  """
  def get_ai_context(chat_id) do
    # 1) Вытаскиваем хвост из последних 20 сообщений диалог user и assistant
    recent_messages =
      Message
      |> where(chat_id: ^chat_id)
      |> where([m], m.role in ["user", "assistant"])

      |> order_by(desc: :inserted_at)
      |> limit(20)
      |> Repo.all()

      |> Enum.reverse() # Разворачиваем хвост в хронологическом порядке

    # 2) Форматируем хвост для API
    formatted_tail = Enum.map(recent_messages, fn msg ->
      %{role: msg.role, content: msg.content}
    end)

    formatted_tail
  end

  @doc"""
  Функция отдает список чатов с ограничением с пагинацией по курсору,
  Если before_cursor = nil, возвращаются самые свежие чаты - первая страница
  """
  def list_user_chats(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 15)
    before_cursor = Keyword.get(opts, :before_cursor)
    options = Keyword.get(opts, :options, %{})

    group_id =
      case options do
        %{"group_id" => id} when not is_nil(id) -> id
        %{group_id: id} when not is_nil(id) -> id
        _ -> Keyword.get(opts, :group_id)
      end

    all_pinned_chats = get_pinned_chats(user_id, group_id)
    pinned_ids = Enum.map(all_pinned_chats, & &1.id)

    query = Chat
            |> where([c], c.user_id == ^user_id)
            |> filter_by_group(user_id, options)
            |> filter_by_cursor(before_cursor) # Теперь тут безопасный кастинг строки
            |> exclude_pinned_chats(pinned_ids) # Исключаем закрепы железно
            |> order_by([c], desc: c.inserted_at)
            |> limit(^limit)

    tail_chats = Repo.all(query)

    if is_nil(before_cursor) do
      marked_pinned = Enum.map(all_pinned_chats, &Map.put(&1, :is_pinned, true))
      marked_tail = Enum.map(tail_chats, &Map.put(&1, :is_pinned, false))
      marked_pinned ++ marked_tail
    else
      # На последующих страницах возвращаем только свежую порцию обычных чатов
      Enum.map(tail_chats, &Map.put(&1, :is_pinned, false))
    end
  end

  defp filter_by_cursor(query, before_cursor) when not is_nil(before_cursor) do
    where(query, [c], c.inserted_at < type(^before_cursor, :utc_datetime))
  end

  defp filter_by_cursor(query, _), do: query



  # Получение закрепленных чатов
  defp get_pinned_chats(user_id, group_id) do
    # Сортируем по p.inserted_at (порядок закрепления), но если нужно по алфавиту или обновлению — меняйте тут
    query = from p in PinnedChat,
                 where: p.user_id == ^user_id,
                 join: c in assoc(p, :chat),
                 order_by: [asc: p.inserted_at],
                 limit: 5,
                 select: c

    if is_nil(group_id) do
      Repo.all(from p in query, where: is_nil(p.group_id))
    else
      Repo.all(from p in query, where: p.group_id == ^group_id)
    end
  end

  # Исключение закрепленных по ID
  defp exclude_pinned_chats(query, []), do: query
  defp exclude_pinned_chats(query, pinned_ids) do
    from c in query, where: c.id not in ^pinned_ids
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



  @doc"""
  Функция забирает из БД сообщения пользователя в текущем чате
  """
  def get_chat_messages(chat_id, user_id, limit \\ 15, before_cursor \\ nil) do
    query = from m in Message,
                 where: m.role in ["user", "assistant"], # Исключаем system, его незачем видеть пользователю
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

    Repo.all(query)
    |> Enum.reverse()
  end

  def get_last_message(chat_id) do
    Message
      |> where(chat_id: ^chat_id)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()
  end

  @doc"""
  Блок для получения суммаризации чата
  """
  def get_messages_each_summary(chat_id, chat_summarized_up_to_message_id) do
    last_id = chat_summarized_up_to_message_id || 0
    Message
      |> where(chat_id: ^chat_id)
      |> where([m], m.id > ^last_id)
      |> Repo.aggregate(:count, :id)
  end

  def get_messages_for_summary(chat_id, chat_summarized_up_to_message_id) do
    last_id = chat_summarized_up_to_message_id || 0
    last_messages = Message
                    |> where(chat_id: ^chat_id)
                    |> where([m], m.id > ^last_id)
                    |> where([m], m.role in ["user", "assistant"])
                    |> order_by([asc: :id])
                    |> Repo.all()

    context = Enum.map(last_messages, fn msg -> %{role: msg.role, content: msg.content} end)

    context =
      case context do
        nil -> nil
        "" -> nil
        context -> context
      end

    last_msg_id =
      case List.last(last_messages) do
        nil -> nil
        msg -> msg.id
      end

    {:ok, %{context: context, last_msg_id: last_msg_id}}
  end


  @doc"""
  Функция Инициализирующая первое создание чата, запись в БД как Чата так и первое его сообщение с пометкой 'system'
  """
  def first_time_create_chat_and_message(user_id, content, model_id, is_audio, overrides \\ %{}) do
    last_message = content |> String.slice(0, 100)
    Multi.new()
      # 1: Создаем чат со всеми обязательными полями
    |> Multi.insert(:chat, Chat.changeset(%Chat{}, %{
      "user_id" => user_id,
      "ai_model_id" => String.to_integer(to_string(model_id)),
      "last_message" => last_message,
      "profile_overrides" => overrides
    }))

     # 2: Собственно сообщение от пользователя
    |> Multi.insert(:message, fn %{chat: chat} ->
      Message.changeset(%Message{}, %{
        "chat_id" => chat.id,
        "content" => content,
        "ai_model_id" => String.to_integer(to_string(model_id)),
        "role" => "user",
        "is_audio" => is_audio
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

  # Приколачивает чат в закрепе
  def update_chat_toggle(user_id, chat_id, group_id) do
    search_result =
      if is_nil(group_id) do
        Repo.get_by(PinnedChat, user_id: user_id, chat_id: chat_id)
      else
        Repo.get_by(PinnedChat, user_id: user_id, chat_id: chat_id, group_id: group_id)
      end
    case search_result do
      nil ->
        toggle_attrs = %{user_id: user_id, chat_id: chat_id, group_id: group_id}
        %PinnedChat{}
        |> PinnedChat.changeset(toggle_attrs)
        |> Repo.insert()
      pin -> # Если нашли — удаляем
        Repo.delete(pin)
    end
  end

  def remove_chat(chat_id, user_id) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil -> {:error, :not_found}
      chat -> Repo.delete(chat)
    end
  end

  @doc"""
  -------------------------------------------Это участок работы с группами--------------------------------------
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

  # REMOVE GROUP
  def remove_group(group_id, user_id) do
    case Repo.get_by(Group, id: group_id, user_id: user_id) do
      nil -> {:error, :not_found}
      group -> Repo.delete(group)
    end
  end

  @doc"""
  ----------------------------------------Это участок работы с сообщениями (messages)-------------------------------
  """
  def create_message(chat_id, ai_model_id, is_audio, content) do
    Message.changeset(%Message{}, %{
      "chat_id" => String.to_integer(to_string(chat_id)),
      "ai_model_id" => String.to_integer(to_string(ai_model_id)),
      "content" => content,
      "role" => "user",
      "is_audio" => is_audio
    })
    |> Repo.insert()
  end

  def create_assistant_message(%{
    chat_id: chat_id,
    ai_model_id: ai_model_id,
    content: content,
    role: role,
    tokens_prompt: tokens_prompt,
    tokens_completion: tokens_completion,
    tokens_total: tokens_total,
    cost_prompt: cost_prompt,
    cost_completion: cost_completion,
    cost_total: cost_total,
    is_aborted: is_aborted
  }) do
    last_message = content |> String.slice(0, 100)
    Multi.new()
    |> Multi.insert(:message, Message.changeset(%Message{}, %{
      "chat_id" => String.to_integer(to_string(chat_id)),
      "ai_model_id" => String.to_integer(to_string(ai_model_id)),
      "content" => content || "",
      "role" => role,
      "tokens_prompt" => tokens_prompt || 0,
      "tokens_completion" => tokens_completion || 0,
      "tokens_total" => tokens_total || 0,
      "cost_prompt" => cost_prompt,
      "cost_completion" => cost_completion,
      "cost_total" => cost_total,
      "is_aborted" => is_aborted || false,
    }))

    |> Multi.update(:chat, Chat.changeset_for_update_last_message_or_model(%Chat{id: chat_id}, %{
      "last_message" => last_message,
      "ai_model_id" => String.to_integer(to_string(ai_model_id)),
    }))

    |> Repo.transaction()
  end

  def get_summaries(chat_id) do
    # 1) Достаем старый саммари
    summaries = ChatSummary
                |> where(chat_id: ^chat_id)
                |> order_by(desc: :inserted_at)
                |> limit(3)
                |> Repo.all()
                |> Enum.reverse()

    # 2) Заголовки. Они зависят от количества summary
    headers = case length(summaries) do
      3 -> ["Далёкая история (сжато)", "Средняя история (сжато)", "Недавняя история (подробнее)"]
      2 -> ["Средняя история (сжато)", "Недавняя история (подробнее)"]
      1 -> ["Недавняя история (подробнее)"]
      0 -> []
    end

    # 3) Формируем строку
    context_block = summaries
                    |> Enum.zip(headers)
                    |> Enum.map(fn {summary, header} -> "## #{header}\n#{summary.content}" end)
                    |> Enum.join("\n\n")

    # 4) Оборачиваем в заголовок
    context_block = if context_block == "" do
      ""
    else
      "# Контекст предыдущего диалога\n\n#{context_block}"
    end
  end

  def create_summary(%{
    chat_id: chat_id,
    content: content,
    summarized_up_to_message_id: summarized_up_to_message_id,
    tokens_prompt: tokens_prompt,
    tokens_completion: tokens_completion,
    tokens_total: tokens_total,
    cost_prompt: cost_prompt,
    cost_completion: cost_completion,
    cost_total: cost_total
    }) do
    Multi.new()
    |> Multi.insert(:chat_summary, ChatSummary.changeset(%ChatSummary{}, %{
      "chat_id" => String.to_integer(to_string(chat_id)),
      "content" => content || "",
      "tokens_prompt" => tokens_prompt || 0,
      "tokens_completion" => tokens_completion || 0,
      "tokens_total" => tokens_total || 0,
      "cost_prompt" => cost_prompt,
      "cost_completion" => cost_completion,
      "cost_total" => cost_total
    }))

    |> Multi.update(:chat, Chat.changeset_for_update_summary(%Chat{id: chat_id}, %{
      summarized_up_to_message_id: summarized_up_to_message_id,
    }))

    |> Repo.transaction()
  end

end

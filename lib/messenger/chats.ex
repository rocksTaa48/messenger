defmodule Messenger.Chats do

  import Ecto.Query
  alias Ecto.Multi
  alias Messenger.Repo
  alias Messenger.Accounts.Transaction
  alias Messenger.Chats.{Chat, Message, Group, PinnedChat, ChatSummary, ImageSession, ChatImage}

  @doc"""
  Функция достает все сообщения из текущего чата пользователя
  """
  def get_chat(user_id, chat_id) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil ->
        {:error, :not_found}
      chat ->
        if chat.is_image_session do
          chat
          |> Repo.preload(:image_session)
        else
          chat
        end
    end
  end

  @doc """
  Функция get_ai_context это контекст для AI:
  """
  def get_ai_context(chat_id) do
    Message
    |> where([a], a.chat_id == ^chat_id and a.role == "assistant")
    |> join(:inner, [a], u in Message, on: u.id == a.request_id)
    |> order_by([a, u], desc: a.inserted_at)
    |> limit([a, u], 10)
    |> select([a, u], %{user_msg: u, assistant_msg: a})
    |> Repo.all()
    |> Enum.reverse()
    |> Enum.flat_map(fn %{user_msg: u, assistant_msg: a} ->
      [
        %{role: "user", content: u.content},
        %{role: "assistant", content: a.content}
      ]
    end)
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
    # Сортируем по p.inserted_at (порядок закрепления), но если нужно по алфавиту или обновлению МЕНЯТЬ ЗДЕСЬ
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
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil ->
        []

      chat ->
        query = from m in Message,
                     where: m.chat_id == ^chat.id and m.role in ["user", "assistant"],
                     order_by: [desc: m.inserted_at],
                     limit: ^limit

        query = if before_cursor, do: from(m in query, where: m.inserted_at < ^before_cursor), else: query

        messages = Repo.all(query)

        if chat.is_image_session do
          messages
          |> Repo.preload(:chat_images)
          |> Enum.reverse()
        else
          messages
          |> Enum.reverse()
        end
    end
  end

  def get_last_message(chat_id) do
    Message
      |> where(chat_id: ^chat_id)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()
  end

  def get_message(message_id) do
    Repo.get(Message, message_id)
  end

  @doc"""
  Блок для получения суммаризации чата
  """
  def count_pairs_for_summary(chat_id, chat_summarized_up_to_message_id) do
    last_id = chat_summarized_up_to_message_id || 0

    Message
    |> where([a], a.chat_id == ^chat_id)
    |> where([a], a.role == "assistant")
    |> where([a], a.id > ^last_id)
    |> where([a], a.content != "" and a.is_aborted != true)
    |> join(:inner, [a], u in Message, on: u.id == a.request_id)
    |> Repo.aggregate(:count, :id)
  end

  def get_messages_for_summary(chat_id, chat_summarized_up_to_message_id) do
    last_id = chat_summarized_up_to_message_id || 0
    raw_context =
      Message
      |> where([a], a.chat_id == ^chat_id and a.role == "assistant")
      |> where([a], a.id > ^last_id)
      |> where([a], a.content != "" and a.is_aborted == false)
      |> join(:inner, [a], u in Message, on: u.id == a.request_id)
      |> order_by([a, u], desc: a.id)
      |> select([a, u], %{user_msg: u, assistant_msg: a})
      |> Repo.all()
      |> Enum.reverse()
    context =
      Enum.flat_map(raw_context, fn %{user_msg: u, assistant_msg: a} ->
        [
          %{role: "user", content: u.content},
          %{role: "assistant", content: a.content}
        ]
      end)
    last_msg_id =
      case List.last(raw_context) do
        nil -> chat_summarized_up_to_message_id
        %{assistant_msg: a} -> a.id
      end

    {:ok, %{context: context, last_msg_id: last_msg_id}}
  end

  @doc"""
  Обновляем чат
  """
  def update_chat(chat_id, user_id, attrs) do
    IO.inspect(attrs, label: "chat update ATTRS !__!_!_!_!_!!_!_!__!!_!_!__!_!!!!_!_!_!_!")
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      chat ->
        multi =
          Multi.new()
          |> Multi.update(:chat, Chat.changeset(chat, attrs))
        multi =
          if chat.is_image_session do
            Multi.run(multi, :image_session, fn repo, %{chat: updated_chat} ->
              update_image_session(repo, updated_chat, attrs)
            end)
          else
            multi
          end
        Repo.transaction(multi)
    end
  end

  defp update_image_session(repo, %{is_image_session: true, id: chat_id}, attrs) do
    image_model_id = attrs[:image_ai_model_id] || attrs["image_ai_model_id"]

    case {repo.get_by(ImageSession, chat_id: chat_id), image_model_id} do
      {nil, _} ->
        {:error, :image_session_not_found}

      {session, nil} ->
        # Если модель картинок не передавали, просто возвращаем сессию без изменений
        {:ok, session}

      {session, model_id} ->
        session
        |> ImageSession.changeset(%{ai_model_id: model_id})
        |> repo.update()
    end
  end

  defp update_image_session(_repo, _chat, _attrs), do: {:ok, nil}

  @doc"""
  Обновляем чат TITLE
  """
  def update_chat_title_with_ai(%{
    user_id: user_id,
    chat_id: chat_id,
    ai_model_id: ai_model_id,
    content: content,
    tokens_prompt: tokens_prompt,
    tokens_completion: tokens_completion,
    tokens_total: tokens_total,
    cost_prompt: cost_prompt,
    cost_completion: cost_completion,
    cost_total: cost_total,
  }) do
    chat = Repo.get_by(Chat, id: chat_id, user_id: user_id)
    Multi.new()
    |> Multi.update(:chat, Chat.changeset(chat, %{"title" => content}))
    |> Multi.insert(:transaction, Transaction.changeset(%Transaction{}, %{
      "user_id" => user_id,
      "tokens_prompt" => tokens_prompt || 0,
      "tokens_completion" => tokens_completion || 0,
      "tokens_total" => tokens_total || 0,
      "cost_prompt" => cost_prompt,
      "cost_completion" => cost_completion,
      "cost_total" => cost_total,
      "ai_model_id" => ai_model_id,
      "metadata" =>  %{"action" => "chat_ai_update_title", "chat_id" => chat_id},
    }))
    |> Repo.transaction()
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
      nil ->
        {:error, :not_found}
      chat ->
        Repo.delete(chat)
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
        case chat.group_id do
          nil ->
            chat
            |> Chat.changeset(%{group_id: group_id})
            |> Repo.update()
          id ->
            if id == group_id do
              {:ok, chat}
            else
              Multi.new()
              |> Multi.update(:chat, Chat.changeset(chat, %{group_id: group_id}))
              |> Multi.delete_all(:pinned_chat,
                   from(p in PinnedChat, where: p.chat_id == ^chat_id and p.user_id == ^user_id and p.group_id == ^id)
                 )
              |> Repo.transaction()
            end
        end
    end
  end

  # REMOVE_CHAT_FROM_GROUP
  def remove_chat_from_group(chat_id, user_id) do
    case Repo.get_by(Chat, id: chat_id, user_id: user_id) do
      nil ->
        {:error, :not_found}
      chat ->
        group_id = chat.group_id
        Multi.new()
        |> Multi.update(:chat, Chat.changeset(chat, %{group_id: nil}))
        |> Multi.delete_all(:pinned_chat,
             from(p in PinnedChat, where: p.chat_id == ^chat_id and p.user_id == ^user_id and p.group_id == ^group_id)
           )
        |> Repo.transaction()
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
  def create_user_message(attrs) do
    user_id = Map.fetch!(attrs, "user_id")
    ai_model_id = Map.fetch!(attrs, "ai_model_id")
    image_ai_model_id = Map.get(attrs, "image_ai_model_id")
    chat_id = Map.get(attrs, "chat_id")
    chat = if chat_id, do: Repo.get_by(Chat, id: chat_id, user_id: user_id), else: nil
    overrides = Map.get(attrs, "overrides")
    content = Map.get(attrs, "content")
    is_audio = Map.get(attrs, "is_audio",false)
    is_image_session = Map.get(attrs, "is_image_session", false)
    case chat do
      nil ->
        last_message = content |> String.slice(0, 100)
        Multi.new()

        # 1: Создаем чат со всеми обязательными полями
        |> Multi.insert(:chat, Chat.changeset(%Chat{}, %{
          "user_id" => user_id,
          "ai_model_id" => String.to_integer(to_string(ai_model_id)),
          "last_message" => last_message,
          "profile_overrides" => overrides,
          "is_image_session" => is_image_session
        }))

          # 2: Собственно сообщение от пользователя
        |> Multi.insert(:message, fn %{chat: chat} ->
          Message.changeset(%Message{}, %{
            "chat_id" => chat.id,
            "content" => content,
            "ai_model_id" => String.to_integer(to_string(ai_model_id)),
            "role" => "user",
            "is_audio" => is_audio
          })
        end)

          # 3: Инициализируем ImageSession при старте чата
        |> Multi.run(:image_session, fn repo, %{chat: chat} ->
          if is_image_session do
            repo.insert(ImageSession.changeset(
              %ImageSession{}, %{
                "chat_id" => chat.id,
                "ai_model_id" => String.to_integer(to_string(image_ai_model_id))
              })
            )
          else
            {:ok, nil}
          end
        end)

        |> Repo.transaction()
      chat ->
        last_message = content |> String.slice(0, 100)
        Multi.new()
        |> Multi.insert(:message, Message.changeset(%Message{}, %{
          "chat_id" => String.to_integer(to_string(chat.id)),
          "ai_model_id" => String.to_integer(to_string(ai_model_id)),
          "content" => content,
          "role" => "user",
          "is_audio" => is_audio
        }))

        |> Multi.update(:chat, Chat.changeset_for_update_last_message_or_model(chat, %{
          "last_message" => last_message,
        }))

        |> Repo.transaction()
    end
  end

  def create_assistant_message(%{
    user_id: user_id,
    chat_id: chat_id,
    ai_model_id: ai_model_id,
    request_id: request_id,
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
    chat = Repo.get(Chat, chat_id)
    Multi.new()
    |> Multi.insert(:message, Message.changeset(%Message{}, %{
      "chat_id" => String.to_integer(to_string(chat_id)),
      "ai_model_id" => String.to_integer(to_string(ai_model_id)),
      "request_id" => request_id,
      "content" => content || "",
      "role" => role,
      "is_aborted" => is_aborted || false,
    }))

    |> Multi.insert(:transaction, Transaction.changeset(%Transaction{}, %{
      "user_id" => user_id,
      "tokens_prompt" => tokens_prompt || 0,
      "tokens_completion" => tokens_completion || 0,
      "tokens_total" => tokens_total || 0,
      "cost_prompt" => cost_prompt,
      "cost_completion" => cost_completion,
      "cost_total" => cost_total,
      "ai_model_id" => ai_model_id,
      "metadata" =>  %{"action" => "chat_ai_response", "chat_id" => chat_id},
    }))

    |> Multi.update(:chat, Chat.changeset_for_update_last_message_or_model(chat, %{
      "last_message" => last_message,
      "ai_model_id" => String.to_integer(to_string(ai_model_id)),
    }))

    |> Repo.transaction()
  end

  def create_chat_image(attrs) when is_map(attrs) do
    %ChatImage{}
    |> ChatImage.changeset(attrs)
    |> Repo.insert()
  end

  def get_image_session(image_session_id) do
    case Repo.get_by(ImageSession, id: image_session_id) do
      nil ->
        {:error, :not_found}
      session ->
        session
    end
  end

  def update_image_session(image_session_id, attrs) do
    case Repo.get_by(ImageSession, id: image_session_id) do
      nil ->
        {:error, :not_found}
      session ->
        ImageSession.changeset(session, attrs)
        |> Repo.update()
    end
  end

  def remove_group(group_id, user_id) do
    case Repo.get_by(Group, id: group_id, user_id: user_id) do
      nil -> {:error, :not_found}
      group -> Repo.delete(group)
    end
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
    user_id: user_id,
    chat_id: chat_id,
    ai_model_id: ai_model_id,
    content: content,
    summarized_up_to_message_id: summarized_up_to_message_id,
    tokens_prompt: tokens_prompt,
    tokens_completion: tokens_completion,
    tokens_total: tokens_total,
    cost_prompt: cost_prompt,
    cost_completion: cost_completion,
    cost_total: cost_total
    }) do
    chat = Repo.get(Chat, chat_id)

    Multi.new()

    |> Multi.insert(:chat_summary, ChatSummary.changeset(%ChatSummary{}, %{
      "chat_id" => String.to_integer(to_string(chat_id)),
      "content" => content || ""
    }))

    |> Multi.insert(:transaction, Transaction.changeset(%Transaction{}, %{
      "user_id" => user_id,
      "tokens_prompt" => tokens_prompt || 0,
      "tokens_completion" => tokens_completion || 0,
      "tokens_total" => tokens_total || 0,
      "cost_prompt" => cost_prompt,
      "cost_completion" => cost_completion,
      "cost_total" => cost_total,
      "ai_model_id" => ai_model_id,
      "metadata" =>  %{"action" => "chat_ai_summary", "chat_id" => chat_id},
    }))

    |> Multi.update(:chat, Chat.changeset_for_update_summary(chat, %{
      summarized_up_to_message_id: summarized_up_to_message_id,
    }))

    |> Repo.transaction()
  end

  def mark_message_completed(message_id) do
    case Repo.get_by(Message, id: message_id) do
      nil -> {:error, :not_found}
      message ->
        message
        |> Message.changeset(%{status: "completed"})
        |> Repo.update()
    end
  end


end

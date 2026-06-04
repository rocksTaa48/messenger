defmodule Messenger.Chats do
  import Ecto.Query
  alias Ecto.Multi
  alias Messenger.Repo
  alias Messenger.Chats
  alias Messenger.Chats.{Chat, Message}

  @doc"""
  Функция достает все сообщения из текущего чата пользователя
  """
  def get_chat_messages(chat_id) do
    messages =
      Message

      |> where(chat_id: ^chat_id)
      |> order_by(desc: :inserted_at)
      |> limit(15)
      |> Repo.all()
      |> Enum.reverse()
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
  def list_user_chats(user_id, limit \\ 15, before_cursor \\ nil) do
    # Базовый запрос: ищем чаты пользователя, сортируем от новых к старым
    query =
      from c in Chat,
           where: c.user_id == ^user_id,
           order_by: [desc: c.inserted_at],
           limit: ^limit

    # Если фронтенд передал курсор (время последнего чата),
    # отсекаем всё, что было создано ПОСЛЕ - берем более старые чаты
    query =
      if before_cursor do
        from c in query, where: c.inserted_at < ^before_cursor
      else
        query
      end

    Repo.all(query)
  end


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
  Функция создает запись в БД как Чата так и первое его сообщение с пометкой 'system'
  """
  def create_chat_with_prompt(user_id, ai_profile_id, model_name, title, system_prompt) do
    Multi.new()
    # 1: Создаем чат со всеми обязательными полями
    |> Multi.insert(:chat, Chat.changeset(%Chat{}, %{
      "user_id" => user_id,
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
  Функция ЗАГЛУШКА отдает список доступных для конкретного пользователя моделей ИИ (AI_PROFILES)
  """
  def list_user_ai_profiles(user_id) do
    [
      %{"id" => "gpt_4o", "name" => "ChatGPT 4o", "icon" => "openai", "color" => "text-emerald-400"},
      %{"id" => "claude_3b", "name" => "Claudecode", "icon" => "claude", "color" => "text-emerald-400"},
      %{"id" => "deepseek_v3", "name" => "DeepSeek V3", "icon" => "deepseek", "color" => "text-blue-400"},
      %{"id" => "qwen_2_5", "name" => "Qwen 2.5 (Alibaba)", "icon" => "qween", "color" => "text-purple-400"}
    ]
  end
end

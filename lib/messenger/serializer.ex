defmodule Messenger.Serializer do

  # Сериализуем сообщение
  def message_serialize(message) do
    %{
      "id" => to_string(message.id),
      "text" => message.content,
      "role" => if(message.role == "user", do: "me", else: "other"),
      "created_at" => DateTime.to_iso8601(message.inserted_at)
    }
  end

  # Сериализуем группу чатов
  def group_serialize(group) do
    %{
      "id" => to_string(group.id),
      "title" => group.title,
      "created_at" => DateTime.to_iso8601(group.inserted_at)
    }
  end

  # Сериализуем AI_PROFILE
  def ai_profile_serialize(ai_profile) do
    %{
      "id" => to_string(ai_profile.id),
      "name" => ai_profile.name,
      "provider" => ai_profile.provider || "Без названия",
      "model" => ai_profile.model,
      "timestamp" => DateTime.to_iso8601(ai_profile.inserted_at),
      "variant" => if(ai_profile.user_id != nil, do: "personal", else: "global")
      # "status" => if(chat.has_unread, do: "unread", else: "read"),
      # "unread_count" => chat.unread_count || 0,
      # Строковые алиасы для фронтенда, чтобы не тащить JS-классы через JSON
      # "icon_type" => chat.bot_type || "default", # "bot", "image", "sparkles"
      # "icon_color" => chat.ui_color || "text-[#2481cc] bg-[#2481cc]/10"
    }
  end

  # Сериализуем Чат
  def chat_serialize(chat) do
    %{
      "id" => to_string(chat.id),
      "title" => chat.title || "Без названия",
      "body" => "Нет сообщений",
      "model" => chat.model_name || "Нет модели",
      "group_id" => chat.group_id || nil,
      "cursor_timestamp" => DateTime.to_iso8601(chat.inserted_at)
      # "status" => if(chat.has_unread, do: "unread", else: "read"),
      # "unread_count" => chat.unread_count || 0,
      # Строковые алиасы для фронтенда, чтобы не тащить JS-классы через JSON
      # "icon_type" => chat.bot_type || "default", # "bot", "image", "sparkles"
      # "icon_color" => chat.ui_color || "text-[#2481cc] bg-[#2481cc]/10"
    }
  end
end
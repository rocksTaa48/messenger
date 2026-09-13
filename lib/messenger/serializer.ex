defmodule Messenger.Serializer do

  # Сериализуем сообщение
  def message_serialize(message) do
    %{
      "id" => to_string(message.id),
      "content" => message.content,
      "role" => message.role,
      "created_at" => DateTime.to_iso8601(message.inserted_at),
      "cursor_timestamp" => DateTime.to_iso8601(message.inserted_at)
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
      "model" => ai_profile.ai_model.model_name,
      "display_name" => ai_profile.display_name || "Без имени",
      "display_description" => ai_profile.display_description || "Без описания",
      "tier" => ai_profile.tier || "Отсутствует",

      "timestamp" => DateTime.to_iso8601(ai_profile.inserted_at),
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
      "ai_profile_id" => chat.ai_profile_id || nil,
      "cursor_timestamp" => DateTime.to_iso8601(chat.inserted_at),
      "is_pinned" => Map.get(chat, :is_pinned, false),
      "last_message" => chat.last_message || "Нет сообщений"
    }
  end
end
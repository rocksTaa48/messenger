defmodule Messenger.Serializer do

  # Сериализуем сообщение
  def message_serialize(message) do
    %{
      "id" => to_string(message.id),
      "content" => message.content,
      "role" => message.role,
      "ai_model_id" => to_string(message.ai_model_id) || nil,
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
      "display_name" => ai_profile.display_name || "Без имени",
      "display_description" => ai_profile.display_description || "Без описания",
      "temperature" => ai_profile.temperature || nil,
      "top_p" => ai_profile.top_p || nil,
      "frequency_penalty" => ai_profile.frequency_penalty || nil,
      "presence_penalty" => ai_profile.presence_penalty || nil,
      "tier" => ai_profile.tier || "Отсутствует",

      "timestamp" => DateTime.to_iso8601(ai_profile.inserted_at),
    }
  end

  def ai_model_serialize(ai_model) do
    %{
      "id" => to_string(ai_model.id),
      "model_name" => ai_model.model_name,
      "provider" => ai_model.provider,
      "display_name" => ai_model.display_name || "Без имени",
      "display_description" => ai_model.display_description || "Без описания",
      "display_icon" => ai_model.display_icon || "",
      "tier" => ai_model.tier || "Отсутствует",

      "timestamp" => DateTime.to_iso8601(ai_model.inserted_at),
    }
  end

  # Сериализуем Чат
  def chat_serialize(chat) do
    %{
      "id" => to_string(chat.id),
      "title" => chat.title || "Без названия",
      "group_id" => chat.group_id || nil,
      "ai_model_id" => to_string(chat.ai_model_id) || nil,
      "cursor_timestamp" => DateTime.to_iso8601(chat.inserted_at),
      "is_pinned" => Map.get(chat, :is_pinned, false),
      "last_message" => chat.last_message || "Нет сообщений"
    }
  end

  def profile_for_api_serialize(profile) do
    profile
    |> Map.update(:temperature, nil, &to_float/1)
    |> Map.update(:top_p, nil, &to_float/1)
    |> Map.update(:presence_penalty, nil, &to_float/1)
    |> Map.update(:frequency_penalty, nil, &to_float/1)
  end

  defp to_float(v) when is_float(v),   do: v
  defp to_float(v) when is_integer(v), do: v * 1.0

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, ""} -> f
      _       -> nil
    end
  end

  defp to_float(_), do: nil
end
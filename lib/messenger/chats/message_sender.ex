defmodule Messenger.Chats.MessageSender do
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer
  alias Messenger.Ai.{MessageStreaming, CreateSummaryForChat, CreateTitleForChat}

  def create_message(current_user, payload) do
    is_audio = Map.get(payload, "is_audio")
    content = Map.get(payload, "text")
    temp_id = Map.get(payload, "temp_id")
    chat_id = Map.get(payload, "chat_id")

    case Chats.ChatsBuilder.build_ai_profile(current_user, payload) do
      nil ->
        {:error, "build profile error"}
      {:ok, %{ai_model: ai_model, ai_profile: ai_profile}} ->
        IO.inspect(ai_model, label: "ПЭЁЛОАД КОТОРЫЙ ОТДАЛ В БИЛДЕР - МОДЕЛЬ")
        IO.inspect(ai_profile, label: "ПЭЁЛОАД КОТОРЫЙ ОТДАЛ В БИЛДЕР - ПРОФИЛЬ")
        send_run(%{
        "user_id" => current_user.id,
        "user_status" => current_user.status,
        "chat_id" => chat_id,
        "temp_id" => temp_id,
        "content" => content,
        "is_audio" => is_audio,
        "ai_profile" => ai_profile,
        "ai_model" => ai_model
        })
    end
  end

  def retry_message(current_user, payload) do
    chat_id = Map.fetch!(payload, "chat_id")
    message_id = Map.fetch!(payload, "message_id")
    temp_id = Map.get(payload, "temp_id")

    case Chats.get_chat(current_user.id, chat_id) do
      nil ->
        {:error, :chat_not_found}

      chat ->
        case Chats.get_message(message_id) do
          nil ->
            {:error, :message_not_found}

          message ->
            case Chats.ChatsBuilder.build_ai_profile(current_user, payload) do
              nil ->
                {:error, :build_profile_failed}

              {:ok, %{ai_model: ai_model, ai_profile: ai_profile}} ->
                serialized_ai_profile = Serializer.profile_for_api_serialize(ai_profile)
                trigger_stream(current_user, chat, message, ai_model, serialized_ai_profile, temp_id)
                {:ok, chat, message}
            end
        end
    end
  end


  defp send_run(attrs) do
    ai_model = Map.fetch!(attrs, "ai_model")
    ai_profile = Map.fetch!(attrs, "ai_profile")
    user_id = Map.fetch!(attrs, "user_id")
    user_status = Map.fetch!(attrs, "user_status")

    chat_id = Map.get(attrs, "chat_id")
    content = Map.get(attrs, "content")
    is_audio = Map.get(attrs, "is_audio")
    temp_id = Map.get(attrs, "temp_id")

    naming_ai_profile =  AiProfiles.get_default_system_user_ai_profile("naming", user_status)
    serialized_ai_profile = Serializer.profile_for_api_serialize(ai_profile)
    overrides = ai_profile |> Map.take([:temperature, :top_p, :presence_penalty, :frequency_penalty])

    complete_attrs = %{
      "ai_model_id" => ai_model.id,
      "chat_id" => chat_id,
      "content" => content,
      "overrides" => overrides,
      "user_id" => user_id,
      "is_audio" => is_audio,
    }
    IO.inspect(complete_attrs, label: "Это пайлоад который попал в CREATE <--------------------------------------------------")

    case Chats.create_user_message(complete_attrs) do
      {:error, _failed_step, _failed_value, _changesets} ->
        {:error, IO.inspect(_changesets, label: "db_insert_failed")}

      {:ok, %{chat: chat, message: message}} ->
        # Если чата в вызове небыло, то стартуем нейминг, так как пишем в новом чате
        unless chat_id do
          CreateTitleForChat.start_generation(%{
            "user_id" => user_id,
            "chat_id" => chat.id,
            "ai_model" => ai_model,
            "ai_profile" => naming_ai_profile,
            "content" => message.content
          })
        end
        # Собираем контекст суммаризация и предыдушие сообщения
        summaries = Chats.get_summaries(chat.id)
        context = Chats.get_ai_context(chat.id)

        MessageStreaming.start_generation(%{
          "user_id" => user_id,
          "chat_id" => chat.id,
          "ai_model" => ai_model,
          "ai_profile" => serialized_ai_profile,
          "context" => context,
          "content" => message.content,
          "summaries" => summaries,
          "temp_id" => temp_id,
          "request_id" => message.id
        })
        # Щупаем суммаризатор на его необходимость
        start_summary(user_id, user_status, ai_model, chat.id, chat.summarized_up_to_message_id)
        {:ok, chat, message}
    end
  end

  defp trigger_stream(current_user, chat, message, ai_model, serialized_ai_profile, temp_id) do
    summaries = Chats.get_summaries(chat.id)
    context = Chats.get_ai_context(chat.id)

    MessageStreaming.start_generation(%{
      "user_id" => current_user.id,
      "chat_id" => chat.id,
      "ai_model" => ai_model,
      "ai_profile" => serialized_ai_profile,
      "context" => context,
      "content" => message.content,
      "summaries" => summaries,
      "temp_id" => temp_id,
      "request_id" => message.id
    })

    start_summary(current_user.id, current_user.status, ai_model, chat.id, chat.summarized_up_to_message_id)
  end

  defp start_summary(user_id, user_status, ai_model, chat_id, summarized_up_to_message_id) do
    count = Chats.count_pairs_for_summary(chat_id, summarized_up_to_message_id)
    # Если пар :user\:assistant более 10, тоесть 20 сообщений, то включаем суммаризацию
    if count >= 10 do
      # получаем системный профиль для суммаризатора
      ai_profile =  AiProfiles.get_default_system_user_ai_profile("summary", user_status)
      # get_messages_for_summary/2 отдает не только последние сообщения от summarized_up_to_message_id,
      # но и старый summary что бы его не забыть.
      summary_context = Chats.get_messages_for_summary(chat_id, summarized_up_to_message_id)

      case summary_context do
        {:ok, %{context: [], last_msg_id: nil}} ->
          :ok
        {:ok, %{context: context, last_msg_id: last_msg_id}} ->
          CreateSummaryForChat.start_generation(%{
            "user_id" => user_id,
            "chat_id" => chat_id,
            "ai_model" => ai_model,
            "ai_profile" => ai_profile,
            "context" => context,
            "last_msg_id" => last_msg_id
          })
        {:error, _} ->
          :ok
      end
    end
  end
end
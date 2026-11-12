defmodule Messenger.Chats.MessageSender do
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer
  alias Messenger.Ai.{MessageStreaming, CreateSummaryForChat, CreateTitleForChat, CreateOrchestratorMessage}

  def create_message(current_user, data) do
    case Chats.ChatsBuilder.build_ai_profile(current_user, data) do
      nil ->
        {:error, "build profile error"}
      {:ok, %{ai_model: ai_model, image_session: image_session, ai_profile: ai_profile}} ->
        unless handle_session(image_session) do
          send_run(%{
            "user_id" => current_user.id,
            "user_status" => current_user.status,
            "chat_id" => data.chat_id,
            "temp_id" => data.temp_id,
            "content" => data.text,
            "is_audio" => data.is_audio,
            "ai_profile" => ai_profile,
            "ai_model" => ai_model
          })
        else
          send_orchestrator_run(current_user, %{
            "chat_id" => data.chat_id,
            "temp_id" => data.temp_id,
            "content" => data.text,
            "is_audio" => data.is_audio,
            "ai_profile" => ai_profile,
            "ai_model" => ai_model,
            "image_session" => image_session
          })
        end
    end
  end

  def retry_message(current_user, data) do
    case Chats.get_chat(current_user.id, data.chat_id) do
      nil ->
        {:error, :chat_not_found}

      chat ->
        case Chats.get_message(data.message_id) do
          nil ->
            {:error, :message_not_found}

          message ->
            case Chats.ChatsBuilder.build_ai_profile(current_user, data) do
              nil ->
                {:error, :build_profile_failed}

              {:ok, %{ai_model: ai_model,image_session: image_session, ai_profile: ai_profile}} ->
                serialized_ai_profile = Serializer.profile_for_api_serialize(ai_profile)
                trigger_stream(current_user, chat, message, ai_model, serialized_ai_profile, data.temp_id)
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
        {:ok, %{chat: chat, message: message}}
    end
  end

  defp send_orchestrator_run(current_user, attrs) do
    ai_model = Map.fetch!(attrs, "ai_model")
    ai_profile = Map.fetch!(attrs, "ai_profile")
    image_ai_model_id = Map.fetch!(attrs, "image_session").ai_model_id
    chat_id = Map.get(attrs, "chat_id")
    content = Map.get(attrs, "content")
    is_audio = Map.get(attrs, "is_audio")
    temp_id = Map.get(attrs, "temp_id")

    naming_ai_profile =  AiProfiles.get_default_system_user_ai_profile("naming", current_user.status)
    serialized_ai_profile = Serializer.profile_for_api_serialize(ai_profile)
    overrides = ai_profile |> Map.take([:temperature, :top_p, :presence_penalty, :frequency_penalty])

    complete_attrs = %{
      "ai_model_id" => ai_model.id,
      "chat_id" => chat_id,
      "content" => content,
      "overrides" => overrides,
      "user_id" => current_user.id,
      "is_audio" => is_audio,
      "image_ai_model_id" => image_ai_model_id,
      "is_image_session" => true
    }

    case Chats.create_user_message(complete_attrs) do
      {:error, _failed_step, _failed_value, _changesets} ->
        {:error, IO.inspect(_changesets, label: "db_insert_failed")}

      {:ok, %{chat: chat, message: message}} ->
        # Если чата в вызове небыло, то стартуем нейминг, так как пишем в новом чате
        unless chat_id do
          CreateTitleForChat.start_generation(%{
            "user_id" => current_user.id,
            "chat_id" => chat.id,
            "ai_model" => ai_model,
            "ai_profile" => naming_ai_profile,
            "content" => message.content
          })
        end

        # Собираем контекст
        context = Chats.get_ai_context(chat.id)
        image_ai_model = AiProfiles.get_ai_model(image_ai_model_id)
        CreateOrchestratorMessage.start_generation(current_user, %{
          "chat_id" => chat.id,
          "ai_model" => ai_model,
          "ai_profile" => serialized_ai_profile,
          "image_ai_model" => image_ai_model,
          "context" => context,
          "content" => message.content,
          "temp_id" => temp_id,
          "request_id" => message.id
        })
        {:ok, %{chat: chat, message: message}}
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

  defp handle_session(session) when session in [%{}, nil, false], do: false
  defp handle_session(%{} = session), do: true
end
defmodule Messenger.Chats.ChatsBuilder do
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer

  def create_message_in_chat(user, payload) do
    IO.inspect(payload, label: "Это пайлоад который попал в экшен <--------------------------------------------------")

    content = Map.get(payload, "text")
    temp_id = Map.get(payload, "temp_id")
    chat_id = Map.get(payload, "chat_id")
    chat = if chat_id, do: Chats.get_chat(user.id, chat_id), else: nil

    case build_ai_profile(user, payload) do
      {:ok, %{model: model, profile: profile}} ->
        create_message_in_existing_chat(user, model, profile, chat, content, temp_id)
    end
  end

  def create_first_message(user, payload) do
    IO.inspect(payload, label: "Это пайлоад который попал в экшен <--------------------------------------------------")
    content = Map.get(payload, "text")
    temp_id = Map.get(payload, "temp_id")
    case build_ai_profile(user, payload) do
      {:ok, %{model: model, profile: profile}} ->
        create_chat_and_first_message(user, model, profile, content, temp_id)
    end
  end

  @doc"""
  Собирает актуальный стейт, приоритетной модели и приоритетных настроек
  для отправки в модель перед генерацией.
  """
  def build_ai_profile(current_user, payload \\ %{}) do
    chat_id = Map.get(payload, "chat_id")
    chat = if chat_id, do: Chats.get_chat(current_user.id, chat_id), else: nil
    default_user_ai_profile = AiProfiles.get_default_user_ai_profile(current_user.status) # Default user AiProfile
    ai_models = AiProfiles.get_all_users_ai_models() # All models in application
    user_ai_profile = current_user.profile_overrides || %{} # User ai_profile overrides top_p, temperature...
    user_ai_model_id = current_user.ai_model_id # User global ai_model (change in settings user profile)

    payload_ai_model_id = Map.get(payload, "ai_model_id") # Get ai_model_id
    payload_overrides = Map.get(payload, "profile_overrides") || %{} # Get chat_ai_profile_overrides

    available_user_models = Enum.filter(ai_models, fn m -> m.tier == current_user.status and m.is_active == true end)

    user_overrides =
      user_ai_profile
      |> Map.take(["temperature", "top_p", "presence_penalty", "frequency_penalty"])
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    case chat do
      nil ->
        overrides =
          payload_overrides
          |> Map.take(["temperature", "top_p", "presence_penalty", "frequency_penalty"])
          |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

        current_ai_model =
          with nil <- Enum.find(available_user_models, fn m -> m.id == payload_ai_model_id end),
               nil <- Enum.find(available_user_models, fn m -> m.id == user_ai_model_id end) do
            Enum.find(ai_models, fn m -> m.tier == current_user.status and m.is_active == true and m.is_default == true end)
          else
            model -> model
          end

        current_ai_profile =
          default_user_ai_profile
          |> Map.from_struct()
          |> Map.merge(user_overrides)
          |> Map.merge(overrides)

        {:ok, %{model: current_ai_model, profile: current_ai_profile}}

      chat ->
        current_chat_ai_profile = chat.profile_overrides || %{}
        current_chat_model_id = chat.ai_model_id

        current_ai_model =
          with nil <- Enum.find(available_user_models, fn m -> m.id == current_chat_model_id end),
               nil <- Enum.find(available_user_models, fn m -> m.id == user_ai_model_id end) do
            Enum.find(ai_models, fn m -> m.tier == current_user.status and m.is_active == true and m.is_default == true end)
          else
            model -> model
          end

        chat_overrides =
          current_chat_ai_profile
          |> Map.take(["temperature", "top_p", "presence_penalty", "frequency_penalty"])
          |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

        current_ai_profile =
          default_user_ai_profile
          |> Map.from_struct()
          |> Map.merge(user_overrides)
          |> Map.merge(chat_overrides)

        {:ok, %{model: current_ai_model, profile: current_ai_profile}}
    end
  end

  @doc"""
  Создает сообщение в первый раз, вместе с чатом и настройками из payload
  """
  defp create_chat_and_first_message(user, model, profile, content, temp_id) do
    naming_ai_profile =  AiProfiles.get_default_system_user_ai_profile(user.status, "naming")
    serialized_profile = Serializer.profile_for_api_serialize(profile)
    overrides = profile |> Map.take([:temperature, :top_p, :presence_penalty, :frequency_penalty])
    IO.inspect(overrides, label: "<_________________CREATE MESSAGE OVERRIDES INSPECT")

    case Chats.first_time_create_chat_and_message(user.id, content, model.id, overrides) do

      {:ok, %{chat: chat, message: message}} ->
        context = Chats.get_ai_context(chat.id)
        Chats.ChatsAgent.start_and_process(user.id, chat.id, model, serialized_profile, context, temp_id)
        Chats.ChatNameCreator.start_generation(user.id, chat.id, model, naming_ai_profile, content)
        {:ok, chat, message}
      {:error, _failed_step, _failed_value, _changesets} ->
        {:error, "db_insert_failed"}
    end
  end

  @doc"""
  Создает сообщение уже в существующем чате, настройки подтягиваются из БД
  """
  defp create_message_in_existing_chat(user, model, profile, chat, content, temp_id) do
    case Chats.create_message(chat.id, model.id, content) do
      {:ok, message} ->
        context = Chats.get_ai_context(chat.id)
        serialized_profile = Serializer.profile_for_api_serialize(profile)
        Chats.ChatsAgent.start_and_process(user.id, chat.id, model, serialized_profile, context, temp_id)
        start_summary(user, model, chat)
        {:ok, chat, message}
      {:error, _changeset} ->
        {:error, "message_insert_failed"}
    end
  end

  @doc"""
  HELPER start_summary: Запускает процесс суммаризации истории чата, для экономии токенов
  """
  defp start_summary(user, model, chat) do
    count = Chats.get_messages_each_summary(chat.id, chat.summarized_up_to_message_id)
    if count >= 20 do
      # получаем системный профиль для суммаризатора
      naming_ai_profile =  AiProfiles.get_default_system_user_ai_profile(user.status, "summary")
      # get_messages_for_summary/3 отдает не только последние сообщения от summarized_up_to_message_id,
      # но и старый summary что бы его не забыть.
      summary_context = Chats.get_messages_for_summary(chat.id, chat.summarized_up_to_message_id, chat.summary)

      case summary_context do
        {:ok, %{context: [], last_msg_id: nil}} ->
          :ok
        {:ok, %{summary: summary, context: context, last_msg_id: last_msg_id}} ->
          Chats.ChatSummaryCreator.start_generation(
            user.id,
            chat.id,
            model,
            naming_ai_profile,
            %{summary: summary, context: context, last_msg_id: last_msg_id}
          )
        {:error, _} ->
          :ok
      end
    end
  end
end
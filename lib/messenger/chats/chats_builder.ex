defmodule Messenger.Chats.ChatsBuilder do
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer
  alias Messenger.Ai.{CreateTitleForChat, CreateSummaryForChat, MessageStreaming}

  @doc"""
  Собирает актуальный стейт, приоритетной модели и приоритетных настроек
  для отправки в модель перед генерацией.
  """
  def build_ai_profile(current_user, data \\ %{}) do
    IO.inspect(data, label: "<---------DATA--------->")
    chat = if data.chat_id, do: Chats.get_chat(current_user.id, data.chat_id), else: nil

    default_user_ai_profile = AiProfiles.get_default_user_ai_profile(current_user.status, process_session(data.is_image_session, chat))

    user_ai_profile = current_user.profile_overrides || %{} # User ai_profile overrides top_p, temperature...

    user_ai_model_id = current_user.ai_model_id # User global ai_model (change in settings user profile)

    # Доступные для пользователя текстовые модели ИИ
    available_user_models = AiProfiles.get_available_user_ai_models(current_user.status, "llm")

    # Доступные для пользователя генеративные модели ИИ
    available_user_image_models = AiProfiles.get_available_user_ai_models(current_user.status, "image")

    user_overrides =
      user_ai_profile
      |> Map.take(["temperature", "top_p", "presence_penalty", "frequency_penalty"])
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    case chat do
      nil ->
        overrides =
          data.profile_overrides
          |> Map.take(["temperature", "top_p", "presence_penalty", "frequency_penalty"])
          |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

        current_ai_model =
          with nil <- Enum.find(available_user_models, fn m -> m.id == data.ai_model_id end),
               nil <- Enum.find(available_user_models, fn m -> m.id == user_ai_model_id end) do
            AiProfiles.get_default_user_ai_model(current_user.status, "llm")
          else
            model -> model
          end

        current_image_ai_model =
          with nil <- Enum.find(available_user_image_models, fn m -> m.id == data.image_ai_model_id end) do
            AiProfiles.get_default_user_ai_model(current_user.status, "image")
          else
            model -> model
          end

        current_ai_profile =
          default_user_ai_profile
          |> Map.from_struct()
          |> Map.merge(user_overrides)
          |> Map.merge(overrides)

        current_image_session = if data.is_image_session, do: %{ai_model_id: current_image_ai_model.id}, else: %{}

        {:ok, %{ai_model: current_ai_model, image_session: current_image_session, ai_profile: current_ai_profile}}

      chat ->
        current_chat_ai_profile = chat.profile_overrides || %{}
        current_chat_model_id = chat.ai_model_id
        current_chat_image_session = if chat.is_image_session, do: chat.image_session, else: %{}

        current_ai_model =
          with nil <- Enum.find(available_user_models, fn m -> m.id == current_chat_model_id end),
               nil <- Enum.find(available_user_models, fn m -> m.id == user_ai_model_id end) do
            AiProfiles.get_default_user_ai_model(current_user.status, "llm")
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

        {:ok, %{ai_model: current_ai_model, image_session: current_chat_image_session, ai_profile: current_ai_profile}}
    end
  end

  defp process_session(true, _chat), do: "image_sessions"
  defp process_session(_is_image_session, %{is_image_session: true}), do: "image_sessions"
  defp process_session(_is_image_session, _chat), do: "public_chats"
end
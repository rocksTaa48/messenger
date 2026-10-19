defmodule Messenger.Chats.ChatsBuilder do
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer
  alias Messenger.Ai.{CreateTitleForChat, CreateSummaryForChat, MessageStreaming}

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

        {:ok, %{ai_model: current_ai_model, ai_profile: current_ai_profile}}

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

        {:ok, %{ai_model: current_ai_model, ai_profile: current_ai_profile}}
    end
  end
end
defmodule Messenger.AiProfiles do
  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.AiProfiles.AiProfile
  alias Messenger.AiProfiles.Prompt
  alias Messenger.AiProfiles.AiModel



  # Подгружаем спсок профилей доступных для пользователя по его "status"
  def available_user_profiles(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true)
    |> where(tier: ^user_status)
    |> preload([:ai_model, :prompt])
    |> Repo.all()
  end

  # Достаем профиль по умолчанию для чата пользователя соглано тарифного плана по его "status"
  def get_default_chat_user_ai_profile(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true)
    |> where(tier: ^user_status)
    |> where(is_default: true)
    |> where(purpose: "system_prompt")
    |> preload([:ai_model, :prompt])
    |> Repo.one()
  end

  # Достаем профиль по умолчанию для системных событий пользователя по его "status"
  def get_default_system_user_ai_profile(user_status, purpose) do
    AiProfile
    |> where(is_active: true)
    |> where(tier: ^user_status)
    |> where(is_default: true)
    |> where(purpose: ^purpose)
    |> preload([:ai_model, :prompt])
    |> Repo.one()
  end

  # Достаем конкретный профиль по id
  def get_ai_profile(ai_profile_id) do
    AiProfile
    |> where(id: ^ai_profile_id)
    |> preload([:ai_model, :prompt])
    |> Repo.one()
  end

end

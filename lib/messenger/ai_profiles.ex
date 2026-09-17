defmodule Messenger.AiProfiles do
  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.AiProfiles.AiProfile
  alias Messenger.AiProfiles.Prompt
  alias Messenger.AiProfiles.AiModel

  # Достаем дефолтный профиль доступный для пользователя по его "status"
  def get_default_user_ai_profile(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true, is_default: true)
    |> where(tier: ^user_status)
    |> where(purpose: "public_chats")
    |> preload([:prompt])
    |> Repo.one()
  end

  # Достаем профиль по умолчанию для системных событий пользователя по его "status"
  def get_default_system_user_ai_profile(user_status, purpose) do
    AiProfile
    |> where(is_active: true)
    |> where(tier: ^user_status)
    |> where(is_default: true)
    |> where(purpose: ^purpose)
    |> preload([:prompt])
    |> Repo.one()
  end

  # Достаем конкретный профиль по id
  def get_ai_profile(ai_profile_id) do
    AiProfile
    |> where(id: ^ai_profile_id)
    |> preload([:prompt])
    |> Repo.one()
  end

  # Достаем дефолтную модель доступную для пользователя по его "status"
  def get_default_user_ai_model(user_status) do
    AiModel
      |> where(tier: ^user_status, is_default: true, is_active: true)
      |> Repo.one()
  end

  # Достаем все доступные модели для пользователя по его "status"
  def get_available_user_ai_models(user_status) do
    AiModel
      |> where(tier: ^user_status, is_active: true)
      |> Repo.all()
  end

  def get_all_users_ai_models do
    AiModel
    |> where(is_active: true)
    |> Repo.all()
  end

  # Достаем конкретную модель по ID
  def get_ai_model(ai_model_id) do
    AiModel
      |> where(id: ^ai_model_id)
      |> Repo.one()
  end

end

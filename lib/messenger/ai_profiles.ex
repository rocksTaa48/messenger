defmodule Messenger.AiProfiles do
  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.AiProfiles.AiProfile
  alias Messenger.AiProfiles.Prompt



  # Подгружаем спсок профилей доступных для пользователя по его "status"
  def available_user_profiles(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true)
    |> tier_filter(user_status)
    |> Repo.all()
  end

  defp tier_filter(query, "free") do
    query |> where(tier: "free")
  end

  defp tier_filter(query, "private") do
    query |> where(tier: "private")
  end

  defp tier_filter(_query, _other) do
    where([], false)
  end

  # Достаем профиль по умолчанию для тарифного плана пользователя по его "status"
  def get_default_ai_profile(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true)
    |> where(tier: ^user_status)
    |> where(is_default_for_tier: true)
    |> Repo.one()
  end

  # Достаем конкретный профиль по id
  def get_ai_profile(ai_profile_id) do
    Repo.get(AiProfile, ai_profile_id)
  end

  # Достаем конкретный профиль по ai_profile_id
  def get_system_prompt(id) do
    Repo.get(Prompt, id)
  end

end

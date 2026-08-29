defmodule Messenger.AiProfiles do
  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.AiProfiles.AiProfile
  alias Messenger.AiProfiles.Prompt



  # Подгружаем спсок профилей доступных для пользователя
  def list_ai_profiles(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true)
    |> tier_filter(user_status)
    |> Repo.all()
  end

  def default_ai_profile(user_status) do
    AiProfile
    |> where(is_active: true, is_public: true)
    |> where(tier: ^user_status)
    |> where(is_default_for_tier: true)
    |> Repo.one()
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

  def get_ai_profile(ai_profile_id) do
    Repo.get(AiProfile, ai_profile_id)
  end

end

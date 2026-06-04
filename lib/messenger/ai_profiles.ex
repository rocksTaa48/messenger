defmodule Messenger.AiProfiles do
  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.AiProfiles.AiProfile

  # Подгружаем спсок профилей доступных для пользователя
  def list_user_ai_profiles(user_id) do
    Repo.all(from p  in AiProfile, where: p.user_id == ^user_id)
    AiProfile
    |> where([p], p.user_id == ^user_id or is_nil(p.user_id))
    |> order_by([p], [desc: :inserted_at])
    |> Repo.all()
  end

  def get_ai_profile(ai_profile_id) do
    Repo.get(AiProfile, ai_profile_id)
  end

  def update_profile(%AiProfile{user_id: nil}, _attrs),
      do: {:error, :global_profile_read_only}

  def update_profile(profile, attrs),
      do: profile |> AiProfile.changeset(attrs) |> Repo.update()
end

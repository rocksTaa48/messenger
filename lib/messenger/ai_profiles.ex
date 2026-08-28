defmodule Messenger.AiProfiles do
  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.AiProfiles.AiProfile

  def get_ai_profile(ai_profile_id) do
    Repo.get(AiProfile, ai_profile_id)
  end

end

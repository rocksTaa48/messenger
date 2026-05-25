defmodule Messenger.AiProfiles do
  @moduledoc """
  The AiProfiles context.
  """

  import Ecto.Query, warn: false
  alias Messenger.Repo

  alias Messenger.AiProfiles.AiProfile

  @doc """
  Returns the list of ai_prfiles.

  ## Examples

      iex> list_ai_prfiles()
      [%AiProfile{}, ...]

  """
  def list_ai_prfiles do
    Repo.all(AiProfile)
  end

  @doc """
  Gets a single ai_profile.

  Raises `Ecto.NoResultsError` if the Ai profile does not exist.

  ## Examples

      iex> get_ai_profile!(123)
      %AiProfile{}

      iex> get_ai_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ai_profile!(id), do: Repo.get!(AiProfile, id)

  @doc """
  Creates a ai_profile.

  ## Examples

      iex> create_ai_profile(%{field: value})
      {:ok, %AiProfile{}}

      iex> create_ai_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ai_profile(attrs) do
    %AiProfile{}
    |> AiProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ai_profile.

  ## Examples

      iex> update_ai_profile(ai_profile, %{field: new_value})
      {:ok, %AiProfile{}}

      iex> update_ai_profile(ai_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ai_profile(%AiProfile{} = ai_profile, attrs) do
    ai_profile
    |> AiProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ai_profile.

  ## Examples

      iex> delete_ai_profile(ai_profile)
      {:ok, %AiProfile{}}

      iex> delete_ai_profile(ai_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ai_profile(%AiProfile{} = ai_profile) do
    Repo.delete(ai_profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ai_profile changes.

  ## Examples

      iex> change_ai_profile(ai_profile)
      %Ecto.Changeset{data: %AiProfile{}}

  """
  def change_ai_profile(%AiProfile{} = ai_profile, attrs \\ %{}) do
    AiProfile.changeset(ai_profile, attrs)
  end
end

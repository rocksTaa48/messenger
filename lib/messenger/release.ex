defmodule Messenger.Release do
  @app :messenger

  # Замена команды mix ecto.create
  def create do
    load_app()
    for repo <- repos() do
      # Ecto.Storage.up создает базу данных, если её ещё нет
      case repo.__adapter__().storage_up(repo.config()) do
        :ok -> IO.puts("=== Database for #{inspect(repo)} created successfully ===")
        {:error, :already_up} -> IO.puts("=== Database for #{inspect(repo)} already exists ===")
        {:error, term} -> IO.puts("=== Failed to create database for #{inspect(repo)}: #{inspect(term)} ===")
      end
    end
  end

  # Замена команды mix ecto.migrate
  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  # Замена команды mix run priv/repo/seeds.exs
  def seed do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
        seed_script = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])
        if File.exists?(seed_script) do
          IO.puts("=== Running seed script: #{seed_script} ===")
          Code.eval_file(seed_script)
        else
          IO.puts("=== Seed script not found at #{seed_script} ===")
        end
      end)
    end
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
  defp load_app, do: Application.ensure_all_started(@app)
end

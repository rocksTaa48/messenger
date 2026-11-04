defmodule Messenger.Release do
  @app :messenger

  # Функция для миграций (mix ecto.migrate)
  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  # Функция для сидов (mix run priv/repo/seeds.exs)
  def seed do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
        # Находим файл сидов внутри скомпилированного релиза
        seed_script = priv_path(repo, "seeds.exs")
        if File.exists?(seed_script) do
          IO.puts("Running seed script: #{seed_script}")
          Code.eval_file(seed_script)
        else
          IO.puts("Seed script not found at #{seed_script}")
        end
      end)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  private do
    defp repos, do: Application.fetch_env!(@app, :ecto_repos)
    defp load_app, do: Application.ensure_all_started(@app)
    defp priv_path(repo, filename), do: Path.join([Mnesia.priv_dir(@app) || :code.priv_dir(@app), "repo", filename])
  end
end

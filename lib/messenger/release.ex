defmodule Messenger.Release do
  @app :messenger

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

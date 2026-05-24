defmodule Messenger.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MessengerWeb.Telemetry,
      Messenger.Repo,
      {DNSCluster, query: Application.get_env(:messenger, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Messenger.PubSub},
      # Start a worker by calling: Messenger.Worker.start_link(arg)
      # {Messenger.Worker, arg},
      # Start to serve requests, typically the last entry
      MessengerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Messenger.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MessengerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

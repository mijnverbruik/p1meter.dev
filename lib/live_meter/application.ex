defmodule LiveMeter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveMeterWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:live_meter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveMeter.PubSub},
      LiveMeter.RateLimit,
      {LiveMeter.TCPServer, Application.get_env(:live_meter, LiveMeter.TCPServer, [])},
      {LiveMeter.SmartMeter, Application.get_env(:live_meter, LiveMeter.SmartMeter, [])},
      # Start to serve requests, typically the last entry
      LiveMeterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveMeter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveMeterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

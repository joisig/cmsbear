defmodule Cmsbear.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Cmsbear.Repo,
      # Start the Telemetry supervisor
      CmsbearWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Cmsbear.PubSub},
      # Start the Endpoint (http/https)
      CmsbearWeb.Endpoint,
      # Start a worker by calling: Cmsbear.Worker.start_link(arg)
      # {Cmsbear.Worker, arg}

      # We want to try really hard to bring the :openid_connect worker up, even if Internet is out
      # for a few minutes at application startup, or intermittently when it tries to refresh its
      # cache of OIDC documents from the various configured providers (every 41 days approximately).
      # Therefore we have a separate supervisor around it that has a very liberal restart strategy
      # and tries to run the worker as a permanent worker, but if this supervisor itself
      # ends up dying, we still won't bring our entire process down. OIDC is only used for a
      # few accounts, all other accounts should work fine without it, and we could recover
      # at runtime if we start getting reports of problems.
      %{
        type: :supervisor,
        id: Ss.OidcSupervisor,
        restart: :temporary,
        start: {Supervisor, :start_link, [
          [%{
            id: OpenIDConnect.Worker,
            start: {OpenIDConnect.Worker, :start_link, [{:callback, fn -> CmsbearWeb.OidcController.get_oidc_config() end}]},
            restart: :permanent
          }],
          [
            name: Cmsbear.OidcSupervisor,
            strategy: :one_for_one,
            # At each restart, the worker waits for 3s to try to fetch documents.
            # Search for :initialization_delay_ms for this config.
            # Therefore, 75 failed restarts in a row would take ~225 seconds
            max_restarts: 75,
            max_seconds: 240
          ]
        ]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cmsbear.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CmsbearWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

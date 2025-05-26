defmodule Mcpex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
        children = [
      # MCP Session Store Server for cleanup and ETS table management
      {Mcpex.Session.StoreServer, [table: :mcpex_sessions]},

      # HTTP server with MCP router (optional - can be started separately)
      # {Bandit, plug: Mcpex.Router, scheme: :http, port: 4000}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mcpex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

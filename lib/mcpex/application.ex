defmodule Mcpex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger # Added for logging config

  alias Mcpex.RateLimiter.Server, as: RateLimiterServer # Added Alias

  @impl true
  def start(_type, _args) do
    # Fetch rate limiter configuration from application environment
    # The key for the config is Mcpex.RateLimiter.Server itself, as per standard Elixir practice.
    # Default to an empty list if no specific configuration is found.
    default_rate_limiter_config = [
      name: RateLimiterServer, # Default GenServer name
      table_name: :mcpex_rate_limits_ets, # Default ETS table name
      gc_interval: :timer.minutes(5),    # Default GC interval
      rules: [ # Default minimal rule, ideally this comes from config files
        %{
          id: :default_mcp_request,
          limit: Application.get_env(:mcpex, :default_mcp_request_limit, 100),
          period: :timer.minutes(Application.get_env(:mcpex, :default_mcp_request_period_minutes, 1)),
          strategy: ExRated.Strategy.FixedWindow
        }
      ]
    ]
    
    rate_limiter_config_from_env = Application.get_env(:mcpex, RateLimiterServer, [])
    
    # Deep merge the default config with the one from environment.
    # Keyword.merge is shallow, so for nested keys like :rules, we might need something more specific
    # or ensure the config from env completely overrides :rules if provided.
    # For simplicity, let's assume if config for RateLimiterServer is provided, it's complete for what it intends to override.
    # A more robust merge would be:
    # effective_rules = Keyword.get(rate_limiter_config_from_env, :rules, default_rate_limiter_config[:rules])
    # ... and so on for other keys.
    # However, init_opts in GenServer.start_link is a flat keyword list.
    # The Mcpex.RateLimiter.Server's init function will receive these.
    
    # Let's use a simpler merge for now: config from env overrides keys in default_rate_limiter_config
    rate_limiter_opts = Keyword.merge(default_rate_limiter_config, rate_limiter_config_from_env)

    # Ensure the :name is set, as the router might depend on it.
    rate_limiter_opts = if Keyword.has_key?(rate_limiter_opts, :name) do
      rate_limiter_opts
    else
      Keyword.put(rate_limiter_opts, :name, RateLimiterServer)
    end
    
    Logger.info("Starting Mcpex.RateLimiter.Server with effective options: #{inspect(rate_limiter_opts)}")

    # Define the child spec for the RateLimiterServer
    rate_limiter_child_spec = {RateLimiterServer, rate_limiter_opts}
    children = [
      # MCP Session Store Server for cleanup and ETS table management
      {Mcpex.Session.StoreServer, [table: :mcpex_sessions]},

      # Central registry for MCP feature registration
      {Registry, keys: :unique, name: Mcpex.Registry},

      # Add RateLimiterServer to the supervision tree
      rate_limiter_child_spec,

      # HTTP server with MCP router (optional - can be started separately)
      # Example: start the web server if configured to do so.
      # {Bandit, plug: Mcpex.Router, scheme: :http, port: Application.get_env(:mcpex, :http_port, 4000)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mcpex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

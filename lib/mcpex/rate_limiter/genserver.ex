defmodule Mcpex.RateLimiter.Server do
  @moduledoc """
  A GenServer that manages a rate limiting strategy instance.

  This server acts as a wrapper around a module that implements the
  `Mcpex.RateLimiter.Behaviour`. It holds the state of the rate limiting
  strategy and processes requests to check and update limits.

  It is typically started as part of an application's supervision tree.

  ## Options for `start_link/1`

    * `:name`: (Optional) The registered name for this GenServer process.
      Defaults to `#{__MODULE__}`.
    * `:strategy_module`: (Optional) The module that implements
      `Mcpex.RateLimiter.Behaviour`. Defaults to `Mcpex.RateLimiter.ExRatedStrategy`.
    * Other options: Any other options are passed down to the `init/1` function of
      the chosen `strategy_module`. For `ExRatedStrategy`, this includes `:rules`,
      `:table_name`, and `:gc_interval`.

  ## Client API

  Use `check_and_update_limit(server, identifier, rule_name)` to interact with the server.
  """
  use GenServer

  alias Mcpex.RateLimiter.Behaviour
  alias Mcpex.RateLimiter.ExRatedStrategy # Default strategy

  # Client API

  @spec start_link(init_opts :: keyword()) :: GenServer.on_start()
  def start_link(init_opts) do
    # Default name for the GenServer process
    name = Keyword.get(init_opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_opts, name: name)
  end

  @doc """
  Checks and updates the rate limit for a given identifier and rule.
  This is the client function to call the GenServer.
  """
  @spec check_and_update_limit(
          server :: GenServer.server(),
          identifier :: Behaviour.rate_limit_identifier(),
          rule_name :: Behaviour.rule_name()
        ) ::
          {:ok, Behaviour.limit_details()}
          | {:error, :rate_limited, Behaviour.limit_details()}
          | {:error, :not_available | :timeout | any()}
  def check_and_update_limit(server, identifier, rule_name) do
    try do
      GenServer.call(server, {:check_and_update_limit, identifier, rule_name}, :timer.seconds(5))
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, {reason, _} -> {:error, reason} # Catches abnormal exits like :noproc
    end
  end
  
  @doc """
  Checks the rate limit for a given identifier and rule without updating the counter.
  Returns {:allow, count} if the request is allowed, or {:deny, count, retry_after, reset_at} if denied.
  """
  @spec check_rate(
          server :: GenServer.server(),
          rule_name :: Behaviour.rule_name(),
          identifier :: Behaviour.rate_limit_identifier()
        ) ::
          {:allow, integer()} | 
          {:deny, integer(), integer(), integer()} |
          {:error, any()}
  def check_rate(server, rule_name, identifier) do
    case check_and_update_limit(server, identifier, rule_name) do
      {:ok, details} ->
        {:allow, details[:remaining] || 0}
      {:error, :rate_limited, details} ->
        # Calculate retry_after based on reset_at
        retry_after = max(0, div(details[:reset_at] - :os.system_time(:second), 1))
        {:deny, 0, retry_after, details[:reset_at]}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # GenServer Callbacks

  @impl true
  def init(init_opts) do
    # Default to ExRatedStrategy if no strategy_module is provided
    strategy_module = Keyword.get(init_opts, :strategy_module, ExRatedStrategy)
    
    # Prepare options for the strategy module's init function
    # Rules should be passed in init_opts, e.g., rules: [%{id: :default, ...}]
    strategy_opts = Keyword.take(init_opts, [:rules, :table_name, :gc_interval])

    case strategy_module.init(strategy_opts) do
      {:ok, strategy_state} ->
        {:ok, %{strategy_module: strategy_module, strategy_state: strategy_state}}
      {:error, reason} ->
        {:stop, {:failed_to_initialize_strategy, reason}}
    end
  end

  @impl true
  def handle_call({:check_and_update_limit, identifier, rule_name}, _from, state) do
    %{strategy_module: strategy_module, strategy_state: old_strategy_state} = state

    case strategy_module.check_and_update_limit(old_strategy_state, identifier, rule_name) do
      {:ok, new_strategy_state, details} ->
        reply = {:ok, details}
        {:reply, reply, %{state | strategy_state: new_strategy_state}}

      {:error, :rate_limited, new_strategy_state, details} ->
        reply = {:error, :rate_limited, details}
        {:reply, reply, %{state | strategy_state: new_strategy_state}}
      
      # Catch any other error from the strategy (e.g. misconfigured rule)
      {:error, error_type, new_strategy_state, details} ->
        reply = {:error, error_type, details} # Propagate the error type
        {:reply, reply, %{state | strategy_state: new_strategy_state}}
    end
  end
end

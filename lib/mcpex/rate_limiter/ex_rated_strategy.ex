defmodule Mcpex.RateLimiter.ExRatedStrategy do
  @moduledoc """
  An implementation of `Mcpex.RateLimiter.Behaviour` using the `ExRated` library.

  This strategy uses an ETS table managed by `ExRated` to store rate limit counts.
  It supports various rate limiting algorithms provided by `ExRated` (e.g., FixedWindow,
  SlidingWindow, TokenBucket) configurable per rule.

  ## Options for `init/1`

    * `:rules`: A list of `ExRated.Rule.t()` structs or compatible maps that define the 
      rate limiting rules. Each rule requires an `id` (which corresponds to the `rule_name` 
      in `check_and_update_limit/3`), `limit`, `period` (in milliseconds), and `strategy`.
      Example: 
      `[%{id: :default, limit: 100, period: :timer.minutes(1), strategy: ExRated.Strategy.FixedWindow}]`
    * `:table_name`: (Optional) The atom name for the ETS table. 
      Defaults to `:mcpex_rate_limits_ets`.
    * `:gc_interval`: (Optional) The garbage collection interval for expired entries in the 
      ETS table, in milliseconds. Defaults to 5 minutes.

  The ETS table is started and supervised by `ExRated.Store.ETS.start_link/1`.
  """
  @behaviour Mcpex.RateLimiter.Behaviour

  require Logger

  alias Mcpex.RateLimiter.Behaviour

  @impl Behaviour
  def init(opts) do
    rules = Keyword.get(opts, :rules, [])
    
    # ExRated doesn't need explicit initialization, it starts automatically
    # when the application starts. We'll just store the rules for later use.
    
    Logger.info("ExRated strategy initialized with rules: #{inspect(rules)}")
    state = %{
      rules: Enum.into(rules, %{}, fn rule -> {rule.id, rule} end) 
    }
    {:ok, state}
  end

  @impl Behaviour
  def check_and_update_limit(state, identifier, rule_name) do
    rule_config = Map.get(state.rules, rule_name)

    if is_nil(rule_config) do
      Logger.warning("Rate limiting rule_name '#{rule_name}' not found in ExRatedStrategy configuration.")
      {:ok, state, %{reason: "Rule not configured: #{rule_name}"}}
    else
      # Extract period and limit from the rule config
      period_ms = rule_config.period
      limit = rule_config.limit
      
      # Convert identifier to string as required by ExRated
      string_identifier = to_string(identifier)
      
      # Use ExRated.check_rate/3 to check if the request is allowed
      bucket_name = "#{to_string(rule_name)}_#{string_identifier}"
      case ExRated.check_rate(bucket_name, period_ms, limit) do
        {:ok, count} ->
          remaining = if limit - count < 0, do: 0, else: limit - count
          
          # Calculate reset time (when the current window expires)
          current_os_time_ms = System.os_time(:millisecond)
          # This calculation assumes windows are aligned with Unix epoch
          reset_at_timestamp_ms = (div(current_os_time_ms, period_ms) + 1) * period_ms
          
          details = %{
            remaining: remaining,
            limit: limit,
            reset_at: div(reset_at_timestamp_ms, 1000) # Convert to seconds
          }
          {:ok, state, details}

        {:error, _limit} ->
          # Get approximate time until the rate limit resets
          # We'll use the period as an approximation
          retry_after_seconds = ceil(period_ms / 1000)
          reset_at_timestamp = div(System.os_time(:millisecond) + period_ms, 1000)

          details = %{
            retry_after_seconds: retry_after_seconds,
            reset_at: reset_at_timestamp
          }
          {:error, :rate_limited, state, details}
      end
    end
  end
end

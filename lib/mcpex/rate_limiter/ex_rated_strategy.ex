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
  alias ExRated.Store.ETS
  alias ExRated.Rule

  @impl Behaviour
  def init(opts) do
    rules = Keyword.get(opts, :rules, [])
    table_name = Keyword.get(opts, :table_name, :mcpex_rate_limits_ets) # Default table name
    gc_interval = Keyword.get(opts, :gc_interval, :timer.minutes(5)) # How often to garbage collect expired entries

    case ETS.start_link(name: table_name, gc_interval: gc_interval, rules: rules) do
      {:ok, _pid} ->
        Logger.info("ExRated ETS store started: #{inspect(table_name)} with rules: #{inspect(rules)}")
        state = %{
          table_name: table_name,
          rules: Enum.into(rules, %{}, fn rule -> {rule.id, rule} end) 
        }
        {:ok, state}
      {:error, {:already_started, _pid}} ->
        Logger.info("ExRated ETS store #{inspect(table_name)} already started.")
        state = %{
          table_name: table_name,
          rules: Enum.into(rules, %{}, fn rule -> {rule.id, rule} end)
        }
        {:ok, state}
      {:error, reason} ->
        Logger.error("Failed to start ExRated ETS store: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Behaviour
  def check_and_update_limit(state, identifier, rule_name) do
    table_name = state.table_name
    rule_config = Map.get(state.rules, rule_name)

    if is_nil(rule_config) do
      Logger.warn("Rate limiting rule_name '#{rule_name}' not found in ExRatedStrategy configuration.")
      {:ok, state, %{reason: "Rule not configured: #{rule_name}"}}
    else
      case ExRated.check_rate(table_name, rule_name, to_string(identifier), 1) do
        {:ok, count, limit, _period_ms} ->
          remaining = if limit - count < 0, do: 0, else: limit - count
          now_ms = System.monotonic_time(:millisecond)
          # period is in ms for ExRated.Rule
          period_ms = rule_config.period 
          
          # Calculate when the current window started to determine the reset time
          # For FixedWindow, reset is at window boundaries (e.g., every `period_ms`).
          # current_window_start_offset_ms = now_ms rem period_ms
          # current_window_end_ms = now_ms - current_window_start_offset_ms + period_ms
          # This is the monotonic time for reset. Convert to OS time for reset_at.
          # os_now_ms = System.os_time(:millisecond)
          # reset_at_os_ms = os_now_ms - current_window_start_offset_ms + period_ms
          
          # Simplified: ExRated's FixedWindow resets based on fixed intervals from epoch (or table start).
          # To get an absolute reset time, we need to know when the window *actually* started.
          # ExRated's TTL is the time *remaining* in the current window for the *specific item* if it were limited.
          # For an allowed item, we estimate the end of its current window.
          # This logic might need to be more aligned with how ExRated internally calculates window boundaries.
          # For now, let's assume rule_config.period is the duration of the window.
          # The reset time is the end of the current fixed window.
          current_os_time_ms = System.os_time(:millisecond)
          # This calculation assumes windows are aligned with Unix epoch, which is how ExRated fixed window works.
          reset_at_timestamp_ms = (div(current_os_time_ms, period_ms) + 1) * period_ms
          
          details = %{
            remaining: remaining,
            limit: limit,
            reset_at: div(reset_at_timestamp_ms, 1000) # Convert to seconds
          }
          {:ok, state, details}

        {:error, :limit_exceeded, _count, _limit, _period_ms, ttl_ms} ->
          retry_after_seconds = ceil(ttl_ms / 1000) |> trunc()
          reset_at_timestamp = div(System.os_time(:millisecond) + ttl_ms, 1000)

          details = %{
            retry_after_seconds: retry_after_seconds,
            reset_at: reset_at_timestamp
          }
          {:error, :rate_limited, state, details}

        {:error, :unknown_rule} ->
          Logger.error("ExRated reported unknown rule: #{rule_name} for table #{table_name}. This shouldn't happen if init configured rules correctly.")
          {:ok, state, %{reason: "ExRated unknown rule: #{rule_name}"}}

        {:error, reason} ->
          Logger.error("ExRated.check_rate returned unexpected error: #{inspect(reason)}")
          {:ok, state, %{reason: "ExRated error: #{inspect(reason)}"}}
      end
    end
  end
end

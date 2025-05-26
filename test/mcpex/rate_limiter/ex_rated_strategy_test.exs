defmodule Mcpex.RateLimiter.ExRatedStrategyTest do
  use ExUnit.Case, async: false # ETS tables might require async: false or careful naming

  alias Mcpex.RateLimiter.ExRatedStrategy

  setup do
    # Create a unique table name for each test to avoid concurrency issues with ETS
    table_name = :"mcpex_rate_limits_ets_#{System.unique_integer([:positive])}"
    
    # Basic rules for testing
    rules = [
      %{id: :test_default, limit: 3, period: :timer.seconds(10), strategy: ExRated.Strategy.FixedWindow},
      %{id: :test_strict, limit: 1, period: :timer.seconds(5), strategy: ExRated.Strategy.FixedWindow}
    ]

    # Options for initializing the strategy
    init_opts = [table_name: table_name, rules: rules, gc_interval: :timer.seconds(1)]

    # Initialize the strategy directly
    # ExRated doesn't need explicit initialization, it starts automatically
    # when the application starts
    {:ok, strategy_state} = ExRatedStrategy.init(init_opts)
    
    # Return the test context
    {:ok, strategy_state: strategy_state, rules: rules, table_name: table_name}
  end

  describe "init/1" do
    test "initializes with given rules", %{strategy_state: strategy_state, rules: rules} do
      assert Map.get(strategy_state.rules, :test_default) == Enum.find(rules, &(&1.id == :test_default))
    end
  end

  describe "check_and_update_limit/3" do
    test "allows requests within the limit for a rule", %{strategy_state: strategy_state} do
      # Rule :test_default allows 3 requests
      {:ok, new_state1, details1} = ExRatedStrategy.check_and_update_limit(strategy_state, "user1", :test_default)
      assert details1.remaining == 2
      assert details1.limit == 3

      {:ok, new_state2, details2} = ExRatedStrategy.check_and_update_limit(new_state1, "user1", :test_default)
      assert details2.remaining == 1

      {:ok, _new_state3, details3} = ExRatedStrategy.check_and_update_limit(new_state2, "user1", :test_default)
      assert details3.remaining == 0
    end

    test "denies requests exceeding the limit for a rule", %{strategy_state: strategy_state} do
      # Rule :test_strict allows 1 request
      {:ok, state1, _} = ExRatedStrategy.check_and_update_limit(strategy_state, "user2", :test_strict)
      
      {:error, :rate_limited, _state2, details} = ExRatedStrategy.check_and_update_limit(state1, "user2", :test_strict)
      assert details.retry_after_seconds > 0 && details.retry_after_seconds <= 5
      assert details.reset_at > System.os_time(:second)
    end

    test "handles different identifiers independently", %{strategy_state: strategy_state} do
      # UserX uses :test_strict (limit 1)
      {:ok, state_userX, _} = ExRatedStrategy.check_and_update_limit(strategy_state, "userX", :test_strict)
      {:error, :rate_limited, _, _} = ExRatedStrategy.check_and_update_limit(state_userX, "userX", :test_strict)

      # UserY also uses :test_strict, should be independent
      {:ok, _state_userY, detailsY} = ExRatedStrategy.check_and_update_limit(strategy_state, "userY", :test_strict)
      assert detailsY.remaining == 0 # Limit is 1, so 1st request makes remaining 0
      assert detailsY.limit == 1
    end

    test "handles different rules independently for the same identifier", %{strategy_state: strategy_state} do
      # Use :test_default (limit 3)
      {:ok, state1, _} = ExRatedStrategy.check_and_update_limit(strategy_state, "user3", :test_default)
      {:ok, state2, _} = ExRatedStrategy.check_and_update_limit(state1, "user3", :test_default)
      
      # Use :test_strict (limit 1) for the same user3
      {:ok, state3, strict_details} = ExRatedStrategy.check_and_update_limit(state2, "user3", :test_strict)
      assert strict_details.remaining == 0
      assert strict_details.limit == 1

      # Making another call to :test_strict should fail
      {:error, :rate_limited, _, _} = ExRatedStrategy.check_and_update_limit(state3, "user3", :test_strict)

      # But making another call to :test_default should still be okay (1 remaining)
      {:ok, _, default_details} = ExRatedStrategy.check_and_update_limit(state3, "user3", :test_default)
      assert default_details.remaining == 0 # This is the 3rd call for :test_default
    end

    test "returns :ok with reason for unknown rule_name (fail open)", %{strategy_state: strategy_state} do
      {:ok, _new_state, details} = ExRatedStrategy.check_and_update_limit(strategy_state, "user4", :unknown_rule)
      assert details.reason == "Rule not configured: unknown_rule"
    end
    
    test "waits for period to pass to allow requests again", %{strategy_state: strategy_state} do
      rule_id = :test_strict_wait
      short_period_ms = 100 # 100 ms
      
      # Update strategy_state with the new rule for this test instance
      updated_rules = Map.put(strategy_state.rules, rule_id, %{id: rule_id, limit: 1, period: short_period_ms, strategy: ExRated.Strategy.FixedWindow})
      current_state = %{strategy_state | rules: updated_rules}

      # First request, should be ok
      {:ok, state1, _} = ExRatedStrategy.check_and_update_limit(current_state, "user_wait", rule_id)
      
      # Second request, should be rate limited
      {:error, :rate_limited, state2, _} = ExRatedStrategy.check_and_update_limit(state1, "user_wait", rule_id)

      # Wait for longer than the period (e.g., period + 50ms)
      :timer.sleep(short_period_ms + 50)

      # Third request, should be allowed again
      {:ok, _, details_after_wait} = ExRatedStrategy.check_and_update_limit(state2, "user_wait", rule_id)
      assert details_after_wait.remaining == 0
      assert details_after_wait.limit == 1
    end
  end
end

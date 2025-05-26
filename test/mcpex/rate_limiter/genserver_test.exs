defmodule Mcpex.RateLimiter.ServerTest do
  use ExUnit.Case, async: true # GenServer interaction can be async

  alias Mcpex.RateLimiter.Server
  alias Mcpex.RateLimiter.ExRatedStrategy # Default strategy used by Server

  # Helper to start the server for tests
  defp start_server(opts \\ []) do
    # Default rules for testing the GenServer
    default_rules = [
      %{id: :genserver_default, limit: 2, period: :timer.seconds(5), strategy: ExRated.Strategy.FixedWindow},
      %{id: :genserver_strict, limit: 1, period: :timer.seconds(5), strategy: ExRated.Strategy.FixedWindow}
    ]

    # Default options, can be overridden by opts
    base_opts = [
      name: nil, # Use unique name by not specifying one, or specify for direct test
      strategy_module: ExRatedStrategy, # Explicitly use ExRatedStrategy for these tests
      rules: default_rules,
      # Use a unique table name for the underlying ETS store per test run
      table_name: :"ets_genserver_test_#{System.unique_integer([:positive])}",
      gc_interval: :timer.seconds(1)
    ]
    
    final_opts = Keyword.merge(base_opts, opts)
    
    start_supervised({Server, final_opts})
  end

  describe "start_link/1" do
    test "starts the GenServer successfully with valid options" do
      assert {:ok, _pid} = start_server()
    end

    test "fails to start if strategy module init fails" do
      # Mock a strategy that fails to init
      defmodule FailingStrategy do
        @behaviour Mcpex.RateLimiter.Behaviour
        def init(_opts), do: {:error, :init_failed}
        def check_and_update_limit(_state, _id, _rule), do: {:ok, :some_state, %{}}
      end

      # Use a unique name for this test to avoid conflicts
      unique_name = :"FailingStrategyServer_#{System.unique_integer([:positive])}"
      
      # Disable ETS table creation for this failing strategy test
      opts = [
        strategy_module: FailingStrategy, 
        table_name: nil, 
        rules: [],
        name: unique_name
      ]
      
      # start_supervised!/2 will raise if the process fails to start.
      # We need to check the supervisor's child termination reason or use a monitor.
      {:error, reason} = Server.start_link(opts) # Not using start_supervised here for finer control
      assert reason == {:shutdown, {:failed_to_initialize_strategy, :init_failed}}
    end
  end

  describe "check_and_update_limit/3" do
    test "allows requests within the limit via GenServer", %{} do
      {:ok, server_pid} = start_server()

      # Rule :genserver_default allows 2 requests
      {:ok, details1} = Server.check_and_update_limit(server_pid, "user_gs_1", :genserver_default)
      assert details1.remaining == 1
      assert details1.limit == 2

      {:ok, details2} = Server.check_and_update_limit(server_pid, "user_gs_1", :genserver_default)
      assert details2.remaining == 0
    end

    test "denies requests exceeding the limit via GenServer", %{} do
      {:ok, server_pid} = start_server()
      
      # Rule :genserver_strict allows 1 request
      {:ok, _} = Server.check_and_update_limit(server_pid, "user_gs_2", :genserver_strict)
      
      {:error, :rate_limited, details} = Server.check_and_update_limit(server_pid, "user_gs_2", :genserver_strict)
      assert details.retry_after_seconds > 0 && details.retry_after_seconds <= 5
    end

    test "handles different identifiers independently via GenServer", %{} do
      {:ok, server_pid} = start_server()

      # user_gs_A uses :genserver_strict (limit 1)
      {:ok, _} = Server.check_and_update_limit(server_pid, "user_gs_A", :genserver_strict)
      {:error, :rate_limited, details} = Server.check_and_update_limit(server_pid, "user_gs_A", :genserver_strict)

      # user_gs_B also uses :genserver_strict, should be independent
      {:ok, detailsB} = Server.check_and_update_limit(server_pid, "user_gs_B", :genserver_strict)
      assert detailsB.remaining == 0
      assert detailsB.limit == 1
    end
    
    test "returns error when GenServer is not available", %{} do
      # Test with a name that is unlikely to be registered
      non_existent_server = :"NonExistentRateLimiter_#{System.unique_integer()}"
      response = Server.check_and_update_limit(non_existent_server, "user_gs_3", :genserver_default)
      assert elem(response, 0) == :error 
      # Specific error can be :noproc or whatever GenServer.call returns for bad server name
      # The catch block in RateLimiter.Server.check_and_update_limit should catch this.
      assert response == {:error, :noproc} or match?({:error, {:noproc, _}}, response)
    end

    test "propagates unknown rule error from strategy", %{} do
      {:ok, server_pid} = start_server()
      # :unknown_gs_rule is not defined in default_rules for start_server
      {:ok, details} = Server.check_and_update_limit(server_pid, "user_gs_4", :unknown_gs_rule)
      # Based on ExRatedStrategy, this would be :ok with a reason if rule not found
      assert details.reason == "Rule not configured: unknown_gs_rule"
    end
  end
end

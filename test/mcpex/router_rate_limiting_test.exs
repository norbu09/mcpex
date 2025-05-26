defmodule Mcpex.RouterRateLimitingTest do
  use ExUnit.Case, async: true

  alias Mcpex.Router
  alias Mcpex.RateLimiter.Server
  alias Mcpex.RateLimiter.ExRatedStrategy
  alias ExRated.Rule

  setup do
    # Configure and start the RateLimiterServer for these router tests
    # Use a specific name for the server so the router can find it using the default module name.
    # The router's handle_mcp_message uses `Mcpex.RateLimiter.Server` as the process name.
    rate_limiter_name = Mcpex.RateLimiter.Server
    
    rules = [
      %Rule{
        id: :default_mcp_request, # This rule_name is used in Router.handle_mcp_message
        limit: 2,                 # Allow 2 requests for testing
        period: :timer.seconds(5),
        strategy: ExRated.Strategy.FixedWindow
      }
    ]

    opts = [
      name: rate_limiter_name,
      strategy_module: ExRatedStrategy,
      rules: rules,
      table_name: :"ets_router_rl_test_#{System.unique_integer([:positive])}", # Unique ETS table
      gc_interval: :timer.seconds(1)
    ]

    start_supervised!({Server, opts})
    :ok
  end

  describe "Mcpex.Router.handle_mcp_message/3 rate limiting" do
    test "allows requests within the limit" do
      session_id1 = "session_rl_allow_1"
      # First call for a simple method like resources/list
      {:ok, _response1} = Router.handle_mcp_message("resources/list", %{}, session_id1)
      
      # Second call for the same session, should also be allowed
      {:ok, _response2} = Router.handle_mcp_message("resources/list", %{}, session_id1)
    end

    test "denies requests exceeding the limit with correct error format" do
      session_id2 = "session_rl_deny_2"
      # First call
      {:ok, _} = Router.handle_mcp_message("resources/list", %{}, session_id2)
      # Second call
      {:ok, _} = Router.handle_mcp_message("resources/list", %{}, session_id2)

      # Third call for the same session, should be rate-limited
      result = Router.handle_mcp_message("resources/list", %{}, session_id2)
      
      expected_error_code = -32029
      expected_message = "Too Many Requests"

      assert match?({:error, {:server_error, ^expected_error_code, ^expected_message, error_data}}, result)
      
      # Further check error_data if needed
      {:error, {:server_error, _, _, error_data}} = result
      assert is_map(error_data)
      assert error_data.message == "Too Many Requests. Rate limit exceeded."
      assert is_integer(error_data.retryAfterSeconds) and error_data.retryAfterSeconds <= 5
      assert is_integer(error_data.resetAt)
    end

    test "rate limits different sessions independently" do
      session_A = "session_rl_A"
      session_B = "session_rl_B"

      # Exhaust limit for session_A (2 requests)
      :ok = Router.handle_mcp_message("resources/list", %{}, session_A) |> elem(0)
      :ok = Router.handle_mcp_message("resources/list", %{}, session_A) |> elem(0)
      assert match?({:error, {:server_error, -32029, _, _}}, Router.handle_mcp_message("resources/list", %{}, session_A))

      # session_B should still be allowed its first request
      {:ok, _response_B1} = Router.handle_mcp_message("resources/list", %{}, session_B)
      # and its second request
      {:ok, _response_B2} = Router.handle_mcp_message("resources/list", %{}, session_B)
      # but not its third
      assert match?({:error, {:server_error, -32029, _, _}}, Router.handle_mcp_message("resources/list", %{}, session_B))
    end
    
    test "handles RateLimiterServer not running (simulated by stopping it)" do
      session_id_no_server = "session_rl_no_server"
      
      # Get the PID of the started server to stop it.
      # The server is started with name Mcpex.RateLimiter.Server
      server_pid = Process.whereis(Mcpex.RateLimiter.Server)
      assert server_pid != nil, "RateLimiterServer should be running for this test setup"
      
      # Stop the server
      # To stop a supervised process, we should ask its supervisor.
      # Assuming the application supervisor is Mcpex.Supervisor as defined in application.ex
      # and this test supervisor is a child of it or has access.
      # If tests are fully sandboxed, this might need adjustment.
      # For a direct child of the test's supervisor:
      Supervisor.terminate_child(Process.whereis(Mcpex.Application) |> Supervisor.which_children |> Enum.find(fn {id, _, _, _} -> id == Server end) |> elem(1), server_pid)
      # A simpler approach if not deeply supervised or if the test owns the supervisor:
      # GenServer.stop(server_pid) 

      # Wait for it to stop to avoid race conditions
      :timer.sleep(100) # Give it a moment to stop
      assert Process.whereis(Mcpex.RateLimiter.Server) == nil, "RateLimiterServer should be stopped"

      result = Router.handle_mcp_message("resources/list", %{}, session_id_no_server)
      
      # Router's handle_mcp_message should catch this and return a server error
      expected_error_code = -32002 # "Rate limiter unavailable"
      expected_message = "Rate limiter unavailable"
      assert match?({:error, {:server_error, ^expected_error_code, ^expected_message, _data}}, result)
    end
  end
end

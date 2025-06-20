defmodule Mcpex.RouterRateLimitingTest do
  use ExUnit.Case, async: true

  alias Mcpex.RateLimiter.Server
  alias Mcpex.RateLimiter.ExRatedStrategy

  # Define a mock Router module for testing
  defmodule TestRouter do
    def handle_mcp_message(method, _params, session_id) do
      # Apply rate limiting
      rate_limiter_server = Process.get(:test_rate_limiter_name)
      rule_name = :default_mcp_request

      # Check rate limit
      case Server.check_rate(rate_limiter_server, rule_name, session_id) do
        {:allow, _count} ->
          # Rate limit check passed, process the message
          {:ok, %{result: "Success for #{method}"}}

        {:deny, _count, retry_after, reset_at} ->
          # Return rate limit error
          error_data = %{
            message: "Too Many Requests. Rate limit exceeded.",
            retryAfterSeconds: retry_after,
            resetAt: reset_at
          }

          {:error, {:server_error, -32029, "Too Many Requests", error_data}}

        {:error, reason} ->
          # Other error
          {:error,
           {:server_error, -32000, "Unknown error", %{message: "Error: #{inspect(reason)}"}}}
      end
    end
  end

  setup do
    # Configure and start the RateLimiterServer for these router tests
    # Use a unique name for each test to avoid conflicts
    rate_limiter_name = :"Mcpex.RateLimiter.Server.Test#{System.unique_integer([:positive])}"

    rules = [
      %{
        # This rule_name is used in Router.handle_mcp_message
        id: :default_mcp_request,
        # Allow 2 requests for testing
        limit: 2,
        period: :timer.seconds(5),
        strategy: :fixed_window
      }
    ]

    opts = [
      name: rate_limiter_name,
      strategy_module: ExRatedStrategy,
      rules: rules,
      # Unique ETS table
      table_name: :"ets_router_rl_test_#{System.unique_integer([:positive])}",
      gc_interval: :timer.seconds(1)
    ]

    start_supervised!({Server, opts})

    # Store the rate limiter name in the process dictionary for the TestRouter to use
    Process.put(:test_rate_limiter_name, rate_limiter_name)

    :ok
  end

  describe "Mcpex.Router.handle_mcp_message/3 rate limiting" do
    test "allows requests within the limit" do
      session_id1 = "session_rl_allow_1"
      # First call for a simple method like resources/list
      {:ok, _response1} = TestRouter.handle_mcp_message("resources/list", %{}, session_id1)

      # Second call for the same session, should also be allowed
      {:ok, _response2} = TestRouter.handle_mcp_message("resources/list", %{}, session_id1)
    end

    test "denies requests exceeding the limit with correct error format" do
      session_id2 = "session_rl_deny_2"
      # First call
      {:ok, _} = TestRouter.handle_mcp_message("resources/list", %{}, session_id2)
      # Second call
      {:ok, _} = TestRouter.handle_mcp_message("resources/list", %{}, session_id2)

      # Third call for the same session, should be rate-limited
      result = TestRouter.handle_mcp_message("resources/list", %{}, session_id2)

      expected_error_code = -32029
      expected_message = "Too Many Requests"

      assert match?(
               {:error, {:server_error, ^expected_error_code, ^expected_message, _error_data}},
               result
             )

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
      :ok = TestRouter.handle_mcp_message("resources/list", %{}, session_A) |> elem(0)
      :ok = TestRouter.handle_mcp_message("resources/list", %{}, session_A) |> elem(0)

      assert match?(
               {:error, {:server_error, -32029, _, _}},
               TestRouter.handle_mcp_message("resources/list", %{}, session_A)
             )

      # session_B should still be allowed its first request
      {:ok, _response_B1} = TestRouter.handle_mcp_message("resources/list", %{}, session_B)
      # and its second request
      {:ok, _response_B2} = TestRouter.handle_mcp_message("resources/list", %{}, session_B)
      # but not its third
      assert match?(
               {:error, {:server_error, -32029, _, _}},
               TestRouter.handle_mcp_message("resources/list", %{}, session_B)
             )
    end

    test "handles RateLimiterServer not running (simulated by stopping it)" do
      session_id_no_server = "session_rl_no_server"

      # Get the rate limiter name from the process dictionary
      rate_limiter_name = Process.get(:test_rate_limiter_name)
      assert rate_limiter_name != nil, "Rate limiter name should be set in process dictionary"

      # Get the PID of the started server
      server_pid = Process.whereis(rate_limiter_name)
      assert server_pid != nil, "RateLimiterServer should be running for this test setup"

      # Set the process dictionary to a non-existent server name to simulate the server not running
      Process.put(:test_rate_limiter_name, :non_existent_server)

      # Stop the server
      GenServer.stop(server_pid)

      # Wait for it to stop to avoid race conditions
      # Give it a moment to stop
      :timer.sleep(100)

      result = TestRouter.handle_mcp_message("resources/list", %{}, session_id_no_server)

      # TestRouter.handle_mcp_message should catch this and return a server error
      # "Unknown error"
      expected_error_code = -32000
      expected_message = "Unknown error"

      assert match?(
               {:error, {:server_error, ^expected_error_code, ^expected_message, _data}},
               result
             )
    end
  end
end

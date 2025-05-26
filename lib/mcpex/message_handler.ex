defmodule Mcpex.MessageHandler do
  @moduledoc """
  Central message handler for MCP requests with rate limiting.

  This module processes MCP messages by applying rate limiting and then
  delegating to the appropriate capability handlers via the registry.
  It serves as the bridge between the transport layer and the capability
  implementations.
  """

  require Logger
  alias Mcpex.RateLimiter.Server, as: RateLimiterServer
  alias Mcpex.Protocol.Errors

  @doc """
  Handle an MCP message with rate limiting.

  This function is used by the transport layers to process MCP messages.
  It applies rate limiting based on the session ID and returns appropriate
  responses or error messages.

  ## Parameters

  - `method` - The MCP method to call (e.g., "resources/list")
  - `params` - The parameters for the method call
  - `session_id` - The session ID for rate limiting

  ## Returns

  - `{:ok, response}` - The successful response
  - `{:error, error}` - An error response
  """
  @spec handle_message(String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def handle_message(method, params, session_id) do
    # Apply rate limiting
    case check_rate_limit(session_id, method) do
      {:ok, _details} ->
        # Rate limit check passed, process the message
        route_message(method, params, session_id)

      {:error, :rate_limited, details} ->
        Logger.warning(
          "Rate limit exceeded for session #{session_id}, method: #{method}. Details: #{inspect(details)}"
        )

        # Return rate limit error
        error_data = %{
          message: "Too Many Requests. Rate limit exceeded.",
          retryAfterSeconds: details.retry_after_seconds,
          resetAt: details.reset_at
        }

        {:error, {:server_error, -32029, "Too Many Requests", error_data}}

      {:error, :rate_limiter_unavailable} ->
        # Rate limiter not available, log warning but continue processing
        Logger.warning("Rate limiter unavailable for session #{session_id}, method: #{method}")
        route_message(method, params, session_id)

      {:error, reason} ->
        # Other error
        Logger.error("Error checking rate limit for session #{session_id}: #{inspect(reason)}")
        {:error, Errors.internal_error("Error checking rate limit: #{inspect(reason)}")}
    end
  end

  # Private functions

  defp check_rate_limit(session_id, _method) do
    rate_limiter_server = Mcpex.RateLimiter.Server
    rule_name = :default_mcp_request

    # Check if rate limiter is available
    case Process.whereis(rate_limiter_server) do
      nil ->
        # Rate limiter not available
        {:error, :rate_limiter_unavailable}

      _pid ->
        # Check rate limit
        RateLimiterServer.check_and_update_limit(rate_limiter_server, session_id, rule_name)
    end
  end

  defp route_message(method, params, session_id) do
    # Parse method to determine capability
    {capability, _specific_method} = parse_method(method)

    case Mcpex.Registry.lookup(capability) do
      {:ok, {_pid, %{module: module}}} ->
        try do
          case apply(module, :handle_request, [method, params, session_id]) do
            {:ok, result} ->
              {:ok, result}

            {:error, error} ->
              {:error, error}
          end
        rescue
          e ->
            Logger.error("Error handling request #{method}: #{inspect(e)}")
            {:error, Errors.internal_error("Unexpected error: #{inspect(e)}")}
        end

      {:error, :not_found} ->
        Logger.warning("No handler found for method: #{method}")
        {:error, Errors.method_not_found()}
    end
  end

  defp parse_method(method) do
    case String.split(method, "/", parts: 2) do
      [capability, specific_method] -> {String.to_atom(capability), specific_method}
      [capability] -> {String.to_atom(capability), nil}
    end
  end
end

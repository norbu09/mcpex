defmodule Mcpex.Router do
  @moduledoc """
  Main router for MCP server endpoints.

  This router demonstrates how to integrate both MCP transport implementations
  (SSE and Streamable HTTP) into a single application using Plug.Router.

  All MCP messages processed via `handle_mcp_message/3` are subject to rate limiting
  based on session ID and the type of request. If a client exceeds the configured
  rate limits, they will receive a JSON-RPC error response (typically code -32029)
  indicating "Too Many Requests".

  ## Usage

      # In your application
      children = [
        {Plug.Bandit, plug: Mcpex.Router, scheme: :http, port: 4000}
      ]

      # Or with Cowboy
      children = [
        {Plug.Cowboy, plug: Mcpex.Router, scheme: :http, port: 4000}
      ]

  ## Endpoints

  - `POST /mcp/sse` - SSE transport for legacy clients (MCP 2024-11-05)
  - `GET /mcp/sse/stream` - SSE stream endpoint
  - `POST /mcp` - Streamable HTTP transport (MCP 2025-03-26)
  - `GET /mcp/stream` - Optional SSE stream for Streamable HTTP
  - `GET /health` - Health check endpoint

  ## Session Management

  The router uses Plug.Session for HTTP session management and integrates
  with the MCP session manager for protocol-specific session handling.
  """

  use Plug.Router
  require Logger

  alias Mcpex.Transport.{SSE, StreamableHttp}
  alias Mcpex.RateLimiter.Server, as: RateLimiterServer # New Alias
  alias Mcpex.Protocol.Errors # New Alias

  # Plug pipeline
  plug Plug.Logger
  plug :match
  plug :dispatch

  # Session configuration using our custom MCP session store
  plug Plug.Session,
    store: Mcpex.Session.Store,
    key: "_mcpex_session",
    table: :mcpex_sessions

  # CORS support for development
  plug :cors_headers

  # Health check endpoint
  get "/health" do
    send_resp(conn, 200, "OK")
  end

  # SSE Transport (Legacy MCP 2024-11-05)
  post "/mcp/sse" do
    SSE.call(conn, SSE.init(message_handler: &handle_mcp_message/3))
  end

  get "/mcp/sse/stream" do
    SSE.call(conn, SSE.init(message_handler: &handle_mcp_message/3))
  end

  # Streamable HTTP Transport (Current MCP 2025-03-26)
  post "/mcp" do
    StreamableHttp.call(conn, StreamableHttp.init(message_handler: &handle_mcp_message/3))
  end

  get "/mcp/stream" do
    StreamableHttp.call(conn, StreamableHttp.init(message_handler: &handle_mcp_message/3))
  end

  # OPTIONS support for CORS
  options "/mcp" do
    send_resp(conn, 200, "")
  end

  options "/mcp/sse" do
    send_resp(conn, 200, "")
  end

  # Catch-all for undefined routes
  match _ do
    send_resp(conn, 404, "Not found")
  end

  # Private functions

  defp cors_headers(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Mcp-Session-Id")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
  end

  # Example message handler - in a real application, this would be more sophisticated
  # Note: This function is subject to rate limiting. See module doc for details.
  defp handle_mcp_message(method, params, session_id) do
    # Rate Limiting Check
    # Assume RateLimiterServer is started under Mcpex.RateLimiter.Server name
    # In a real app, this name might come from config or an application registry.
    rate_limiter_process_name = Mcpex.RateLimiter.Server # Or a configured name

    case RateLimiterServer.check_and_update_limit(rate_limiter_process_name, session_id, :default_mcp_request) do
      {:ok, _details} ->
        # Rate limit check passed, proceed with normal message handling
        Logger.info("Rate limit check passed for session #{session_id}, method: #{method}")
        # Original message handling logic starts here
        Logger.info("Handling MCP message: #{method} for session #{session_id}")
        Logger.debug("Parameters: #{inspect(params)}")

        case method do
          "resources/list" ->
            # Return example resources
            {:ok, %{
          resources: [
            %{
              uri: "file://example.txt",
              name: "Example File",
              description: "An example text file",
              mimeType: "text/plain"
            }
          ]
        }}

      "resources/read" ->
        case Map.get(params, :uri) do
          "file://example.txt" ->
            {:ok, %{
              contents: [
                %{
                  type: "text",
                  text: "This is an example file content."
                }
              ]
            }}

          _ ->
            {:error, {:invalid_params, "Resource not found"}}
        end

      "prompts/list" ->
        # Return example prompts
        {:ok, %{
          prompts: [
            %{
              name: "greeting",
              description: "A simple greeting prompt",
              arguments: [
                %{
                  name: "name",
                  description: "The name to greet",
                  required: true
                }
              ]
            }
          ]
        }}

      "prompts/get" ->
        case Map.get(params, :name) do
          "greeting" ->
            name = get_in(params, [:arguments, :name]) || "World"
            {:ok, %{
              description: "A greeting prompt",
              messages: [
                %{
                  role: "user",
                  content: %{
                    type: "text",
                    text: "Hello, #{name}! How are you today?"
                  }
                }
              ]
            }}

          _ ->
            {:error, {:invalid_params, "Prompt not found"}}
        end

      "tools/list" ->
        # Return example tools
        {:ok, %{
          tools: [
            %{
              name: "echo",
              description: "Echo back the input text",
              inputSchema: %{
                type: "object",
                properties: %{
                  text: %{
                    type: "string",
                    description: "Text to echo back"
                  }
                },
                required: ["text"]
              }
            }
          ]
        }}

      "tools/call" ->
        case Map.get(params, :name) do
          "echo" ->
            text = get_in(params, [:arguments, :text]) || ""
            {:ok, %{
              content: [
                %{
                  type: "text",
                  text: "Echo: #{text}"
                }
              ]
            }}

          _ ->
            {:error, {:invalid_params, "Tool not found"}}
        end

      _ ->
        {:error, {:method_not_found, "Method not implemented: #{method}"}}
    end
        # End of original message handling logic

      {:error, :rate_limited, details} ->
        Logger.warn("Rate limit exceeded for session #{session_id}, method: #{method}. Details: #{inspect(details)}")
        # MCP protocol expects error responses in a specific format.
        # Using a custom error code for rate limiting, e.g., -32029
        # The `id` for the error response should ideally match the request `id` if available.
        # However, `handle_mcp_message` doesn't receive the request `id` directly.
        # The transport layer (`sse.ex`, `streamable_http.ex`) adds the `id` to the response.
        # So, we return an error tuple that the transport layer can convert.
        error_data = %{
          message: "Too Many Requests. Rate limit exceeded.",
          retryAfterSeconds: details.retry_after_seconds,
          resetAt: details.reset_at
        }
        # Using a custom error type :rate_limit_exceeded, which Errors.normalize_error can handle
        # if we define it there, or a generic one for now.
        # Let's use a structure that Errors.normalize_error can understand or extend.
        # For now, :server_error with a specific code.
        # The `Errors.normalize_error` function might need adjustment if we want a very specific code.
        # Let's use a tuple that can be somewhat descriptive for Errors.normalize_error.
        {:error, {:server_error, -32029, "Too Many Requests", error_data}}


      {:error, :timeout} ->
        Logger.error("Rate limiter GenServer call timed out for session #{session_id}, method: #{method}.")
        # Fail open or closed? For now, let's fail open but log an error.
        # This indicates a problem with the rate limiter itself.
        # Proceeding as if passed, but this should be monitored.
        # Alternatively, return a specific server error.
        {:error, {:server_error, -32001, "Rate limiter timeout", %{}}}


      {:error, reason} -> # Other GenServer call errors (e.g., :noproc if not started)
        Logger.error("Rate limiter error for session #{session_id}, method: #{method}. Reason: #{inspect(reason)}")
        # Fail open or closed? Similar to timeout, this is an issue with the limiter.
        # Let's return a server error.
        {:error, {:server_error, -32002, "Rate limiter unavailable", %{reason: inspect(reason)}}}

    end
  end
end

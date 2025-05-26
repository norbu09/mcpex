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
  @spec handle_mcp_message(String.t(), map(), String.t()) :: 
    {:ok, map()} | {:error, term()}

  # Define the handle_mcp_message function
  def handle_mcp_message(method, params, session_id) do
    # Apply rate limiting
    rate_limiter_server = Mcpex.RateLimiter.Server
    rule_name = :default_mcp_request
    
    # Check if rate limiter is available
    rate_limit_result = case Process.whereis(rate_limiter_server) do
      nil ->
        # Rate limiter not available, return error
        {:error, :rate_limiter_unavailable}
      _pid ->
        # Check rate limit
        RateLimiterServer.check_and_update_limit(rate_limiter_server, session_id, rule_name)
    end
    
    case rate_limit_result do
      {:ok, _details} ->
        # Rate limit check passed, process the message
        case method do
          "resources/list" ->
            # Return example resources
            {:ok, %{
              resources: [
                %{
                  uri: "file://example.txt",
                  title: "Example Text File"
                }
              ]
            }}
            
          "resources/get" ->
            # Return example resource content
            uri = Map.get(params, :uri)
            Logger.info("Reading resource for session #{session_id} with params: #{inspect(params)}")
            
            case uri do
              "file://example.txt" ->
                {:ok, %{
                  content: "This is an example text file."
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
        
      {:error, :rate_limited, details} ->
        Logger.warning("Rate limit exceeded for session #{session_id}, method: #{method}. Details: #{inspect(details)}")
        # Return rate limit error
        error_data = %{
          message: "Too Many Requests. Rate limit exceeded.",
          retryAfterSeconds: details.retry_after_seconds,
          resetAt: details.reset_at
        }
        {:error, {:server_error, -32029, "Too Many Requests", error_data}}
        
      {:error, :rate_limiter_unavailable} ->
        # Rate limiter not available
        {:error, {:server_error, -32002, "Rate limiter unavailable", %{message: "Rate limiting service is unavailable"}}}
        
      {:error, reason} ->
        # Other error
        {:error, {:server_error, -32000, "Unknown error", %{message: "Error checking rate limit: #{inspect(reason)}"}}}
    end
  end
  
  # Plug pipeline
  plug Plug.Logger
  plug :match
  plug :dispatch

  # Session configuration using our custom MCP session store
  plug Plug.Session,
    store: Mcpex.Session.Store,
    key: "mcpex_session",
    signing_salt: "mcpex_salt"

  # Enable CORS for all routes
  plug :cors_headers

  # Health check endpoint
  get "/health" do
    send_resp(conn, 200, "OK")
  end

  # SSE transport endpoints
  post "/mcp/sse" do
    SSE.handle_request(conn)
  end

  get "/mcp/sse/stream" do
    SSE.handle_stream(conn)
  end

  # Streamable HTTP transport endpoints
  post "/mcp" do
    StreamableHttp.handle_request(conn)
  end

  get "/mcp/stream" do
    StreamableHttp.handle_stream(conn)
  end

  # CORS preflight
  options _ do
    send_resp(conn, 200, "")
  end

  # Catch-all route
  match _ do
    send_resp(conn, 404, "Not found")
  end

  # Helper function to add CORS headers
  defp cors_headers(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Mcp-Session-Id")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
  end
end
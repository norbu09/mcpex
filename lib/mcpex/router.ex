defmodule Mcpex.Router do
  @moduledoc """
  Main router for MCP server endpoints.

  This router demonstrates how to integrate both MCP transport implementations
  (SSE and Streamable HTTP) into a single application using Plug.Router.

  All MCP messages are processed via `Mcpex.MessageHandler.handle_message/3` which
  applies rate limiting based on session ID and the type of request. If a client 
  exceeds the configured rate limits, they will receive a JSON-RPC error response 
  (typically code -32029) indicating "Too Many Requests".

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

  # Plug pipeline
  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  # Session configuration using our custom MCP session store
  plug(Plug.Session,
    store: Mcpex.Session.Store,
    key: "mcpex_session",
    signing_salt: "mcpex_salt"
  )

  # Enable CORS for all routes
  plug(:cors_headers)

  # Health check endpoint
  get "/health" do
    send_resp(conn, 200, "OK")
  end

  # SSE transport endpoints
  post "/mcp/sse" do
    SSE.call(conn, [])
  end

  get "/mcp/sse/stream" do
    SSE.handle_stream(conn)
  end

  # Streamable HTTP transport endpoints
  post "/mcp" do
    StreamableHttp.call(conn, [])
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

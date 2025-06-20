defmodule BasicMcpServer.Transport.SSE do
  @moduledoc """
  Server-Sent Events (SSE) transport for the MCP protocol.

  This module implements the SSE transport layer as specified in the MCP specification.
  SSE provides a simple way for clients to receive real-time updates from the server
  while using standard HTTP for sending requests.

  ## Protocol Flow

  1. Client establishes SSE connection to `/sse` endpoint
  2. Client sends HTTP requests to `/message` endpoint
  3. Server sends responses and notifications via SSE stream
  4. Session is maintained until SSE connection is closed

  ## Endpoints

  - `GET /sse` - Establish SSE connection
  - `POST /message` - Send MCP message
  """

  use Plug.Router
  require Logger

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], json_decoder: JSON)
  plug(:match)
  plug(:dispatch)

  @doc """
  Starts the SSE transport server.

  ## Options

  - `:port` - The port to listen on (default: 4001)
  """
  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, 4001)

    Bandit.start_link(
      plug: __MODULE__,
      port: port,
      options: [
        http_1_options: [
          idle_timeout: 300_000,
          request_timeout: 60_000
        ]
      ]
    )
  end

  # SSE endpoint - establishes persistent connection
  get "/sse" do
    session_id = generate_session_id()
    Logger.info("SSE connection established for session: #{session_id}")

    # Set SSE headers
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("access-control-allow-headers", "Content-Type")

    # Send the session ID to the client
    conn = send_chunked(conn, 200)
    conn = send_sse_event(conn, "session", %{"sessionId" => session_id})
    keep_connection_alive(conn)
  end

  # Message endpoint - processes MCP messages
  post "/message" do
    session_id = get_session_id(conn)
    Logger.debug("Received message for session: #{inspect(session_id)}")

    case conn.body_params do
      %{} = message ->
        # Process the MCP message
        case BasicMcpServer.Server.handle_message(message) do
          {:ok, response} ->
            Logger.debug("Sending response: #{inspect(response)}")

            # Send response via SSE (if we have the connection)
            # For now, we'll return it as HTTP response
            # In a full implementation, this would go through the SSE stream
            conn
            |> put_resp_header("content-type", "application/json")
            |> send_resp(200, JSON.encode!(response))

          {:error, error} ->
            Logger.error("Error processing message: #{inspect(error)}")

            error_response = %{
              "jsonrpc" => "2.0",
              "id" => Map.get(message, "id"),
              "error" => %{
                "code" => -32603,
                "message" => "Internal error",
                "data" => inspect(error)
              }
            }

            conn
            |> put_resp_header("content-type", "application/json")
            |> send_resp(500, JSON.encode!(error_response))
        end

      _ ->
        Logger.error("Invalid message format")

        error_response = %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32700,
            "message" => "Parse error"
          }
        }

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, JSON.encode!(error_response))
    end
  end

  # CORS preflight
  options "/message" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type")
    |> send_resp(200, "")
  end

  # Health check endpoint
  get "/health" do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{"status" => "ok", "transport" => "sse"}))
  end

  # Catch-all route
  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, JSON.encode!(%{"error" => "Not found"}))
  end

  # Private helper functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_session_id(conn) do
    # Extract session ID from headers or query params
    case get_req_header(conn, "x-session-id") do
      [session_id] -> session_id
      _ -> "default-session"
    end
  end

  defp send_sse_event(conn, event_type, data) do
    event_data = JSON.encode!(data)

    event_string = """
    event: #{event_type}
    data: #{event_data}

    """

    {:ok, conn} = chunk(conn, event_string)
    conn
  end

  defp keep_connection_alive(conn) do
    # Send periodic heartbeat to keep connection alive
    spawn(fn ->
      :timer.sleep(30_000)
      send_heartbeat(conn)
    end)

    conn
  end

  defp send_heartbeat(conn) do
    try do
      heartbeat = """
      event: heartbeat
      data: {"timestamp": "#{DateTime.utc_now() |> DateTime.to_iso8601()}"}

      """

      chunk(conn, heartbeat)
    rescue
      _ ->
        # Connection closed, stop heartbeat
        :ok
    end
  end
end

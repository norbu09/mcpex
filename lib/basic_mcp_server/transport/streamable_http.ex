defmodule BasicMcpServer.Transport.StreamableHTTP do
  @moduledoc """
  Streamable HTTP transport for the MCP protocol.

  This module implements the Streamable HTTP transport layer as specified in the MCP specification.
  It provides a bidirectional streaming communication channel over HTTP using newline-delimited JSON.

  ## Protocol Flow

  1. Client sends HTTP POST request to `/message` with MCP message
  2. Server responds with streaming HTTP response
  3. Each message is a JSON object followed by a newline
  4. Connection can be kept alive for multiple message exchanges

  ## Endpoints

  - `POST /message` - Send/receive MCP messages with streaming support
  """

  use Plug.Router
  require Logger

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], json_decoder: JSON)
  plug(:match)
  plug(:dispatch)

  @doc """
  Starts the StreamableHTTP transport server.

  ## Options

  - `:port` - The port to listen on (default: 4000)
  """
  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, 4000)

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

  # Main message endpoint with streaming support
  post "/message" do
    session_id = get_session_id(conn)
    Logger.debug("Received StreamableHTTP message for session: #{inspect(session_id)}")

    case conn.body_params do
      %{} = message ->
        # Check if client accepts streaming responses
        accept_streaming = accepts_streaming?(conn)

        if accept_streaming do
          handle_streaming_request(conn, message, session_id)
        else
          handle_single_request(conn, message, session_id)
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
    |> put_resp_header("access-control-allow-headers", "Content-Type, Accept")
    |> send_resp(200, "")
  end

  # Health check endpoint
  get "/health" do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, JSON.encode!(%{"status" => "ok", "transport" => "streamable_http"}))
  end

  # Catch-all route
  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, JSON.encode!(%{"error" => "Not found"}))
  end

  # Private helper functions

  defp get_session_id(conn) do
    # Extract session ID from headers
    case get_req_header(conn, "x-session-id") do
      [session_id] -> session_id
      _ -> generate_session_id()
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp accepts_streaming?(conn) do
    # Check if client accepts streaming responses
    case get_req_header(conn, "accept") do
      [accept] -> String.contains?(accept, "application/x-ndjson") or String.contains?(accept, "application/json-seq")
      _ -> false
    end
  end

  defp handle_single_request(conn, message, session_id) do
    # Process the MCP message normally
    case BasicMcpServer.Server.handle_message(message) do
      {:ok, response} ->
        Logger.debug("Sending single response: #{inspect(response)}")

        conn
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("x-session-id", session_id)
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
        |> put_resp_header("x-session-id", session_id)
        |> send_resp(500, JSON.encode!(error_response))
    end
  end

  defp handle_streaming_request(conn, message, session_id) do
    # Set up streaming response
    conn =
      conn
      |> put_resp_header("content-type", "application/x-ndjson")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-session-id", session_id)
      |> put_resp_header("access-control-allow-origin", "*")

    # Start chunked response
    conn = send_chunked(conn, 200)

    # Process the MCP message
    case BasicMcpServer.Server.handle_message(message) do
      {:ok, response} ->
        Logger.debug("Sending streaming response: #{inspect(response)}")

        # Send response as NDJSON
        response_json = JSON.encode!(response) <> "\n"
        {:ok, conn} = chunk(conn, response_json)

        # For demonstration, send a completion marker
        completion_marker = JSON.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "notifications/complete",
          "params" => %{"sessionId" => session_id}
        }) <> "\n"

        {:ok, conn} = chunk(conn, completion_marker)
        conn

      {:error, error} ->
        Logger.error("Error processing streaming message: #{inspect(error)}")

        error_response = %{
          "jsonrpc" => "2.0",
          "id" => Map.get(message, "id"),
          "error" => %{
            "code" => -32603,
            "message" => "Internal error",
            "data" => inspect(error)
          }
        }

        error_json = JSON.encode!(error_response) <> "\n"
        {:ok, conn} = chunk(conn, error_json)
        conn
    end
  end
end

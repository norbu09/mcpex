defmodule Mcpex.Transport.Behaviour do
  @moduledoc """
  Behaviour for MCP transport implementations.

  This behaviour defines the common interface that all MCP transport
  implementations must follow. It provides lifecycle callbacks and
  message routing capabilities.

  Transport implementations handle the HTTP layer and session management,
  while delegating JSON-RPC message processing to the protocol layer.
  """

  alias Mcpex.Protocol.JsonRpc
  alias Plug.Conn

  @type transport_opts :: keyword()
  @type session_id :: String.t()
  @type message :: map()
  @type transport_result :: {:ok, Conn.t()} | {:error, term()}

  @doc """
  Initialize the transport with the given options.

  This callback is called when the transport is started and should
  return the initialized options that will be passed to other callbacks.
  """
  @callback init(transport_opts()) :: transport_opts()

  @doc """
  Handle an incoming HTTP request for this transport.

  This is the main entry point for processing MCP requests. The transport
  should:
  1. Validate the request format
  2. Extract or create session information
  3. Parse the JSON-RPC message
  4. Route the message to appropriate handlers
  5. Send the response back to the client
  """
  @callback handle_request(Conn.t(), transport_opts()) :: transport_result()

  @doc """
  Send a notification to a client session.

  This callback is used to send server-initiated notifications to clients.
  The implementation should handle the specific transport mechanism
  (SSE stream, HTTP response, etc.).
  """
  @callback send_notification(session_id(), message(), transport_opts()) :: :ok | {:error, term()}

  @doc """
  Validate the security requirements for this transport.

  This callback should check Origin headers, authentication, and other
  security measures specific to the transport type.
  """
  @callback validate_security(Conn.t(), transport_opts()) :: {:ok, Conn.t()} | {:error, term()}

  @doc """
  Get or create a session ID for the connection.

  This callback handles session management, either by extracting an
  existing session ID from headers or creating a new one.
  """
  @callback get_session_id(Conn.t(), transport_opts()) :: {session_id() | nil, Conn.t()}

  @doc """
  Clean up resources when a session ends.

  This callback is called when a session is terminated and should
  clean up any resources associated with the session.
  """
  @callback cleanup_session(session_id(), transport_opts()) :: :ok

  @doc """
  Helper function to parse JSON-RPC messages from request body.
  """
  @spec parse_json_rpc_message(String.t()) :: {:ok, JsonRpc.message() | [JsonRpc.message()]} | {:error, term()}
  def parse_json_rpc_message(body) when is_binary(body) do
    JsonRpc.parse(body)
  end

  @doc """
  Helper function to encode JSON-RPC messages for response.
  """
  @spec encode_json_rpc_message(JsonRpc.message() | [JsonRpc.message()]) :: {:ok, String.t()} | {:error, term()}
  def encode_json_rpc_message(message) do
    JsonRpc.encode(message)
  end

  @doc """
  Helper function to validate Origin header for security.
  """
  @spec validate_origin(Conn.t(), [String.t()]) :: {:ok, Conn.t()} | {:error, :invalid_origin}
  def validate_origin(conn, allowed_origins \\ ["http://localhost", "https://localhost"]) do
    case Conn.get_req_header(conn, "origin") do
      [] ->
        # No origin header - allow for same-origin requests
        {:ok, conn}

      [origin] ->
        if origin_allowed?(origin, allowed_origins) do
          {:ok, conn}
        else
          {:error, :invalid_origin}
        end

      _ ->
        # Multiple origin headers - suspicious
        {:error, :invalid_origin}
    end
  end

  @doc """
  Helper function to generate a new session ID.
  """
  @spec generate_session_id() :: String.t()
  def generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Helper function to send JSON response with proper headers.
  """
  @spec send_json_response(Conn.t(), integer(), term()) :: Conn.t()
  def send_json_response(conn, status, data) do
    try do
      json = JSON.encode!(data)
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(status, json)
    rescue
      _ ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.send_resp(500, ~s({"error": "Internal server error"}))
    end
  end

  @doc """
  Helper function to send Server-Sent Events response.
  """
  @spec send_sse_response(Conn.t(), String.t()) :: Conn.t()
  def send_sse_response(conn, data) do
    conn
    |> Conn.put_resp_content_type("text/event-stream")
    |> Conn.put_resp_header("cache-control", "no-cache")
    |> Conn.put_resp_header("connection", "keep-alive")
    |> Conn.send_resp(200, format_sse_data(data))
  end

  # Private helper functions

  defp origin_allowed?(origin, allowed_origins) do
    Enum.any?(allowed_origins, fn allowed ->
      String.starts_with?(origin, allowed)
    end)
  end

  defp format_sse_data(data) do
    "data: #{data}\n\n"
  end
end

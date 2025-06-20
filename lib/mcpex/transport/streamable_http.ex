defmodule Mcpex.Transport.StreamableHttp do
  @moduledoc """
  Streamable HTTP transport implementation for MCP protocol version 2025-03-26.

  This transport implements the current MCP protocol using:
  - HTTP POST for client-to-server messages
  - Optional SSE streams for server-to-client messages
  - Session ID management via Mcp-Session-Id headers
  - Resumable connections

  The Streamable HTTP transport is designed as a Plug module that integrates
  seamlessly with Plug's session handling and provides better session management
  than the legacy SSE transport.

  ## Usage

      # In your router
      post "/mcp", Mcpex.Transport.StreamableHttp, []
      get "/mcp/stream", Mcpex.Transport.StreamableHttp, action: :sse_stream

  ## Session Management

  This transport uses the `Mcp-Session-Id` header for session identification
  and falls back to Plug's session management for compatibility.

  ## Security

  - Origin header validation to prevent DNS rebinding attacks
  - Session-based security with proper cleanup
  - TLS support for production deployments
  """

  @behaviour Plug

  import Plug.Conn
  require Logger

  alias Mcpex.Transport.Behaviour
  alias Mcpex.Session.Helpers
  alias Mcpex.Protocol.{JsonRpc, Errors, Messages}

  @impl Plug
  def init(opts) do
    defaults = [
      allowed_origins: ["http://localhost", "https://localhost"],
      message_handler: nil,
      session_store: :ets,
      enable_streaming: true,
      # 1MB
      max_body_length: 1_048_576
    ]

    Keyword.merge(defaults, opts)
  end

  @impl Plug
  def call(conn, opts) do
    case {conn.method, conn.path_info} do
      {"POST", _} ->
        handle_post_request(conn, opts)

      {"GET", _} ->
        if Keyword.get(opts, :enable_streaming, true) do
          handle_stream_request(conn, opts)
        else
          send_method_not_allowed(conn)
        end

      _ ->
        send_method_not_allowed(conn)
    end
  end

  def handle_request(conn, opts) do
    call(conn, opts)
  end

  def validate_security(conn, opts) do
    allowed_origins =
      Keyword.get(opts, :allowed_origins, ["http://localhost", "https://localhost"])

    Behaviour.validate_origin(conn, allowed_origins)
  end

  def get_session_id(conn, _opts) do
    Helpers.ensure_session(conn)
  end

  def send_notification(session_id, message, _opts) do
    # For Streamable HTTP, notifications can be sent via optional SSE streams
    # or stored for the next client request
    Logger.info("Streamable HTTP notification for session #{session_id}: #{inspect(message)}")

    # In a full implementation, this would:
    # 1. Check if there's an active SSE stream for the session
    # 2. Send immediately via SSE if available
    # 3. Store for retrieval on next client request if no stream
    :ok
  end

  def cleanup_session(_session_id, _opts) do
    # Session cleanup is handled by Plug.Session and our custom store
    :ok
  end

  # Private functions

  defp handle_post_request(conn, opts) do
    with {:ok, conn} <- validate_security(conn, opts),
         {:ok, conn} <- validate_content_type(conn),
         {:ok, body, conn} <- read_body(conn, length: opts[:max_body_length]),
         {:ok, message} <- Behaviour.parse_json_rpc_message(body),
         {session_id, conn} <- get_or_create_session(conn, opts),
         {:ok, response} <- process_message(message, session_id, conn, opts) do
      conn = prepare_response_headers(conn, session_id)
      # Set transport type for this session
      Helpers.set_transport(conn, :streamable_http)

      case response do
        nil ->
          # No response needed (e.g., notifications only)
          send_resp(conn, 204, "")

        response ->
          Behaviour.send_json_response(conn, 200, response)
      end
    else
      {:error, :invalid_origin} ->
        send_forbidden(conn, "Invalid origin")

      {:error, :invalid_content_type} ->
        send_bad_request(conn, "Content-Type must be application/json")

      {:error, {:parse_error, reason}} ->
        error_response =
          Errors.to_error_response(Errors.create_error(:parse_error, reason, nil), nil)

        Behaviour.send_json_response(conn, 400, error_response)

      {:error, {:invalid_request, reason}} ->
        error_response =
          Errors.to_error_response(Errors.create_error(:invalid_request, reason, nil), nil)

        Behaviour.send_json_response(conn, 400, error_response)

      {:error, reason} ->
        Logger.error("Streamable HTTP transport error: #{inspect(reason)}")

        error_response =
          Errors.to_error_response(
            Errors.create_error(:internal_error, "Internal server error", nil),
            nil
          )

        Behaviour.send_json_response(conn, 500, error_response)
    end
  end

  defp handle_stream_request(conn, opts) do
    with {:ok, conn} <- validate_security(conn, opts),
         {session_id, conn} <- get_or_create_session(conn, opts) do
      # Set transport type and start SSE stream
      Helpers.set_transport(conn, :streamable_http)
      start_sse_stream(conn, session_id, opts)
    else
      {:error, :invalid_origin} ->
        send_forbidden(conn, "Invalid origin")

      {:error, reason} ->
        Logger.error("Streamable HTTP stream error: #{inspect(reason)}")
        send_resp(conn, 500, "Internal server error")
    end
  end

  defp get_or_create_session(conn, opts) do
    get_session_id(conn, opts)
  end

  defp start_sse_stream(conn, session_id, _opts) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("mcp-session-id", session_id)
      |> send_chunked(200)

    # Send initial connection message
    initial_message = %{
      jsonrpc: "2.0",
      method: "notifications/stream/established",
      params: %{sessionId: session_id}
    }

    case Behaviour.encode_json_rpc_message(initial_message) do
      {:ok, json} ->
        {:ok, conn} = chunk(conn, format_sse_data(json))

        # In a full implementation, this would register the connection
        # for receiving notifications and keep it alive
        Logger.info("Streamable HTTP SSE stream established for session #{session_id}")
        conn

      {:error, _} ->
        {:ok, conn} = chunk(conn, format_sse_data(~s({"error": "Failed to establish stream"})))
        conn
    end
  end

  defp process_message(message, session_id, conn, opts) when is_map(message) do
    handle_single_message(message, session_id, conn, opts)
  end

  defp process_message(messages, session_id, conn, opts) when is_list(messages) do
    # Handle batch messages
    responses = Enum.map(messages, &handle_single_message(&1, session_id, conn, opts))

    # Filter out notifications (which don't have responses)
    valid_responses =
      Enum.filter(responses, fn
        {:ok, response} when is_map(response) -> true
        _ -> false
      end)

    case valid_responses do
      # All notifications
      [] -> {:ok, nil}
      responses -> {:ok, Enum.map(responses, fn {:ok, resp} -> resp end)}
    end
  end

  defp handle_single_message(message, session_id, conn, opts) do
    cond do
      JsonRpc.request?(message) ->
        handle_request(message, session_id, conn, opts)

      JsonRpc.notification?(message) ->
        handle_notification(message, session_id, opts)
        # Notifications don't have responses
        {:ok, nil}

      true ->
        error = Errors.create_error(:invalid_request, "Invalid message type", nil)
        {:ok, Errors.to_error_response(error, JsonRpc.get_id(message))}
    end
  end

  defp handle_request(message, session_id, conn, opts) do
    method = JsonRpc.get_method(message)
    params = Map.get(message, :params, %{})
    id = JsonRpc.get_id(message)

    case method do
      "initialize" ->
        handle_initialize(params, session_id, id, conn)

      _ ->
        # Delegate to message handler if provided
        case Keyword.get(opts, :message_handler) do
          nil ->
            error = Errors.create_error(:method_not_found, "Method not found: #{method}", nil)
            {:ok, Errors.to_error_response(error, id)}

          handler when is_function(handler, 3) ->
            case handler.(method, params, session_id) do
              {:ok, result} ->
                {:ok, JsonRpc.response(result, id)}

              {:error, error} ->
                normalized_error = Errors.normalize_error(error)
                {:ok, Errors.to_error_response(normalized_error, id)}
            end

          {module, function} ->
            case apply(module, function, [method, params, session_id]) do
              {:ok, result} ->
                {:ok, JsonRpc.response(result, id)}

              {:error, error} ->
                normalized_error = Errors.normalize_error(error)
                {:ok, Errors.to_error_response(normalized_error, id)}
            end
        end
    end
  end

  defp handle_notification(message, session_id, _opts) do
    method = JsonRpc.get_method(message)
    params = Map.get(message, :params, %{})

    case method do
      "initialized" ->
        Logger.info("Session #{session_id} initialized")
        :ok

      _ ->
        Logger.debug(
          "Received notification #{method} for session #{session_id}: #{inspect(params)}"
        )

        :ok
    end
  end

  defp handle_initialize(params, _session_id, id, conn) do
    case Messages.validate_initialize_params(params) do
      {:ok, validated_params} ->
        # Update session with client info and capabilities
        client_info = validated_params.clientInfo
        capabilities = validated_params.capabilities

        Helpers.initialize_mcp_session(conn, client_info, capabilities)

        # Return server capabilities
        server_info = %{name: "mcpex", version: "0.1.0"}

        server_capabilities = %{
          resources: %{},
          prompts: %{},
          tools: %{}
        }

        result = Messages.initialize_response(server_info, server_capabilities, id)
        {:ok, result}

      {:error, reason} ->
        error = Errors.create_error(:invalid_params, reason, nil)
        {:ok, Errors.to_error_response(error, id)}
    end
  end

  defp validate_content_type(conn) do
    case get_req_header(conn, "content-type") do
      [] ->
        {:error, :invalid_content_type}

      [content_type] ->
        if String.starts_with?(content_type, "application/json") do
          {:ok, conn}
        else
          {:error, :invalid_content_type}
        end

      _ ->
        {:error, :invalid_content_type}
    end
  end

  defp prepare_response_headers(conn, session_id) do
    conn
    |> put_resp_header("mcp-session-id", session_id)
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Mcp-Session-Id")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
  end

  defp send_method_not_allowed(conn) do
    conn
    |> put_resp_header("allow", "GET, POST")
    |> send_resp(405, "Method not allowed")
  end

  defp send_forbidden(conn, message) do
    send_resp(conn, 403, message)
  end

  defp send_bad_request(conn, message) do
    send_resp(conn, 400, message)
  end

  defp format_sse_data(data) do
    "data: #{data}\n\n"
  end
end

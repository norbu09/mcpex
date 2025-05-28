defmodule Mcpex.Transport.SSE do
  @moduledoc """
  Server-Sent Events (SSE) transport implementation for MCP.

  This transport implements the legacy MCP protocol version 2024-11-05 using:
  - HTTP POST for client-to-server messages
  - Server-Sent Events (SSE) for server-to-client messages
  - Origin validation for security

  The SSE transport is designed as a Plug module that can be integrated
  into any Plug-based application or used standalone.

  ## Usage

      # In your router
      post "/mcp", Mcpex.Transport.SSE, []
      get "/mcp/sse", Mcpex.Transport.SSE, action: :sse_stream

  ## Security

  This transport validates Origin headers to prevent DNS rebinding attacks
  and only allows connections from localhost by default.
  """

  @behaviour Plug

  import Plug.Conn
  require Logger

  alias Mcpex.Transport.Behaviour
  alias Mcpex.Session.Helpers
  alias Mcpex.Protocol.{JsonRpc, Errors}

  @impl Plug
  def init(opts) do
    defaults = [
      allowed_origins: ["http://localhost", "https://localhost"],
      message_handler: nil,
      session_store: :ets
    ]

    Keyword.merge(defaults, opts)
  end

  @impl Plug
  def call(conn, opts) do
    case conn.method do
      "POST" -> handle_post_request(conn, opts)
      "GET" -> handle_sse_request(conn, opts)
      _ -> send_method_not_allowed(conn)
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
    # For SSE, notifications are sent through the SSE stream
    # This would typically involve a registry of SSE connections
    # For now, we'll log the notification
    Logger.info("SSE notification for session #{session_id}: #{inspect(message)}")
    :ok
  end

  def cleanup_session(_session_id, _opts) do
    # Session cleanup is handled by Plug.Session and our custom store
    :ok
  end

  # Private functions

  defp handle_post_request(conn, opts) do
    with {:ok, conn} <- validate_security(conn, opts),
         {:ok, body, conn} <- read_body(conn),
         {:ok, message} <- Behaviour.parse_json_rpc_message(body),
         {session_id, conn} <- get_session_id(conn, opts),
         {:ok, response} <- process_message(message, session_id, conn, opts) do
      conn = Helpers.put_session_header(conn, session_id)
      Behaviour.send_json_response(conn, 200, response)
    else
      {:error, :invalid_origin} ->
        send_forbidden(conn, "Invalid origin")

      {:error, {:parse_error, reason}} ->
        error_response =
          Errors.to_error_response(Errors.create_error(:parse_error, reason, nil), nil)

        Behaviour.send_json_response(conn, 400, error_response)

      {:error, {:invalid_request, reason}} ->
        error_response =
          Errors.to_error_response(Errors.create_error(:invalid_request, reason, nil), nil)

        Behaviour.send_json_response(conn, 400, error_response)

      {:error, reason} ->
        Logger.error("SSE transport error: #{inspect(reason)}")

        error_response =
          Errors.to_error_response(
            Errors.create_error(:internal_error, "Internal server error", nil),
            nil
          )

        Behaviour.send_json_response(conn, 500, error_response)
    end
  end

  defp handle_sse_request(conn, opts) do
    with {:ok, conn} <- validate_security(conn, opts),
         {session_id, conn} <- get_session_id(conn, opts) do
      # Set transport type for this session
      Helpers.set_transport(conn, :sse)
      conn = Helpers.put_session_header(conn, session_id)
      start_sse_stream(conn, session_id, opts)
    else
      {:error, :invalid_origin} ->
        send_forbidden(conn, "Invalid origin")

      {:error, reason} ->
        Logger.error("SSE stream error: #{inspect(reason)}")
        send_resp(conn, 500, "Internal server error")
    end
  end

  defp start_sse_stream(conn, session_id, _opts) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("access-control-allow-origin", "*")
      |> send_chunked(200)

    # Send initial connection message
    initial_message = %{
      jsonrpc: "2.0",
      method: "notifications/connection/established",
      params: %{sessionId: session_id}
    }

    case Behaviour.encode_json_rpc_message(initial_message) do
      {:ok, json} ->
        {:ok, conn} = chunk(conn, format_sse_data(json))

        # Keep connection alive (in a real implementation, this would be handled
        # by a process registry and message passing)
        Logger.info("SSE stream established for session #{session_id}")
        conn

      {:error, _} ->
        {:ok, conn} =
          chunk(conn, format_sse_data(~s({"error": "Failed to establish connection"})))

        conn
    end
  end

  defp process_message(message, session_id, conn, opts) when is_map(message) do
    # Handle single message
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
    case validate_initialize_params(params) do
      {:ok, validated_params} ->
        # Update session with client info and capabilities
        client_info = Map.get(validated_params, "clientInfo", %{})
        capabilities = Map.get(validated_params, "capabilities", %{})

        Helpers.initialize_mcp_session(conn, client_info, capabilities)

        # Return server capabilities
        server_info = %{name: "mcpex", version: "0.1.0"}

        server_capabilities = %{
          resources: %{},
          prompts: %{},
          tools: %{}
        }

        result = %{
          # SSE transport uses legacy version
          protocolVersion: "2024-11-05",
          capabilities: server_capabilities,
          serverInfo: server_info
        }

        {:ok, JsonRpc.response(result, id)}

      {:error, reason} ->
        error = Errors.create_error(:invalid_params, reason, nil)
        {:ok, Errors.to_error_response(error, id)}
    end
  end

  defp validate_initialize_params(params) do
    # Basic validation - in a real implementation, this would be more thorough
    case params do
      %{"protocolVersion" => version, "clientInfo" => client_info}
      when is_binary(version) and is_map(client_info) ->
        {:ok, params}

      _ ->
        {:error, "Invalid initialize parameters"}
    end
  end

  defp send_method_not_allowed(conn) do
    conn
    |> put_resp_header("allow", "GET, POST")
    |> send_resp(405, "Method not allowed")
  end

  defp send_forbidden(conn, message) do
    send_resp(conn, 403, message)
  end

  defp format_sse_data(data) do
    "data: #{data}\n\n"
  end
end

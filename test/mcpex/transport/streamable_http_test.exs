defmodule Mcpex.Transport.StreamableHttpTest do
  use ExUnit.Case, async: false  # Not async due to session store

  alias Mcpex.Transport.StreamableHttp

  setup do
    # Use the same table as the main application
    :ok
  end

  # Helper function to create a test connection with session support
  defp test_conn(method, path, body \\ nil) do
    conn = if body, do: Plug.Test.conn(method, path, body), else: Plug.Test.conn(method, path)

    # Initialize session with our custom store
    conn
    |> Plug.Session.call(Plug.Session.init(
      store: Mcpex.Session.Store,
      key: "_mcpex_session",
      table: :mcpex_sessions
    ))
    |> Plug.Conn.fetch_session()
  end

  # Helper to create a POST connection with JSON headers
  defp json_post_conn(path, body) do
    test_conn(:post, path, body)
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  # Helper to create a connection with origin header
  defp with_origin(conn, origin) do
    Plug.Conn.put_req_header(conn, "origin", origin)
  end

  describe "POST requests" do
    test "handles valid initialize request" do
      body = JSON.encode!(%{
        jsonrpc: "2.0",
        method: "initialize",
        params: %{
          protocolVersion: "2025-03-26",
          clientInfo: %{name: "test-client", version: "1.0.0"},
          capabilities: %{}
        },
        id: "1"
      })

      conn =
        json_post_conn("/mcp", body)
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      assert Plug.Conn.get_resp_header(conn, "mcp-session-id") != []

      {:ok, response} = JSON.decode(conn.resp_body)
      assert response["jsonrpc"] == "2.0"
      assert response["result"]["protocolVersion"] == "2025-03-26"
      assert response["id"] == "1"
    end

    test "handles notification without response" do
      body = JSON.encode!(%{
        jsonrpc: "2.0",
        method: "initialized"
      })

      conn =
        json_post_conn("/mcp", body)
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 204  # No content for notifications
    end

    test "rejects invalid origin" do
      body = JSON.encode!(%{
        jsonrpc: "2.0",
        method: "test",
        id: "1"
      })

      conn =
        json_post_conn("/mcp", body)
        |> with_origin("http://evil.com")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 403
    end

    test "rejects invalid content type" do
      conn =
        test_conn(:post, "/mcp", "some body")
        |> Plug.Conn.put_req_header("content-type", "text/plain")
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 400
    end

    test "handles invalid JSON" do
      conn =
        json_post_conn("/mcp", "invalid json")
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 400

      {:ok, response} = JSON.decode(conn.resp_body)
      assert response["error"]["code"] == -32700  # Parse error
    end

    test "handles method not found" do
      body = JSON.encode!(%{
        jsonrpc: "2.0",
        method: "unknown_method",
        id: "1"
      })

      conn =
        json_post_conn("/mcp", body)
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 200

      {:ok, response} = JSON.decode(conn.resp_body)
      assert response["error"]["code"] == -32601  # Method not found
      assert response["id"] == "1"
    end

    test "uses custom message handler" do
      handler = fn "custom_method", _params, _session_id ->
        {:ok, %{custom: "response"}}
      end

      body = JSON.encode!(%{
        jsonrpc: "2.0",
        method: "custom_method",
        id: "1"
      })

      conn =
        json_post_conn("/mcp", body)
        |> with_origin("http://localhost")

      opts = StreamableHttp.init(message_handler: handler)
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 200

      {:ok, response} = JSON.decode(conn.resp_body)
      assert response["result"]["custom"] == "response"
      assert response["id"] == "1"
    end

    test "handles session ID from header" do
      body = JSON.encode!(%{
        jsonrpc: "2.0",
        method: "initialize",
        params: %{
          protocolVersion: "2025-03-26",
          clientInfo: %{name: "test-client", version: "1.0.0"},
          capabilities: %{}
        },
        id: "1"
      })

      conn =
        json_post_conn("/mcp", body)
        |> Plug.Conn.put_req_header("mcp-session-id", "test-session-123")
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "mcp-session-id") == ["test-session-123"]
    end
  end

  describe "GET requests (SSE stream)" do
    test "establishes SSE stream when enabled" do
      conn =
        test_conn(:get, "/mcp/stream")
        |> with_origin("http://localhost")

      opts = StreamableHttp.init(enable_streaming: true)
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/event-stream; charset=utf-8"]
      assert Plug.Conn.get_resp_header(conn, "cache-control") == ["no-cache"]
      assert Plug.Conn.get_resp_header(conn, "connection") == ["keep-alive"]
      assert Plug.Conn.get_resp_header(conn, "mcp-session-id") != []

      # Should contain initial connection message
      assert String.contains?(conn.resp_body, "data:")
      assert String.contains?(conn.resp_body, "stream/established")
    end

    test "rejects GET when streaming disabled" do
      conn =
        test_conn(:get, "/mcp/stream")
        |> with_origin("http://localhost")

      opts = StreamableHttp.init(enable_streaming: false)
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 405
      assert Plug.Conn.get_resp_header(conn, "allow") == ["GET, POST"]
    end

    test "rejects SSE stream with invalid origin" do
      conn =
        test_conn(:get, "/mcp/stream")
        |> with_origin("http://evil.com")

      opts = StreamableHttp.init(enable_streaming: true)
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 403
    end
  end

  describe "unsupported methods" do
    test "rejects PUT requests" do
      conn = test_conn(:put, "/mcp")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 405
      assert Plug.Conn.get_resp_header(conn, "allow") == ["GET, POST"]
    end
  end

  describe "batch requests" do
    test "handles batch of requests" do
      batch = [
        %{
          jsonrpc: "2.0",
          method: "initialize",
          params: %{
            protocolVersion: "2025-03-26",
            clientInfo: %{name: "test", version: "1.0"},
            capabilities: %{}
          },
          id: "1"
        },
        %{
          jsonrpc: "2.0",
          method: "initialized"
        }
      ]

      body = JSON.encode!(batch)

      conn =
        json_post_conn("/mcp", body)
        |> with_origin("http://localhost")

      opts = StreamableHttp.init([])
      conn = StreamableHttp.call(conn, opts)

      assert conn.status == 200

      {:ok, responses} = JSON.decode(conn.resp_body)
      assert is_list(responses)
      assert length(responses) == 1  # Only the request should have a response
      assert hd(responses)["id"] == "1"
    end
  end
end

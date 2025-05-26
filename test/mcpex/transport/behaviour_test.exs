defmodule Mcpex.Transport.BehaviourTest do
  use ExUnit.Case, async: true

  alias Mcpex.Transport.Behaviour

  describe "parse_json_rpc_message/1" do
    test "parses valid JSON-RPC message" do
      json = ~s({"jsonrpc": "2.0", "method": "test", "id": "1"})

      assert {:ok, message} = Behaviour.parse_json_rpc_message(json)
      assert message.jsonrpc == "2.0"
      assert message.method == "test"
      assert message.id == "1"
    end

    test "returns error for invalid JSON" do
      assert {:error, {:parse_error, "Invalid JSON"}} = Behaviour.parse_json_rpc_message("invalid json")
    end
  end

  describe "encode_json_rpc_message/1" do
    test "encodes JSON-RPC message" do
      message = %{jsonrpc: "2.0", method: "test", id: "1"}

      assert {:ok, json} = Behaviour.encode_json_rpc_message(message)
      assert is_binary(json)

      # Verify it can be parsed back
      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["jsonrpc"] == "2.0"
      assert parsed["method"] == "test"
      assert parsed["id"] == "1"
    end
  end

  describe "validate_origin/2" do
    test "allows requests with no origin header" do
      conn = Plug.Test.conn(:get, "/")

      assert {:ok, ^conn} = Behaviour.validate_origin(conn)
    end

    test "allows requests from allowed origins" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("origin", "http://localhost:3000")

      assert {:ok, ^conn} = Behaviour.validate_origin(conn, ["http://localhost"])
    end

    test "rejects requests from disallowed origins" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("origin", "http://evil.com")

      assert {:error, :invalid_origin} = Behaviour.validate_origin(conn, ["http://localhost"])
    end

    test "rejects requests with multiple origin headers" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("origin", "http://localhost")
        |> Plug.Conn.put_req_header("origin", "http://evil.com")

      assert {:error, :invalid_origin} = Behaviour.validate_origin(conn)
    end
  end

  describe "generate_session_id/0" do
    test "generates unique session IDs" do
      id1 = Behaviour.generate_session_id()
      id2 = Behaviour.generate_session_id()

      assert is_binary(id1)
      assert is_binary(id2)
      assert id1 != id2
      assert String.length(id1) > 0
      assert String.length(id2) > 0
    end
  end

  describe "send_json_response/3" do
    test "sends JSON response with correct headers" do
      conn = Plug.Test.conn(:get, "/")
      data = %{message: "test"}

      conn = Behaviour.send_json_response(conn, 200, data)

      assert conn.status == 200
      assert conn.state == :sent
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

      {:ok, parsed} = Jason.decode(conn.resp_body)
      assert parsed["message"] == "test"
    end

    test "handles encoding errors gracefully" do
      conn = Plug.Test.conn(:get, "/")
      # Create data that can't be encoded to JSON
      data = %{pid: self()}

      conn = Behaviour.send_json_response(conn, 200, data)

      assert conn.status == 500
      assert conn.resp_body == ~s({"error": "Internal server error"})
    end
  end

  describe "send_sse_response/2" do
    test "sends SSE response with correct headers" do
      conn = Plug.Test.conn(:get, "/")
      data = "test data"

      conn = Behaviour.send_sse_response(conn, data)

      assert conn.status == 200
      assert conn.state == :sent
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/event-stream; charset=utf-8"]
      assert Plug.Conn.get_resp_header(conn, "cache-control") == ["no-cache"]
      assert Plug.Conn.get_resp_header(conn, "connection") == ["keep-alive"]
      assert conn.resp_body == "data: test data\n\n"
    end
  end
end

defmodule Mcpex.Protocol.JsonRpcTest do
  use ExUnit.Case, async: true
  doctest Mcpex.Protocol.JsonRpc

  alias Mcpex.Protocol.JsonRpc

  describe "request/3" do
    test "creates a valid request message" do
      request = JsonRpc.request("test_method", %{param1: "value1"}, "1")

      assert %{
               jsonrpc: "2.0",
               method: "test_method",
               params: %{param1: "value1"},
               id: "1"
             } = request
    end

    test "creates request without params when nil" do
      request = JsonRpc.request("test_method", nil, "1")

      assert %{
               jsonrpc: "2.0",
               method: "test_method",
               id: "1"
             } = request

      refute Map.has_key?(request, :params)
    end

    test "creates request with numeric id" do
      request = JsonRpc.request("test_method", nil, 42)

      assert %{
               jsonrpc: "2.0",
               method: "test_method",
               id: 42
             } = request
    end
  end

  describe "response/2" do
    test "creates a valid response message" do
      response = JsonRpc.response(%{success: true}, "1")

      assert %{
               jsonrpc: "2.0",
               result: %{success: true},
               id: "1"
             } = response
    end

    test "creates response with nil result" do
      response = JsonRpc.response(nil, "1")

      assert %{
               jsonrpc: "2.0",
               result: nil,
               id: "1"
             } = response
    end
  end

  describe "error_response/4" do
    test "creates a valid error response message" do
      error_response = JsonRpc.error_response(-32601, "Method not found", nil, "1")

      assert %{
               jsonrpc: "2.0",
               error: %{
                 code: -32601,
                 message: "Method not found"
               },
               id: "1"
             } = error_response
    end

    test "creates error response with data" do
      error_response =
        JsonRpc.error_response(-32602, "Invalid params", %{detail: "missing field"}, "1")

      assert %{
               jsonrpc: "2.0",
               error: %{
                 code: -32602,
                 message: "Invalid params",
                 data: %{detail: "missing field"}
               },
               id: "1"
             } = error_response
    end

    test "omits data when nil" do
      error_response = JsonRpc.error_response(-32603, "Internal error", nil, "1")

      assert %{
               jsonrpc: "2.0",
               error: %{
                 code: -32603,
                 message: "Internal error"
               },
               id: "1"
             } = error_response

      refute Map.has_key?(error_response.error, :data)
    end
  end

  describe "notification/2" do
    test "creates a valid notification message" do
      notification = JsonRpc.notification("test_notification", %{param1: "value1"})

      assert %{
               jsonrpc: "2.0",
               method: "test_notification",
               params: %{param1: "value1"}
             } = notification

      refute Map.has_key?(notification, :id)
    end

    test "creates notification without params when nil" do
      notification = JsonRpc.notification("test_notification", nil)

      assert %{
               jsonrpc: "2.0",
               method: "test_notification"
             } = notification

      refute Map.has_key?(notification, :params)
      refute Map.has_key?(notification, :id)
    end
  end

  describe "parse/1" do
    test "parses valid request" do
      json = ~s({"jsonrpc": "2.0", "method": "test", "params": {"a": 1}, "id": "1"})

      assert {:ok, message} = JsonRpc.parse(json)
      assert %{jsonrpc: "2.0", method: "test", params: %{"a" => 1}, id: "1"} = message
    end

    test "parses valid notification" do
      json = ~s({"jsonrpc": "2.0", "method": "test", "params": {"a": 1}})

      assert {:ok, message} = JsonRpc.parse(json)
      assert %{jsonrpc: "2.0", method: "test", params: %{"a" => 1}} = message
      refute Map.has_key?(message, :id)
    end

    test "parses valid response" do
      json = ~s({"jsonrpc": "2.0", "result": {"success": true}, "id": "1"})

      assert {:ok, message} = JsonRpc.parse(json)
      assert %{jsonrpc: "2.0", result: %{"success" => true}, id: "1"} = message
    end

    test "parses valid error response" do
      json =
        ~s({"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": "1"})

      assert {:ok, message} = JsonRpc.parse(json)

      assert %{jsonrpc: "2.0", error: %{code: -32601, message: "Method not found"}, id: "1"} =
               message
    end

    test "parses valid batch" do
      json =
        ~s([{"jsonrpc": "2.0", "method": "test1", "id": "1"}, {"jsonrpc": "2.0", "method": "test2", "id": "2"}])

      assert {:ok, messages} = JsonRpc.parse(json)

      assert [
               %{jsonrpc: "2.0", method: "test1", id: "1"},
               %{jsonrpc: "2.0", method: "test2", id: "2"}
             ] = messages
    end

    test "rejects invalid JSON" do
      assert {:error, {:parse_error, "Invalid JSON"}} = JsonRpc.parse("invalid json")
    end

    test "rejects missing jsonrpc version" do
      json = ~s({"method": "test", "id": "1"})

      assert {:error, {:invalid_request, "Missing jsonrpc version 2.0"}} = JsonRpc.parse(json)
    end

    test "rejects wrong jsonrpc version" do
      json = ~s({"jsonrpc": "1.0", "method": "test", "id": "1"})

      assert {:error, {:invalid_request, "Missing jsonrpc version 2.0"}} = JsonRpc.parse(json)
    end

    test "rejects empty batch" do
      json = "[]"

      assert {:error, {:invalid_request, "Batch cannot be empty"}} = JsonRpc.parse(json)
    end

    test "rejects response with both result and error" do
      json =
        ~s({"jsonrpc": "2.0", "result": true, "error": {"code": -1, "message": "test"}, "id": "1"})

      assert {:error, {:invalid_request, "Response cannot have both result and error"}} =
               JsonRpc.parse(json)
    end

    test "rejects malformed error object" do
      json = ~s({"jsonrpc": "2.0", "error": {"code": "not_number"}, "id": "1"})

      assert {:error, {:invalid_request, "Invalid error object"}} = JsonRpc.parse(json)
    end
  end

  describe "encode/1" do
    test "encodes request message" do
      message = %{jsonrpc: "2.0", method: "test", params: %{a: 1}, id: "1"}

      assert {:ok, json} = JsonRpc.encode(message)
      assert is_binary(json)

      # Verify it can be parsed back
      assert {:ok, parsed} = JSON.decode(json)
      assert parsed["jsonrpc"] == "2.0"
      assert parsed["method"] == "test"
      assert parsed["id"] == "1"
    end

    test "encodes batch message" do
      messages = [
        %{jsonrpc: "2.0", method: "test1", id: "1"},
        %{jsonrpc: "2.0", method: "test2", id: "2"}
      ]

      assert {:ok, json} = JsonRpc.encode(messages)
      assert is_binary(json)

      # Verify it can be parsed back
      assert {:ok, parsed} = JSON.decode(json)
      assert is_list(parsed)
      assert length(parsed) == 2
    end
  end

  describe "message type checks" do
    test "request?/1 identifies requests correctly" do
      request = %{jsonrpc: "2.0", method: "test", id: "1"}
      notification = %{jsonrpc: "2.0", method: "test"}
      response = %{jsonrpc: "2.0", result: true, id: "1"}

      assert JsonRpc.request?(request)
      refute JsonRpc.request?(notification)
      refute JsonRpc.request?(response)
    end

    test "notification?/1 identifies notifications correctly" do
      request = %{jsonrpc: "2.0", method: "test", id: "1"}
      notification = %{jsonrpc: "2.0", method: "test"}
      response = %{jsonrpc: "2.0", result: true, id: "1"}

      refute JsonRpc.notification?(request)
      assert JsonRpc.notification?(notification)
      refute JsonRpc.notification?(response)
    end

    test "response?/1 identifies responses correctly" do
      request = %{jsonrpc: "2.0", method: "test", id: "1"}
      notification = %{jsonrpc: "2.0", method: "test"}
      response = %{jsonrpc: "2.0", result: true, id: "1"}
      error_response = %{jsonrpc: "2.0", error: %{code: -1, message: "test"}, id: "1"}

      refute JsonRpc.response?(request)
      refute JsonRpc.response?(notification)
      assert JsonRpc.response?(response)
      assert JsonRpc.response?(error_response)
    end
  end

  describe "utility functions" do
    test "get_id/1 extracts id correctly" do
      message_with_id = %{jsonrpc: "2.0", method: "test", id: "1"}
      message_without_id = %{jsonrpc: "2.0", method: "test"}

      assert JsonRpc.get_id(message_with_id) == "1"
      assert JsonRpc.get_id(message_without_id) == nil
    end

    test "get_method/1 extracts method correctly" do
      message_with_method = %{jsonrpc: "2.0", method: "test", id: "1"}
      response = %{jsonrpc: "2.0", result: true, id: "1"}

      assert JsonRpc.get_method(message_with_method) == "test"
      assert JsonRpc.get_method(response) == nil
    end
  end
end

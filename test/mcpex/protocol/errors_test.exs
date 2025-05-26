defmodule Mcpex.Protocol.ErrorsTest do
  use ExUnit.Case, async: true

  alias Mcpex.Protocol.Errors

  describe "error codes" do
    test "returns correct standard error codes" do
      assert Errors.parse_error() == -32700
      assert Errors.invalid_request() == -32600
      assert Errors.method_not_found() == -32601
      assert Errors.invalid_params() == -32602
      assert Errors.internal_error() == -32603
    end
  end

  describe "error_message/1" do
    test "returns correct standard error messages" do
      assert Errors.error_message(-32700) == "Parse error"
      assert Errors.error_message(-32600) == "Invalid Request"
      assert Errors.error_message(-32601) == "Method not found"
      assert Errors.error_message(-32602) == "Invalid params"
      assert Errors.error_message(-32603) == "Internal error"
    end

    test "returns unknown error for non-standard codes" do
      assert Errors.error_message(-1) == "Unknown error"
      assert Errors.error_message(42) == "Unknown error"
    end
  end

  describe "create_error/3" do
    test "creates error from atom codes" do
      assert {-32700, "Parse error", nil} = Errors.create_error(:parse_error)
      assert {-32600, "Invalid Request", nil} = Errors.create_error(:invalid_request)
      assert {-32601, "Method not found", nil} = Errors.create_error(:method_not_found)
      assert {-32602, "Invalid params", nil} = Errors.create_error(:invalid_params)
      assert {-32603, "Internal error", nil} = Errors.create_error(:internal_error)
    end

    test "creates error with custom message" do
      assert {-32601, "Custom message", nil} = Errors.create_error(:method_not_found, "Custom message")
    end

    test "creates error with custom message and data" do
      data = %{details: "more info"}
      assert {-32602, "Custom message", ^data} = Errors.create_error(:invalid_params, "Custom message", data)
    end

    test "creates error from integer code" do
      assert {-1000, "Custom error", nil} = Errors.create_error(-1000, "Custom error")
    end

    test "uses default message for integer codes when message is nil" do
      assert {-32601, "Method not found", nil} = Errors.create_error(-32601, nil)
      assert {-1000, "Unknown error", nil} = Errors.create_error(-1000, nil)
    end
  end

  describe "to_error_response/2" do
    test "creates error response without data" do
      error_tuple = {-32601, "Method not found", nil}
      response = Errors.to_error_response(error_tuple, "1")

      assert %{
               jsonrpc: "2.0",
               error: %{
                 code: -32601,
                 message: "Method not found"
               },
               id: "1"
             } = response

      refute Map.has_key?(response.error, :data)
    end

    test "creates error response with data" do
      error_tuple = {-32602, "Invalid params", %{missing: "field"}}
      response = Errors.to_error_response(error_tuple, "1")

      assert %{
               jsonrpc: "2.0",
               error: %{
                 code: -32602,
                 message: "Invalid params",
                 data: %{missing: "field"}
               },
               id: "1"
             } = response
    end

    test "works with nil id" do
      error_tuple = {-32603, "Internal error", nil}
      response = Errors.to_error_response(error_tuple, nil)

      assert %{
               jsonrpc: "2.0",
               error: %{
                 code: -32603,
                 message: "Internal error"
               },
               id: nil
             } = response
    end
  end

  describe "normalize_error/1" do
    test "normalizes standard error tuples" do
      assert {-32700, "Custom parse error", nil} = Errors.normalize_error({:parse_error, "Custom parse error"})
      assert {-32600, "Custom invalid request", nil} = Errors.normalize_error({:invalid_request, "Custom invalid request"})
      assert {-32601, "Custom method not found", nil} = Errors.normalize_error({:method_not_found, "Custom method not found"})
      assert {-32602, "Custom invalid params", nil} = Errors.normalize_error({:invalid_params, "Custom invalid params"})
      assert {-32603, "Custom internal error", nil} = Errors.normalize_error({:internal_error, "Custom internal error"})
    end

    test "normalizes integer error tuples" do
      assert {-1000, "Custom error", nil} = Errors.normalize_error({-1000, "Custom error", nil})
      assert {-1000, "Custom error", nil} = Errors.normalize_error({-1000, "Custom error"})
    end

    test "normalizes string errors" do
      assert {-32603, "Something went wrong", nil} = Errors.normalize_error("Something went wrong")
    end

    test "normalizes unknown errors" do
      assert {-32603, "Unknown error", nil} = Errors.normalize_error(:unknown)
      assert {-32603, "Unknown error", nil} = Errors.normalize_error(%{some: "data"})
      assert {-32603, "Unknown error", nil} = Errors.normalize_error(42)
    end
  end
end

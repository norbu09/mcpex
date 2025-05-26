defmodule Mcpex.Protocol.Errors do
  @moduledoc """
  Error codes and error handling for JSON-RPC 2.0 and MCP-specific errors.

  This module defines standard JSON-RPC 2.0 error codes as specified in the
  JSON-RPC 2.0 specification, as well as MCP-specific error codes.
  """

  @doc """
  Standard JSON-RPC 2.0 error codes.
  """
  @spec parse_error() :: {integer(), String.t(), nil}
  def parse_error, do: {-32700, "Parse error", nil}

  @spec invalid_request() :: {integer(), String.t(), nil}
  def invalid_request, do: {-32600, "Invalid Request", nil}

  @spec method_not_found() :: {integer(), String.t(), nil}
  def method_not_found, do: {-32601, "Method not found", nil}
  
  @spec server_not_initialized() :: {integer(), String.t(), nil}
  def server_not_initialized, do: {-32002, "Server not initialized", nil}

  @spec invalid_params() :: {integer(), String.t(), nil}
  def invalid_params, do: {-32602, "Invalid params", nil}
  
  @spec invalid_params(String.t()) :: {integer(), String.t(), nil}
  def invalid_params(message), do: {-32602, message, nil}

  @spec internal_error() :: {integer(), String.t(), nil}
  def internal_error, do: {-32603, "Internal error", nil}
  
  @spec internal_error(String.t()) :: {integer(), String.t(), nil}
  def internal_error(message), do: {-32603, message, nil}

  @doc """
  Get the standard error message for a JSON-RPC error code.
  """
  @spec error_message(integer()) :: String.t()
  def error_message(-32700), do: "Parse error"
  def error_message(-32600), do: "Invalid Request"
  def error_message(-32601), do: "Method not found"
  def error_message(-32602), do: "Invalid params"
  def error_message(-32603), do: "Internal error"
  def error_message(_), do: "Unknown error"

  @doc """
  Creates a standardized error tuple for use in error responses.
  """
  @spec create_error(atom() | integer(), String.t() | nil, any()) :: {integer(), String.t(), any()}
  def create_error(code, message \\ nil, data \\ nil)

  def create_error(:parse_error, message, data) do
    {-32700, message || "Parse error", data}
  end

  def create_error(:invalid_request, message, data) do
    {-32600, message || "Invalid Request", data}
  end

  def create_error(:method_not_found, message, data) do
    {-32601, message || "Method not found", data}
  end

  def create_error(:invalid_params, message, data) do
    {-32602, message || "Invalid params", data}
  end

  def create_error(:internal_error, message, data) do
    {-32603, message || "Internal error", data}
  end

  def create_error(code, message, data) when is_integer(code) do
    {code, message || error_message(code), data}
  end

  @doc """
  Creates a JSON-RPC error response from an error tuple.
  """
  @spec to_error_response({integer(), String.t(), any()}, any()) :: map()
  def to_error_response({code, message, data}, id) do
    error = %{
      code: code,
      message: message
    }

    error = if data != nil, do: Map.put(error, :data, data), else: error

    %{
      jsonrpc: "2.0",
      error: error,
      id: id
    }
  end

  @doc """
  Converts various error formats to a standardized error tuple.
  """
  @spec normalize_error(any()) :: {integer(), String.t(), any()}
  def normalize_error({:parse_error, message}), do: {-32700, message, nil}
  def normalize_error({:invalid_request, message}), do: {-32600, message, nil}
  def normalize_error({:method_not_found, message}), do: {-32601, message, nil}
  def normalize_error({:invalid_params, message}), do: {-32602, message, nil}
  def normalize_error({:internal_error, message}), do: {-32603, message, nil}
  def normalize_error({code, message, data}) when is_integer(code), do: {code, message, data}
  def normalize_error({code, message}) when is_integer(code), do: {code, message, nil}
  def normalize_error(message) when is_binary(message), do: {-32603, message, nil}
  def normalize_error(_), do: {-32603, "Unknown error", nil}
end

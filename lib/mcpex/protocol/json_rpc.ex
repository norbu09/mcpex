defmodule Mcpex.Protocol.JsonRpc do
  @moduledoc """
  JSON-RPC 2.0 implementation for the Model Context Protocol.

  This module handles parsing, generating, and validating JSON-RPC 2.0 messages
  as required by the MCP specification. It supports:

  - Request messages
  - Response messages (success and error)
  - Notification messages
  - Batch messages
  - Request/response correlation
  """

  @jsonrpc_version "2.0"

  @type id :: String.t() | number() | nil
  @type method :: String.t()
  @type params :: map() | list() | nil
  @type result :: any()
  @type error_data :: any()

  @type request :: %{
          jsonrpc: String.t(),
          method: method(),
          params: params(),
          id: id()
        }

  @type response :: %{
          jsonrpc: String.t(),
          result: result(),
          id: id()
        }

  @type error_response :: %{
          jsonrpc: String.t(),
          error: %{
            code: integer(),
            message: String.t(),
            data: error_data()
          },
          id: id()
        }

  @type notification :: %{
          jsonrpc: String.t(),
          method: method(),
          params: params()
        }

  @type message :: request() | response() | error_response() | notification()

  @doc """
  Creates a JSON-RPC 2.0 request message.

  ## Examples

      iex> Mcpex.Protocol.JsonRpc.request("initialize", %{clientInfo: %{name: "test"}}, "1")
      %{
        jsonrpc: "2.0",
        method: "initialize",
        params: %{clientInfo: %{name: "test"}},
        id: "1"
      }
  """
  @spec request(method(), params(), id()) :: request()
  def request(method, params \\ nil, id) when is_binary(method) do
    %{
      jsonrpc: @jsonrpc_version,
      method: method,
      params: params,
      id: id
    }
    |> remove_nil_values()
  end

  @doc """
  Creates a JSON-RPC 2.0 success response message.

  ## Examples

      iex> Mcpex.Protocol.JsonRpc.response(%{protocolVersion: "2025-03-26"}, "1")
      %{
        jsonrpc: "2.0",
        result: %{protocolVersion: "2025-03-26"},
        id: "1"
      }
  """
  @spec response(result(), id()) :: response()
  def response(result, id) do
    %{
      jsonrpc: @jsonrpc_version,
      result: result,
      id: id
    }
  end

    @doc """
  Creates a JSON-RPC 2.0 error response message.

  ## Examples

      iex> Mcpex.Protocol.JsonRpc.error_response(-32601, "Method not found", nil, "1")
      %{
        jsonrpc: "2.0",
        error: %{
          code: -32601,
          message: "Method not found"
        },
        id: "1"
      }
  """
  @spec error_response(integer(), String.t(), error_data(), id()) :: error_response()
  def error_response(code, message, data \\ nil, id) do
    error = %{
      code: code,
      message: message,
      data: data
    } |> remove_nil_values()

    %{
      jsonrpc: @jsonrpc_version,
      error: error,
      id: id
    }
  end

  @doc """
  Creates a JSON-RPC 2.0 notification message.

  ## Examples

      iex> Mcpex.Protocol.JsonRpc.notification("initialized", %{})
      %{
        jsonrpc: "2.0",
        method: "initialized",
        params: %{}
      }
  """
  @spec notification(method(), params()) :: notification()
  def notification(method, params \\ nil) when is_binary(method) do
    %{
      jsonrpc: @jsonrpc_version,
      method: method,
      params: params
    }
    |> remove_nil_values()
  end

  @doc """
  Parses a JSON string into a JSON-RPC message or batch of messages.

  Returns `{:ok, message}` for valid JSON-RPC messages,
  `{:error, reason}` for invalid JSON or malformed messages.

  ## Examples

      iex> json = ~s({"jsonrpc": "2.0", "method": "test", "id": "1"})
      iex> Mcpex.Protocol.JsonRpc.parse(json)
      {:ok, %{jsonrpc: "2.0", method: "test", id: "1"}}

      iex> Mcpex.Protocol.JsonRpc.parse("invalid json")
      {:error, {:parse_error, "Invalid JSON"}}
  """
  @spec parse(String.t()) :: {:ok, message() | [message()]} | {:error, {atom(), String.t()}}
  def parse(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> validate_message(data)
      {:error, %Jason.DecodeError{}} -> {:error, {:parse_error, "Invalid JSON"}}
      {:error, _} -> {:error, {:parse_error, "Invalid JSON"}}
    end
  end

    @doc """
  Encodes a JSON-RPC message or batch of messages to a JSON string.

  ## Examples

      iex> message = %{jsonrpc: "2.0", method: "test", id: "1"}
      iex> {:ok, json} = Mcpex.Protocol.JsonRpc.encode(message)
      iex> String.contains?(json, ~s("jsonrpc":"2.0"))
      true
      iex> String.contains?(json, ~s("method":"test"))
      true
      iex> String.contains?(json, ~s("id":"1"))
      true
  """
  @spec encode(message() | [message()]) :: {:ok, String.t()} | {:error, {atom(), String.t()}}
  def encode(message) do
    case Jason.encode(message) do
      {:ok, json} -> {:ok, json}
      {:error, %Jason.EncodeError{}} -> {:error, {:internal_error, "Failed to encode message"}}
      {:error, _} -> {:error, {:internal_error, "Failed to encode message"}}
    end
  end

  @doc """
  Checks if a message is a request (has an id and method).
  """
  @spec request?(map()) :: boolean()
  def request?(%{method: method, id: id}) when is_binary(method) and not is_nil(id), do: true
  def request?(_), do: false

  @doc """
  Checks if a message is a notification (has method but no id).
  """
  @spec notification?(map()) :: boolean()
  def notification?(%{method: method} = msg) when is_binary(method) do
    not Map.has_key?(msg, :id)
  end
  def notification?(_), do: false

  @doc """
  Checks if a message is a response (has result or error, and id).
  """
  @spec response?(map()) :: boolean()
  def response?(%{id: id} = msg) when not is_nil(id) do
    Map.has_key?(msg, :result) or Map.has_key?(msg, :error)
  end
  def response?(_), do: false

  @doc """
  Extracts the ID from a JSON-RPC message.
  """
  @spec get_id(map()) :: id()
  def get_id(%{id: id}), do: id
  def get_id(_), do: nil

  @doc """
  Extracts the method from a JSON-RPC message.
  """
  @spec get_method(map()) :: method() | nil
  def get_method(%{method: method}), do: method
  def get_method(_), do: nil

  # Private functions

  defp validate_message(data) when is_list(data) do
    # Batch message
    if Enum.empty?(data) do
      {:error, {:invalid_request, "Batch cannot be empty"}}
    else
      case Enum.map(data, &validate_single_message/1) do
        results when is_list(results) ->
          errors = Enum.filter(results, &match?({:error, _}, &1))
          if Enum.empty?(errors) do
            messages = Enum.map(results, fn {:ok, msg} -> msg end)
            {:ok, messages}
          else
            {:error, {:invalid_request, "Invalid message in batch"}}
          end
      end
    end
  end

  defp validate_message(data) when is_map(data) do
    validate_single_message(data)
  end

  defp validate_message(_) do
    {:error, {:invalid_request, "Message must be an object or array"}}
  end

  defp validate_single_message(%{"jsonrpc" => "2.0"} = data) do
    # Convert string keys to atom keys
    message =
      try do
        for {key, val} <- data, into: %{} do
          {String.to_existing_atom(key), val}
        end
      rescue
        ArgumentError ->
          # Fallback: keep some keys as strings if atom doesn't exist
          for {key, val} <- data, into: %{} do
            try do
              {String.to_existing_atom(key), val}
            rescue
              ArgumentError -> {key, val}
            end
          end
      end

    cond do
      # Request: has method and id
      Map.has_key?(message, :method) and Map.has_key?(message, :id) ->
        if is_binary(message.method) do
          {:ok, message}
        else
          {:error, {:invalid_request, "Method must be a string"}}
        end

      # Notification: has method but no id
      Map.has_key?(message, :method) and not Map.has_key?(message, :id) ->
        if is_binary(message.method) do
          {:ok, message}
        else
          {:error, {:invalid_request, "Method must be a string"}}
        end

      # Response: has result or error, and id
      (Map.has_key?(message, :result) or Map.has_key?(message, :error)) and Map.has_key?(message, :id) ->
        cond do
          Map.has_key?(message, :result) and Map.has_key?(message, :error) ->
            {:error, {:invalid_request, "Response cannot have both result and error"}}

          Map.has_key?(message, :error) ->
            validate_error_object(message.error, message)

          true ->
            {:ok, message}
        end

      true ->
        {:error, {:invalid_request, "Invalid JSON-RPC message structure"}}
    end
  end

  defp validate_single_message(_) do
    {:error, {:invalid_request, "Missing jsonrpc version 2.0"}}
  end

  defp validate_error_object(error, message) when is_map(error) do
    # Handle both atom and string keys
    code = Map.get(error, :code) || Map.get(error, "code")
    msg = Map.get(error, :message) || Map.get(error, "message")

    if is_integer(code) and is_binary(msg) do
      # Convert to atom keys for consistency
      normalized_error = %{
        code: code,
        message: msg
      }

      # Add data if present
      normalized_error = case Map.get(error, :data) || Map.get(error, "data") do
        nil -> normalized_error
        data -> Map.put(normalized_error, :data, data)
      end

      {:ok, %{message | error: normalized_error}}
    else
      {:error, {:invalid_request, "Invalid error object"}}
    end
  end

  defp validate_error_object(_, _) do
    {:error, {:invalid_request, "Error must be an object"}}
  end

  defp remove_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end
end

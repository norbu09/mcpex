defmodule BasicMcpServer.TestHelpers do
  @moduledoc """
  Helper functions for testing the MCP server.
  """

  import ExUnit.Assertions

  @doc """
  Sends a JSON-RPC request to the server.
  """
  @spec send_request(pid() | port(), map(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def send_request(transport_pid, request, opts \\ []) do
    json = JSON.encode!(request)
    timeout = Keyword.get(opts, :timeout, 5_000)

    case transport_pid do
      port when is_port(port) ->
        # For direct port communication (e.g., in tests)
        :gen_tcp.send(
          port,
          "POST /mcp HTTP/1.1\r\nContent-Length: #{byte_size(json)}\r\n\r\n#{json}"
        )

        receive do
          {:tcp, ^port, data} ->
            [_headers, body] = String.split(data, "\r\n\r\n", parts: 2)
            JSON.decode(body)
        after
          timeout -> {:error, :timeout}
        end

      _ ->
        # For HTTP client communication
        headers = [{"content-type", "application/json"}]

        # Convert to charlists for :httpc compatibility
        url = String.to_charlist("http://localhost:4000/mcp")
        content_type = ~c"application/json"

        case :httpc.request(
               :post,
               {url, headers, content_type, json},
               [timeout: timeout, connect_timeout: timeout],
               []
             ) do
          {:ok, {{_, 200, _}, _headers, body}} ->
            JSON.decode(body)

          {:ok, {{_, status, _}, _headers, body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Creates a test initialization request.
  """
  @spec create_init_request(integer(), map()) :: map()
  def create_init_request(id, params \\ %{}) do
    default_params = %{
      "clientInfo" => %{
        "name" => "Test Client",
        "version" => "1.0.0"
      },
      "capabilities" => %{}
    }

    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "initialize",
      "params" => Map.merge(default_params, params)
    }
  end

  @doc """
  Asserts that a response is a valid JSON-RPC response.
  """
  @spec assert_jsonrpc_response(term()) :: map()
  def assert_jsonrpc_response({:ok, response}) when is_map(response) do
    assert Map.has_key?(response, "jsonrpc")
    assert response["jsonrpc"] == "2.0"
    assert Map.has_key?(response, "id") or Map.has_key?(response, "error")
    response
  end

  def assert_jsonrpc_response(other) do
    flunk("Expected {:ok, response}, got: #{inspect(other)}")
  end

  @doc """
  Asserts that a response is a valid JSON-RPC error response.
  """
  @spec assert_jsonrpc_error(term(), integer() | nil) :: map()
  def assert_jsonrpc_error({:ok, response}, code \\ nil) do
    response = assert_jsonrpc_response({:ok, response})
    assert is_map(response["error"])

    if code do
      assert response["error"]["code"] == code
    end

    response
  end
end

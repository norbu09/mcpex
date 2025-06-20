defmodule BasicMcpServer do
  @moduledoc """
  BasicMcpServer is a complete MCP (Model Context Protocol) server implementation
  built on top of the mcpex library.

  This module provides a demonstration server that implements all MCP capabilities:
  - Resources (file-based)
  - Prompts (templated)
  - Tools (calculator, time, random number)
  - Sampling (text generation)

  The server supports both SSE and Streamable HTTP transports.

  ## Usage

  To start the server:

      iex> {:ok, _pid} = BasicMcpServer.start_link()

  The server will start on ports 4000 (HTTP) and 4001 (SSE) by default.

  ## Example

      # Start the server
      {:ok, server} = BasicMcpServer.start_link(port: 8080, sse_port: 8081)

      # Process a message
      message = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "clientInfo" => %{"name" => "Test Client", "version" => "1.0.0"},
          "capabilities" => %{}
        }
      }

      {:ok, response} = BasicMcpServer.handle_message(message)
  """

  @doc """
  Starts the BasicMcpServer with the given options.

  ## Options

  - `:port` - The port for HTTP transport (default: 4000)
  - `:sse_port` - The port for SSE transport (default: 4001)
  - `:name` - The name to register the server under (default: `BasicMcpServer.Server`)

  ## Returns

  - `{:ok, pid}` - The PID of the server process
  - `{:error, reason}` - If the server failed to start

  ## Examples

      iex> {:ok, _pid} = BasicMcpServer.start_link()

      iex> {:ok, _pid} = BasicMcpServer.start_link(port: 8080, sse_port: 8081)
  """
  def start_link(opts \\ []) do
    BasicMcpServer.Server.start_link(opts)
  end

  @doc """
  Handles an incoming MCP message and returns the response.

  This function delegates to the underlying server implementation.

  ## Parameters

  - `message` - The MCP message as a map

  ## Returns

  - `{:ok, response}` - The response to send back to the client
  - `{:error, reason}` - If an error occurred

  ## Examples

      iex> message = %{
      ...>   "jsonrpc" => "2.0",
      ...>   "id" => 1,
      ...>   "method" => "initialize",
      ...>   "params" => %{
      ...>     "clientInfo" => %{"name" => "Test", "version" => "1.0.0"},
      ...>     "capabilities" => %{}
      ...>   }
      ...> }
      iex> {:ok, response} = BasicMcpServer.handle_message(message)
      iex> response["jsonrpc"]
      "2.0"
  """
  def handle_message(message) do
    BasicMcpServer.Server.handle_message(message)
  end

  @doc """
  Stops the BasicMcpServer.

  ## Parameters

  - `server` - The server process or name (default: `BasicMcpServer.Server`)

  ## Returns

  - `:ok`

  ## Examples

      iex> BasicMcpServer.stop()
      :ok
  """
  def stop(server \\ BasicMcpServer.Server) do
    BasicMcpServer.Server.stop(server)
  end
end

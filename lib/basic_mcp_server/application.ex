defmodule BasicMcpServer.Application do
  @moduledoc """
  This is the main application module for the Basic MCP Server.
  It sets up the supervision tree and starts the MCP server.

  The server is configured to run both SSE and Streamable HTTP transports
  on different ports to support a wide range of clients.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Get configuration from environment
    http_port = Application.get_env(:mcpex, :port, 4000)
    sse_port = Application.get_env(:mcpex, :sse_port, 4001)

    # Define the children to be supervised
    children = [
      # Start the MCP server
      # The server will register capabilities and start transports in its init/1 callback
      # Note: Mcpex.Registry is already started by the mcpex library
      {BasicMcpServer.Server, [port: http_port, sse_port: sse_port]}
    ]

    # Start the supervision tree
    opts = [strategy: :one_for_one, name: BasicMcpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

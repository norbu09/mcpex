#!/usr/bin/env elixir

# Test script to debug server startup
Mix.install([
  {:mcpex, path: "../mcpex"},
  {:basic_mcp_server, path: "."},
  {:plug_cowboy, ">= 2.0.0"},
  {:cors_plug, ">= 3.0.0"}
])

require Logger

Logger.info("Starting test server...")

try do
  # Test if the mcpex library works
  Logger.info("Testing mcpex library...")
  {:ok, mcpex_pid} = Mcpex.start_server(name: TestMcpexServer)
  Logger.info("Mcpex server started: #{inspect(mcpex_pid)}")

  # Test message processing
  Logger.info("Testing message processing...")
  init_message = %{
    "jsonrpc" => "2.0",
    "id" => 1,
    "method" => "initialize",
    "params" => %{
      "clientInfo" => %{"name" => "Test", "version" => "1.0.0"},
      "capabilities" => %{}
    }
  }

  case Mcpex.Server.process_message(TestMcpexServer, init_message, "test-session") do
    {:ok, response} ->
      Logger.info("Message processed successfully: #{inspect(response)}")
    {:error, reason} ->
      Logger.error("Message processing failed: #{inspect(reason)}")
  end

  # Test BasicMcpServer
  Logger.info("Testing BasicMcpServer...")
  {:ok, server_pid} = BasicMcpServer.start_link(port: 4040, sse_port: 4041)
  Logger.info("BasicMcpServer started: #{inspect(server_pid)}")

  Logger.info("Test completed successfully!")

rescue
  exception ->
    Logger.error("Test failed: #{inspect(exception)}")
    Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
end

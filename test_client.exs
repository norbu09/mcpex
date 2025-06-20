#!/usr/bin/env elixir

# Simple test client to reproduce the issue
Mix.install([
  {:req, "~> 0.4"}
])

# Test the streamable HTTP transport
test_message = %{
  jsonrpc: "2.0",
  method: "initialize",
  id: "test-1",
  params: %{
    protocolVersion: "2025-03-26",
    clientInfo: %{
      name: "test-client",
      version: "1.0.0"
    },
    capabilities: %{}
  }
}

IO.puts("Testing MCP server...")
IO.puts("Sending message: #{inspect(test_message)}")

json_body = JSON.encode!(test_message)
IO.puts("JSON body: #{json_body}")
IO.puts("JSON body length: #{byte_size(json_body)}")

response = Req.post!(
  "http://127.0.0.1:4000/mcp",
  headers: [
    {"content-type", "application/json"}
  ],
  body: json_body
)

IO.puts("Response status: #{response.status}")
IO.puts("Response headers: #{inspect(response.headers)}")
IO.puts("Response body: #{inspect(response.body)}")

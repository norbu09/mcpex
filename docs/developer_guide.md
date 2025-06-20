# Mcpex Developer Guide

## Introduction

Mcpex is an Elixir implementation of the Model Context Protocol (MCP), designed to provide a standardized way for AI models to interact with external tools, resources, and capabilities. This guide is intended for developers who want to:

1. Implement MCP servers using the mcpex library
2. Extend the mcpex library with new capabilities
3. Understand the internal architecture of mcpex

## Getting Started

### Prerequisites

- Elixir 1.18+
- Erlang/OTP 27+
- Mix build tool

### Installation

Add mcpex to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mcpex, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Implementing an MCP Server

### Basic Server Setup

The simplest way to create an MCP server is to use the provided convenience functions:

```elixir
defmodule MyApp do
  def start do
    # Start the MCP server with default capabilities
    {:ok, server} = Mcpex.start_with_default_capabilities()
    
    # Start a transport layer (e.g., SSE)
    {:ok, transport} = Mcpex.Transport.SSE.start_link(port: 4000)
    
    {:ok, %{server: server, transport: transport}}
  end
end
```

This will start an MCP server with the default capabilities (resources, prompts, tools, and sampling) and expose it via Server-Sent Events (SSE) on port 4000.

### Custom Server Configuration

For more control over the server configuration, you can use the lower-level API:

```elixir
defmodule MyApp do
  def start do
    # Start the MCP server with custom configuration
    server_info = %{
      name: "my-mcp-server",
      version: "1.0.0"
    }
    
    {:ok, server} = Mcpex.start_server(
      name: MyMcpServer,
      server_info: server_info
    )
    
    # Register capabilities
    Mcpex.register_capability(:resources, Mcpex.Capabilities.Resources)
    Mcpex.register_capability(:prompts, Mcpex.Capabilities.Prompts)
    Mcpex.register_capability(:tools, MyApp.CustomTools, %{
      tools: [
        %{
          "name" => "my-tool",
          "description" => "A custom tool"
        }
      ]
    })
    
    # Start a transport layer (e.g., Streamable HTTP)
    {:ok, transport} = Mcpex.Transport.StreamableHttp.start_link(port: 4001)
    
    {:ok, %{server: server, transport: transport}}
  end
end
```

### Transport Layers

Mcpex supports multiple transport layers:

1. **Server-Sent Events (SSE)**: The legacy transport from protocol version 2024-11-05
2. **Streamable HTTP**: The modern transport that supports bidirectional streaming

Choose the transport layer that best fits your needs. You can even run multiple transport layers simultaneously to support different clients.

## Implementing Custom Capabilities

### Capability Behaviour

All capabilities must implement the `Mcpex.Capabilities.Behaviour` behaviour, which defines the following callbacks:

```elixir
@callback supports?(client_capabilities :: map()) :: boolean()
@callback get_server_capabilities(config :: map()) :: map()
@callback handle_request(method :: String.t(), params :: map(), session_id :: String.t()) ::
            {:ok, map()} | {:error, map()}
```

### Example: Custom Tools Capability

Here's an example of a custom tools capability:

```elixir
defmodule MyApp.CustomTools do
  @behaviour Mcpex.Capabilities.Behaviour
  
  require Logger
  alias Mcpex.Protocol.Errors
  
  @impl true
  def supports?(_client_capabilities) do
    true
  end
  
  @impl true
  def get_server_capabilities(config) do
    %{
      "supportsProgress" => true,
      "supportsSubscriptions" => true
    }
  end
  
  @impl true
  def handle_request(method, params, session_id) do
    case method do
      "tools/list" -> handle_list(params, session_id)
      "tools/execute" -> handle_execute(params, session_id)
      _ -> {:error, Errors.method_not_found()}
    end
  end
  
  defp handle_list(_params, _session_id) do
    tools = [
      %{
        "name" => "my-tool",
        "description" => "A custom tool"
      }
    ]
    
    {:ok, %{"tools" => tools}}
  end
  
  defp handle_execute(params, session_id) do
    name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})
    
    if name == "my-tool" do
      # Execute the tool
      {:ok, %{
        "executionId" => "exec-#{:erlang.system_time(:millisecond)}",
        "content" => [
          %{
            "type" => "text",
            "text" => "Tool executed with arguments: #{inspect(arguments)}"
          }
        ]
      }}
    else
      {:error, Errors.invalid_params("Unknown tool: #{name}")}
    end
  end
end
```

### Registering Custom Capabilities

Register your custom capability with the MCP server:

```elixir
Mcpex.register_capability(:tools, MyApp.CustomTools, %{
  tools: [
    %{
      "name" => "my-tool",
      "description" => "A custom tool"
    }
  ]
})
```

## Advanced Topics

### Session Management

MCP sessions are managed by the server and identified by a unique session ID. The session ID is used to track the state of the client and ensure that requests are properly routed.

Sessions must be initialized before they can be used. The initialization process involves:

1. Client sends an `initialize` request with client info and capabilities
2. Server responds with server info and supported capabilities
3. Server marks the session as initialized

After initialization, the client can send requests to the server using the session ID.

### Capability Negotiation

During initialization, the server and client negotiate which capabilities are supported. The server advertises its capabilities, and the client can choose which ones to use.

The negotiation process involves:

1. Client sends its supported capabilities in the `initialize` request
2. Server checks which capabilities it supports based on the client capabilities
3. Server responds with its supported capabilities

### Error Handling

MCP uses JSON-RPC error codes for error handling. The main error codes are:

- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error
- `-32002`: Server not initialized

Custom error codes can be defined for specific capabilities.

## Testing

### Unit Testing

Mcpex provides utilities for unit testing capabilities:

```elixir
defmodule MyApp.CustomToolsTest do
  use ExUnit.Case
  
  test "lists tools" do
    result = MyApp.CustomTools.handle_request("tools/list", %{}, "test-session")
    
    assert {:ok, %{"tools" => tools}} = result
    assert length(tools) == 1
    assert Enum.at(tools, 0)["name"] == "my-tool"
  end
end
```

### Integration Testing

For integration testing, you can start a test server and send requests to it:

```elixir
defmodule MyApp.IntegrationTest do
  use ExUnit.Case
  
  setup do
    {:ok, server} = Mcpex.start_with_default_capabilities(name: TestServer)
    
    # Register custom capabilities
    Mcpex.register_capability(:tools, MyApp.CustomTools)
    
    %{server: server}
  end
  
  test "handles tools/list request", %{server: server} do
    request = %{
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: %{}
    }
    
    {:ok, response} = Mcpex.Server.process_message(server, request, "test-session")
    
    assert response.id == 1
    assert response.jsonrpc == "2.0"
    assert is_list(response.result["tools"])
  end
end
```

## Best Practices

### Performance Optimization

- Use connection pooling for external services
- Implement caching for frequently accessed resources
- Use asynchronous processing for long-running operations

### Security Considerations

- Validate all client input
- Implement rate limiting for API calls
- Use secure transport layers (HTTPS)
- Implement proper authentication and authorization

### Error Handling

- Provide meaningful error messages
- Log errors for debugging
- Handle edge cases gracefully

## Conclusion

This guide provides an overview of how to implement MCP servers using the mcpex library. For more detailed information, refer to the API documentation and example implementations.

## Additional Resources

- [MCP Specification](https://github.com/microsoft/machine-chat-protocol)
- [Mcpex API Documentation](https://hexdocs.pm/mcpex)
- [Example Implementations](https://github.com/norbu09/mcpex/tree/main/examples)

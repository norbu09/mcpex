# MCP Protocol Implementation Guide

## Introduction

This guide provides a comprehensive overview of the Model Context Protocol (MCP) implementation in the mcpex library. It covers the protocol details, capabilities, and how to implement and extend MCP servers.

## Protocol Overview

The Model Context Protocol (MCP) is a standardized protocol for communication between AI models and external systems. It allows models to access external tools, resources, and capabilities through a well-defined JSON-RPC based interface.

### Key Concepts

1. **Capabilities**: Functional areas that an MCP server can support (resources, prompts, tools, sampling)
2. **Sessions**: Client-server connections that maintain state
3. **Initialization**: Handshake process to establish capabilities and protocol version
4. **Requests & Responses**: JSON-RPC messages for communication
5. **Notifications**: Server-to-client messages for asynchronous updates

### Protocol Flow

1. **Initialization**: Client connects and sends an `initialize` request with its capabilities
2. **Capability Negotiation**: Server responds with supported capabilities
3. **Request Handling**: Client sends requests to access capabilities
4. **Notifications**: Server sends notifications for asynchronous updates
5. **Termination**: Client disconnects or session times out

## Core Capabilities

### Resources Capability

The resources capability allows clients to access external resources like files, documents, or other data sources.

**Methods**:
- `resources/list`: List available resources
- `resources/read`: Read resource contents
- `resources/subscribe`: Subscribe to resource changes
- `resources/unsubscribe`: Unsubscribe from resource changes

**Notifications**:
- `resources/changed`: Notify client of resource changes

### Prompts Capability

The prompts capability allows clients to access prompt templates for generating text.

**Methods**:
- `prompts/list`: List available prompts
- `prompts/get`: Get a specific prompt template
- `prompts/subscribe`: Subscribe to prompt changes
- `prompts/unsubscribe`: Unsubscribe from prompt changes

**Notifications**:
- `prompts/changed`: Notify client of prompt changes

### Tools Capability

The tools capability allows clients to execute external tools and receive results.

**Methods**:
- `tools/list`: List available tools
- `tools/execute`: Execute a tool
- `tools/cancel`: Cancel a tool execution
- `tools/subscribe`: Subscribe to tool changes
- `tools/unsubscribe`: Unsubscribe from tool changes

**Notifications**:
- `tools/progress`: Report progress of tool execution
- `tools/changed`: Notify client of tool changes

### Sampling Capability

The sampling capability allows clients to generate text using an LLM.

**Methods**:
- `sampling/generate`: Generate text
- `sampling/stream`: Stream text generation
- `sampling/cancel`: Cancel text generation

**Notifications**:
- `sampling/chunk`: Send a chunk of generated text

## Transport Layers

MCP supports multiple transport layers for communication between clients and servers:

### Server-Sent Events (SSE)

SSE is a one-way communication channel from server to client over HTTP. It's used for sending notifications to the client.

**Endpoints**:
- `POST /mcp`: Client-to-server requests
- `GET /mcp`: Server-to-client notifications (SSE)

### Streamable HTTP

Streamable HTTP allows for bidirectional streaming of data between client and server.

**Endpoints**:
- `POST /mcp`: Client-to-server requests with streaming responses

## Error Handling

MCP uses JSON-RPC error codes for error handling:

- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error
- `-32002`: Server not initialized

## Implementation Details

### Server Implementation

The MCP server is implemented as a GenServer that handles incoming requests and routes them to the appropriate capability handlers.

```elixir
defmodule Mcpex.Server do
  use GenServer
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def process_message(server, message, session_id \\ nil) do
    GenServer.call(server, {:process_message, message, session_id})
  end
  
  # ...
end
```

### Capability Registration

Capabilities are registered with the server through a central registry:

```elixir
defmodule Mcpex do
  def register_capability(capability_name, module, config \\ %{}) do
    Mcpex.Registry.register(capability_name, module, config)
  end
end
```

### Request Routing

Requests are routed to the appropriate capability handler based on the method name:

```elixir
defp route_request(%{method: method, id: id, params: params}, session_id, state) do
  {capability, _specific_method} = parse_method(method)
  
  case Mcpex.Registry.lookup(capability) do
    {:ok, {_pid, %{module: module}}} ->
      apply(module, :handle_request, [method, params, session_id])
    
    {:error, :not_found} ->
      {:error, Errors.method_not_found()}
  end
end
```

### Capability Implementation

Capabilities are implemented as modules that implement the `Mcpex.Capabilities.Behaviour` behaviour:

```elixir
defmodule Mcpex.Capabilities.Resources do
  @behaviour Mcpex.Capabilities.Behaviour
  
  @impl true
  def supports?(client_capabilities) do
    # Check if the client supports this capability
    true
  end
  
  @impl true
  def get_server_capabilities(config) do
    # Return the server capabilities
    %{
      "supportsSubscriptions" => true,
      "supportsFiltering" => true
    }
  end
  
  @impl true
  def handle_request(method, params, session_id) do
    # Handle the request
    case method do
      "resources/list" -> handle_list(params, session_id)
      # ...
    end
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

### Testing

- Write unit tests for each capability
- Write integration tests for the full protocol flow
- Test with real clients like mcpixir

## Extending the Protocol

### Adding a New Capability

To add a new capability:

1. Create a new module that implements the `Mcpex.Capabilities.Behaviour` behaviour
2. Implement the required callbacks
3. Register the capability with the server

### Adding a New Transport Layer

To add a new transport layer:

1. Create a new module that implements the transport interface
2. Implement the required functions
3. Start the transport server

## Conclusion

The Model Context Protocol provides a standardized way for AI models to interact with external systems. By implementing the protocol in Elixir, mcpex provides a robust, scalable, and extensible framework for building MCP servers.

For more detailed information, refer to the API documentation and example implementations.

## References

- [MCP Specification](https://github.com/microsoft/machine-chat-protocol)
- [Mcpex API Documentation](https://hexdocs.pm/mcpex)
- [Mcpixir Client](https://hexdocs.pm/mcpixir)

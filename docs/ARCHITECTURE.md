# Mcpex - Elixir MCP Server Implementation

## Overview

Mcpex is a generic Elixir library for implementing Model Context Protocol (MCP) servers. It provides a complete implementation of the MCP specification for remote interactions, supporting both SSE and Streamable HTTP transports.

## MCP Protocol Background

The Model Context Protocol enables AI assistants to securely access external data and tools. The protocol comes in multiple transport flavors:

1. **Local**: STDIO-based communication (not implemented in this library)
2. **Remote**: HTTP-based communication with two variants:
   - **SSE (Server-Sent Events)**: Legacy transport from protocol version 2024-11-05
   - **Streamable HTTP**: Current transport from protocol version 2025-03-26

Both remote transports use JSON-RPC 2.0 for message exchange and support core MCP capabilities:
- **Resources**: Provide data and content to clients
- **Prompts**: Template management for AI interactions  
- **Tools**: Executable functions clients can call
- **Sampling**: Optional LLM text generation capabilities

## System Architecture

### Core Components

#### 1. Protocol Layer
- JSON-RPC 2.0 message handling (requests, responses, notifications, errors)
- Message validation and schema enforcement
- Request/response correlation
- Error handling with proper MCP error codes

#### 2. Transport Layer
- **SSE Transport**: HTTP POST for client-to-server, SSE for server-to-client
- **Streamable HTTP Transport**: HTTP POST for client-to-server, optional SSE streams for server-to-client
- Session management with `Mcp-Session-Id` headers
- Connection lifecycle management

#### 3. Server Core
- Initialization handshake (`initialize` → `initialized`)
- Capability negotiation
- Request routing and handler registration
- Progress reporting for long-running operations

#### 4. MCP Features
- **Resources**: Provide data and content to clients
- **Prompts**: Template management for AI interactions  
- **Tools**: Executable functions clients can call
- **Sampling**: Optional LLM text generation capabilities

## Technology Stack

### Core Dependencies
```elixir
defp deps do
  [
    # HTTP server and client
    {:plug, "~> 1.15"},
    {:bandit, "~> 1.0"},
    {:req, "~> 0.4"},
    
    # JSON handling
    {:jason, "~> 1.4"},
    
    # Schema validation
    {:ex_json_schema, "~> 0.10"},
    
    # Server-Sent Events
    {:server_sent_event, "~> 1.0"},
    
    # UUID generation for sessions
    {:elixir_uuid, "~> 1.2"},
    
    # Development and testing
    {:ex_doc, "~> 0.31", only: :dev, runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:bypass, "~> 2.1", only: :test}
  ]
end
```

### Project Structure
```
lib/mcpex/
├── server.ex                    # Main server GenServer
├── protocol/
│   ├── json_rpc.ex             # JSON-RPC 2.0 implementation
│   ├── messages.ex             # MCP message schemas
│   └── errors.ex               # Error codes and handling
├── transport/
│   ├── behaviour.ex            # Transport behaviour
│   ├── sse.ex                  # SSE transport implementation
│   └── streamable_http.ex      # Streamable HTTP transport
├── capabilities/
│   ├── resources.ex            # Resource management
│   ├── prompts.ex              # Prompt templates
│   ├── tools.ex                # Tool execution
│   └── sampling.ex             # Optional LLM sampling
├── session/
│   ├── manager.ex              # Session lifecycle management
│   └── store.ex                # Session storage (ETS/GenServer)
└── handlers/
    ├── initialization.ex       # Initialization handshake
    ├── resources.ex            # Resource request handlers
    ├── prompts.ex              # Prompt request handlers
    └── tools.ex                # Tool request handlers
```

## API Design

### Server Configuration
```elixir
defmodule MyApp.MCPServer do
  use Mcpex.Server

  def init(_opts) do
    {:ok, %{
      name: "my-mcp-server",
      version: "1.0.0",
      capabilities: %{
        resources: %{},
        prompts: %{},
        tools: %{}
      }
    }}
  end

  # Resource handlers
  def handle_list_resources(_params, state) do
    resources = [
      %{uri: "file://example.txt", name: "Example File", mimeType: "text/plain"}
    ]
    {:ok, %{resources: resources}, state}
  end

  def handle_read_resource(%{uri: uri}, state) do
    case File.read(uri) do
      {:ok, content} -> 
        {:ok, %{contents: [%{uri: uri, text: content}]}, state}
      {:error, reason} -> 
        {:error, {:internal_error, "Failed to read file: #{reason}"}, state}
    end
  end

  # Tool handlers
  def handle_call_tool(%{name: "hello", arguments: args}, state) do
    name = Map.get(args, "name", "World")
    {:ok, %{content: [%{type: "text", text: "Hello, #{name}!"}]}, state}
  end
end
```

### Transport Startup
```elixir
# For SSE transport
{:ok, _pid} = Mcpex.Transport.SSE.start_link(
  handler: MyApp.MCPServer,
  port: 4000,
  path: "/mcp"
)

# For Streamable HTTP transport  
{:ok, _pid} = Mcpex.Transport.StreamableHTTP.start_link(
  handler: MyApp.MCPServer,
  port: 4000,
  path: "/mcp"
)
```

## Security Considerations

1. **Origin Validation**: Always validate `Origin` headers to prevent DNS rebinding attacks
2. **Authentication**: Support custom authentication mechanisms via plugs
3. **Local Binding**: Default to localhost binding for local development
4. **TLS Support**: Built-in HTTPS support for production deployments
5. **Rate Limiting**: Configurable rate limiting per client/session

## Testing Strategy

### Unit Tests
- JSON-RPC message parsing and generation
- Schema validation for all MCP message types
- Error handling and edge cases
- Session management lifecycle

### Integration Tests
- Full client-server communication flows
- Transport-specific behavior (SSE vs Streamable HTTP)
- Capability negotiation
- Long-running operations with progress reporting

### Interoperability Tests
We can test interoperability with existing MCP clients:

1. **Claude Desktop App**: Test local connections
2. **Official MCP SDKs**: Use TypeScript/Python clients for validation
3. **Postman**: Test HTTP endpoints directly
4. **Custom test clients**: Build simple Elixir clients for automated testing

### Test Client Implementation
```elixir
defmodule Mcpex.TestClient do
  @moduledoc "Simple MCP client for testing interoperability"
  
  def connect(url, transport \\ :streamable_http) do
    # Implementation for testing against our server
  end
  
  def initialize(client, capabilities \\ %{}) do
    # Send initialize request
  end
  
  def list_resources(client) do
    # Test resource listing
  end
end
```

## Development Phases

See [DEVELOPMENT_PLAN.md](./DEVELOPMENT_PLAN.md) for detailed implementation phases. 
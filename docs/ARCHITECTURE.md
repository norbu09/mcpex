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
  def handle_call(:resource_list, _params, state) do
    resources = [
      %{uri: "file://example.txt", name: "Example File", mimeType: "text/plain"}
    ]
    {:ok, %{resources: resources}, state}
  end

  def handle_call(:resource, %{uri: uri, type: :read}, state) do
    case File.read(uri) do
      {:ok, content} -> 
        {:ok, %{contents: [%{uri: uri, text: content}]}, state}
      {:error, reason} -> 
        {:error, {:internal_error, "Failed to read file: #{reason}"}, state}
    end
  end

  # Tool handlers
  def handle_call(:tool, %{name: "hello", arguments: args}, state) do
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

## Rate Limiting

### Overview

The MCPEX server implements rate limiting to protect against abuse and ensure fair usage of resources. Incoming MCP messages handled by the main `Mcpex.Router` are subject to rate limits based on the client's session ID and the type of operation being performed.

### Mechanism

Rate limiting is managed by the `Mcpex.RateLimiter.Server`, a GenServer that utilizes a strategy pattern based on the `Mcpex.RateLimiter.Behaviour`. The default strategy, `Mcpex.RateLimiter.ExRatedStrategy`, uses the `ExRated` library with an ETS backend to track request counts for different rules.

Each call to the `Mcpex.Router.handle_mcp_message/3` function first checks with the `Mcpex.RateLimiter.Server` to ensure the request is within the configured limits for its session ID and the requested MCP method (or a general category for it).

### Configuration

Rate limiting rules and settings are configured in your Elixir application's config files (e.g., `config/config.exs`, `config/prod.exs`). The configuration is provided under the `:mcpex` application, targeting the `Mcpex.RateLimiter.Server`.

Example configuration:

```elixir
# In config/config.exs
config :mcpex, Mcpex.RateLimiter.Server,
  # GenServer process name (optional, defaults to Mcpex.RateLimiter.Server)
  name: Mcpex.RateLimiter.Server, 
  
  # ETS table name used by ExRatedStrategy (optional, defaults to :mcpex_rate_limits_ets)
  table_name: :mcpex_custom_rate_limits_ets, 
  
  # GC interval for the ETS table (optional, defaults to 5 minutes)
  gc_interval: :timer.minutes(10),
  
  # Define rate limiting rules.
  # Each map in the list should conform to ExRated.Rule structure if using default strategy.
  rules: [
    %{
      id: :default_mcp_request,    # Rule ID used in the Router
      limit: 100,                  # Max requests allowed for this rule
      period: :timer.minutes(1),   # Time window in milliseconds (60,000 ms)
      strategy: ExRated.Strategy.FixedWindow # Or other ExRated strategies
    },
    %{
      id: :expensive_tool_call,    # A more restrictive rule for specific operations
      limit: 10,
      period: :timer.minutes(1),
      strategy: ExRated.Strategy.FixedWindow
    }
    # Add more rules as needed for different MCP methods or contexts.
  ]
```

The `Mcpex.Application` module loads this configuration when starting the `Mcpex.RateLimiter.Server`. If no configuration is provided, sensible defaults with a basic rule for `:default_mcp_request` are used (see `Mcpex.Application.start/2`).

### Error Response

When a client exceeds a configured rate limit, the `Mcpex.Router.handle_mcp_message/3` function will return a JSON-RPC error response. The specific error details are:

*   **Code**: `-32029`
*   **Message**: `"Too Many Requests"`
*   **Data**: An object containing:
    *   `message`: `"Too Many Requests. Rate limit exceeded."`
    *   `retryAfterSeconds`: An integer indicating when the client might be able to retry.
    *   `resetAt`: A Unix timestamp indicating when the limit window is expected to reset.

Example error payload snippet:
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32029,
    "message": "Too Many Requests",
    "data": {
      "message": "Too Many Requests. Rate limit exceeded.",
      "retryAfterSeconds": 35,
      "resetAt": 1678886435
    }
  },
  "id": "your-request-id" 
}
```
*(Note: The `id` in the response will match the `id` of the client's request if one was provided.)*

### Extensibility

The rate limiting system is designed to be extensible. To implement a new rate limiting strategy (e.g., using Redis, a different algorithm, or a third-party service):

1.  Create a new module that implements the `Mcpex.RateLimiter.Behaviour`.
2.  Update the configuration in `config/config.exs` to specify your new module as the `:strategy_module` for `Mcpex.RateLimiter.Server` and provide any necessary options for your new strategy.

```elixir
# Example: Using a hypothetical MyCustomStrategy
config :mcpex, Mcpex.RateLimiter.Server,
  strategy_module: Mcpex.RateLimiter.MyCustomStrategy,
  my_custom_options: [...] 
  # rules might be structured differently depending on MyCustomStrategy
```

This allows for significant flexibility in adapting the rate limiting approach as the application evolves.

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


# Mcpex Codebase Guide

## Introduction

This guide is intended for developers working on the mcpex codebase itself. It provides an overview of the codebase structure, architecture, and development workflow.

## Codebase Structure

The mcpex codebase is organized as follows:

```
mcpex/
├── lib/                  # Source code
│   ├── mcpex.ex          # Main API module
│   └── mcpex/            # Implementation modules
│       ├── application.ex        # OTP application
│       ├── capabilities/         # MCP capabilities
│       ├── handlers/             # Request handlers
│       ├── message_handler.ex    # Message handling
│       ├── protocol/             # Protocol implementation
│       ├── rate_limiter/         # Rate limiting
│       ├── registry.ex           # Capability registry
│       ├── router.ex             # Request routing
│       ├── server.ex             # MCP server
│       ├── session/              # Session management
│       └── transport/            # Transport layers
├── test/                 # Test files
│   ├── mcpex/            # Unit tests
│   ├── integration/      # Integration tests
│   └── test_helper.exs   # Test configuration
├── docs/                 # Documentation
├── examples/             # Example implementations
└── mix.exs              # Project configuration
```

## Core Components

### Main API (`mcpex.ex`)

The `Mcpex` module provides the main API for working with the MCP protocol. It includes functions for starting the server, registering capabilities, and listing capabilities.

### Server (`mcpex/server.ex`)

The `Mcpex.Server` module implements the core MCP server functionality. It handles:

- Initialization handshake
- Capability negotiation
- Request routing
- Handler registration

### Registry (`mcpex/registry.ex`)

The `Mcpex.Registry` module provides a central registry for MCP feature registration and discovery. It allows for a decoupled architecture where capabilities can be added without modifying the core server.

### Capabilities (`mcpex/capabilities/`)

The `Mcpex.Capabilities` namespace contains implementations of the various MCP capabilities:

- `Mcpex.Capabilities.Resources`: Resources capability
- `Mcpex.Capabilities.Prompts`: Prompts capability
- `Mcpex.Capabilities.Tools`: Tools capability
- `Mcpex.Capabilities.Sampling`: Sampling capability

All capabilities implement the `Mcpex.Capabilities.Behaviour` behaviour.

### Transport Layers (`mcpex/transport/`)

The `Mcpex.Transport` namespace contains implementations of the various transport layers:

- `Mcpex.Transport.SSE`: Server-Sent Events transport
- `Mcpex.Transport.StreamableHttp`: Streamable HTTP transport

### Protocol (`mcpex/protocol/`)

The `Mcpex.Protocol` namespace contains implementations of the MCP protocol:

- `Mcpex.Protocol.JsonRpc`: JSON-RPC implementation
- `Mcpex.Protocol.Errors`: Error handling
- `Mcpex.Protocol.Messages`: Message formatting

## Development Workflow

### Setting Up the Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/norbu09/mcpex.git
   cd mcpex
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Run tests:
   ```bash
   mix test
   ```

### Making Changes

1. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes to the codebase.

3. Run tests to ensure everything still works:
   ```bash
   mix test
   ```

4. Run the formatter to ensure consistent code style:
   ```bash
   mix format
   ```

5. Run static analysis tools:
   ```bash
   mix dialyzer
   mix credo
   ```

6. Commit your changes:
   ```bash
   git commit -am "Add your feature description"
   ```

7. Push your changes:
   ```bash
   git push origin feature/your-feature-name
   ```

8. Create a pull request on GitHub.

### Running the Example Server

To run the example MCP server:

```bash
cd examples/basic_server
mix deps.get
iex -S mix
```

This will start an MCP server on port 4000 with the default capabilities.

## Adding a New Capability

To add a new capability to mcpex:

1. Create a new module in `lib/mcpex/capabilities/` that implements the `Mcpex.Capabilities.Behaviour` behaviour.

2. Implement the required callbacks:
   - `supports?/1`: Determines if the capability is supported based on client capabilities
   - `get_server_capabilities/1`: Returns the server capabilities for this capability
   - `handle_request/3`: Handles requests for this capability

3. Add tests for the new capability in `test/mcpex/capabilities/`.

4. Update the `Mcpex.start_with_default_capabilities/1` function to include the new capability if it should be enabled by default.

## Adding a New Transport Layer

To add a new transport layer to mcpex:

1. Create a new module in `lib/mcpex/transport/` that implements the transport interface.

2. Implement the required functions:
   - `start_link/1`: Starts the transport server
   - `handle_request/1`: Handles incoming requests
   - `handle_notification/2`: Sends notifications to clients

3. Add tests for the new transport in `test/mcpex/transport/`.

## Testing

### Unit Tests

Unit tests are located in `test/mcpex/` and test individual components of the system. Run them with:

```bash
mix test
```

### Integration Tests

Integration tests are located in `test/mcpex/integration/` and test the system as a whole. Run them with:

```bash
mix test test/mcpex/integration
```

### External Client Tests

Tests that use external MCP clients (like mcpixir) are tagged with `:external` and can be excluded from the normal test run:

```bash
mix test --exclude external
```

To run only the external tests:

```bash
mix test --only external
```

## Documentation

### Generating Documentation

To generate the API documentation:

```bash
mix docs
```

This will generate HTML documentation in the `doc/` directory.

### Writing Documentation

- Use `@moduledoc` to document modules
- Use `@doc` to document functions
- Use `@typedoc` to document types
- Use `@spec` to specify function types

Example:

```elixir
@moduledoc """
This module implements the MCP server.
"""

@doc """
Starts the MCP server.

## Options

- `:name` - The name of the server (default: `Mcpex.Server`)
- `:server_info` - Information about the server (name, version, etc.)

## Returns

- `{:ok, pid}` - The PID of the server process
- `{:error, reason}` - If the server failed to start
"""
@spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
def start_link(opts \\ []) do
  # ...
end
```

## Performance Considerations

### Connection Pooling

When making external requests, use connection pooling to reduce overhead:

```elixir
defmodule Mcpex.HttpClient do
  use Tesla

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Timeout, timeout: 10_000

  adapter Tesla.Adapter.Hackney, pool: :mcpex_pool
end
```

### Asynchronous Processing

For long-running operations, use asynchronous processing to avoid blocking the server:

```elixir
def handle_request(method, params, session_id) do
  case method do
    "tools/execute" ->
      # Start async execution
      task = Task.async(fn -> execute_tool(params, session_id) end)
      
      # Return immediately with a task ID
      {:ok, %{"taskId" => task.ref |> inspect()}}
    
    # ...
  end
end
```

### Caching

Use caching for frequently accessed resources:

```elixir
def get_resource(uri) do
  case :ets.lookup(:resource_cache, uri) do
    [{^uri, content, timestamp}] ->
      # Check if cache is still valid (less than 5 minutes old)
      if :os.system_time(:second) - timestamp < 300 do
        {:ok, content}
      else
        # Cache expired, fetch fresh content
        fetch_and_cache_resource(uri)
      end
    
    [] ->
      # Not in cache, fetch and cache
      fetch_and_cache_resource(uri)
  end
end

defp fetch_and_cache_resource(uri) do
  case fetch_resource(uri) do
    {:ok, content} ->
      # Cache the content with current timestamp
      :ets.insert(:resource_cache, {uri, content, :os.system_time(:second)})
      {:ok, content}
    
    error ->
      error
  end
end
```

## Troubleshooting

### Common Issues

1. **Server not starting**: Check that the registry is properly started and that there are no port conflicts.

2. **Capability not registered**: Check that the capability is properly registered with the registry.

3. **Method not found**: Check that the method name is correct and that the capability is registered.

4. **Invalid params**: Check that the request parameters match the expected format.

### Debugging

To enable debug logging, set the log level in your `config/config.exs`:

```elixir
config :logger, level: :debug
```

For more detailed logging, you can use the `:trace` level:

```elixir
config :logger, level: :trace
```

## Conclusion

This guide provides an overview of the mcpex codebase and development workflow. For more detailed information, refer to the API documentation and the code itself.

## Additional Resources

- [Elixir Documentation](https://elixir-lang.org/docs.html)
- [Erlang Documentation](https://www.erlang.org/docs)
- [MCP Specification](https://github.com/microsoft/machine-chat-protocol)
- [Mcpex API Documentation](https://hexdocs.pm/mcpex)

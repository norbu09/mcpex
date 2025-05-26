# Phase 3 Implementation Plan: Server Core

## Overview

Phase 3 focuses on implementing the Server core of the MCP protocol, which includes:

1. Creating a central registry for feature registration
2. Implementing the main server GenServer
3. Implementing initialization handlers
4. Implementing the core capabilities (resources, prompts, tools)

## Implementation Details

### 1. Central Registry for Feature Registration

We will use Elixir's built-in Registry module to create a central registry for feature registration. This will allow:

- Dynamic registration of MCP capabilities at runtime
- Easy discovery of available features
- Decoupled architecture where capabilities can be added without modifying the core server

Implementation:
- Create a `Mcpex.Registry` module to manage the registry
- Define functions for registering and discovering capabilities
- Ensure the registry is started as part of the application supervision tree

### 2. Server Core Implementation

The server core will be implemented as a GenServer that:

- Handles the initialization handshake
- Manages capability negotiation
- Routes requests to appropriate handlers
- Manages the lifecycle of client connections

Implementation:
- Create `Mcpex.Server` module with GenServer behavior
- Implement request routing based on method names
- Support capability negotiation during initialization
- Provide a clean API for handler registration

### 3. Initialization Handlers

Initialization handlers will manage the initial handshake between client and server:

- Process `initialize` requests from clients
- Advertise available capabilities
- Negotiate protocol versions
- Send `initialized` notifications

Implementation:
- Create `Mcpex.Handlers.Initialization` module
- Implement handlers for initialization requests
- Support capability advertisement based on registered features

### 4. Core Capabilities Implementation

Implement the three core MCP capabilities:

#### Resources Capability
- Resource listing
- Resource reading
- Resource subscriptions
- Resource change notifications

#### Prompts Capability
- Prompt listing
- Prompt retrieval
- Argument handling
- Prompt change notifications

#### Tools Capability
- Tool listing
- Tool execution
- Progress reporting
- Tool change notifications

Each capability will be implemented as a separate module with a consistent interface for registration with the central registry.

## Testing Strategy

- Unit tests for each component
- Integration tests for the complete server flow
- Test capability registration and discovery
- Test initialization handshake
- Test request routing to appropriate handlers

## Success Criteria

- All three core capabilities are implemented
- Server can negotiate capabilities with clients
- Request routing works correctly
- Notifications are properly sent
- Registry successfully manages feature registration and discovery
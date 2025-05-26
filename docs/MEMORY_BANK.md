# Memory Bank - Mcpex Project

## Project Overview

**Goal**: Create a generic Elixir library for implementing Model Context Protocol (MCP) servers that can be open-sourced and used by other Elixir developers.

**Focus**: Remote MCP server implementation supporting both SSE and Streamable HTTP transports.

## Key Requirements

### Protocol Support
- **MCP Protocol Versions**: 
  - 2024-11-05 (SSE transport - legacy)
  - 2025-03-26 (Streamable HTTP transport - current)
- **Transport Types**: 
  - SSE (Server-Sent Events)
  - Streamable HTTP
- **Message Format**: JSON-RPC 2.0

### Core Capabilities
1. **Resources**: Provide data and content to clients
2. **Prompts**: Template management for AI interactions
3. **Tools**: Executable functions clients can call
4. **Sampling**: Optional LLM text generation capabilities

### Technical Requirements
- **Language**: Elixir (targeting ~> 1.18)
- **Architecture**: OTP-compliant GenServer-based design
- **Security**: Origin validation, TLS support, rate limiting
- **Testing**: Interoperability with existing MCP clients

## Key Decisions Made

### Transport Implementation Strategy
- Support both SSE (legacy) and Streamable HTTP (current) transports
- Use Plug + Bandit for HTTP server functionality
- Implement session management with `Mcp-Session-Id` headers
- Support resumable connections for Streamable HTTP

### Architecture Decisions
- **Behaviour-based design**: Common transport interface for extensibility
- **GenServer core**: Main server as supervised GenServer
- **Capability modules**: Separate modules for each MCP capability
- **Handler pattern**: Request routing through registered handlers

### Technology Stack Choices
- **HTTP**: Plug + Bandit (modern Elixir HTTP stack)
- **JSON**: Jason (standard Elixir JSON library)
- **Schema Validation**: ExJsonSchema
- **SSE**: server_sent_event library
- **Testing**: ExUnit + Bypass for HTTP mocking

### Security Approach
- Always validate Origin headers to prevent DNS rebinding
- Default to localhost binding for development
- Support custom authentication via Plug middleware
- Built-in TLS support for production

## Implementation Phases

### Phase 1: Core Foundation (✅ COMPLETED)
- ✅ JSON-RPC 2.0 implementation with full parsing/generation
- ✅ MCP-specific message schemas and validation
- ✅ Comprehensive error handling with standard JSON-RPC codes
- ✅ Extensive test suite (75 tests, all passing)
- ✅ Support for requests, responses, notifications, batch messages
- ✅ Message type detection and validation
- ✅ Test coverage > 90% for protocol layer

### Phase 2: Transport Layer (NEXT)
- SSE transport implementation
- Streamable HTTP transport implementation
- Session management
- Security features

### Phase 3: MCP Capabilities
- Resources, Prompts, Tools capabilities
- Server core with capability negotiation
- Request routing and handler registration

### Phase 4: Advanced Features
- Sampling capability
- Progress reporting
- Performance optimizations
- Documentation

### Phase 5: Production Readiness
- Monitoring and observability
- Production deployment
- Interoperability validation

## Critical Design Constraints

### MCP Specification Compliance
- Must follow JSON-RPC 2.0 exactly
- Must implement proper initialization handshake
- Must support capability negotiation
- Must handle all required MCP message types

### Elixir/OTP Best Practices
- Supervision tree design
- Graceful error handling
- Proper GenServer lifecycle
- Hot code reloading support

### Interoperability Requirements
- Must work with Claude Desktop App
- Must work with official MCP SDKs (TypeScript/Python)
- Must be testable with standard HTTP tools (Postman)

## Testing Strategy

### Unit Testing
- JSON-RPC message parsing/generation
- Schema validation
- Error handling
- Individual capability functions

### Integration Testing
- Full client-server communication
- Transport-specific behavior
- Multi-client scenarios
- Session management

### Interoperability Testing
- Test against Claude Desktop
- Test against official SDKs
- Cross-platform validation
- Protocol compliance verification

## Open Questions & Risks

### Technical Risks
1. **Protocol Complexity**: MCP specification is extensive with many edge cases
2. **Performance**: HTTP overhead for JSON-RPC message exchange
3. **Interoperability**: Ensuring compatibility with diverse client implementations

### Design Questions
1. **Configuration API**: How should users configure server capabilities?
2. **Error Handling**: How granular should error reporting be?
3. **Extensibility**: How to allow custom capabilities beyond MCP spec?

## Success Criteria

### Functional Success
- [ ] Implements both SSE and Streamable HTTP transports correctly
- [ ] Supports all core MCP capabilities (Resources, Prompts, Tools)
- [ ] Passes interoperability tests with major MCP clients
- [ ] Provides clean, intuitive API for Elixir developers

### Non-Functional Success
- [ ] Performance suitable for production use
- [ ] Comprehensive documentation and examples
- [ ] 90%+ test coverage
- [ ] Security best practices implemented

### Community Success
- [ ] Open source release with clear licensing
- [ ] Usage examples and getting started guide
- [ ] Integration with popular Elixir frameworks
- [ ] Community adoption and contributions

## Project Context Notes

### Source Analysis
- Analyzed comprehensive MCP documentation (~18,000 lines)
- Identified key transport patterns and message flows
- Reviewed security considerations and best practices
- Studied existing client implementations for reference

### Implementation Strategy
- Start with solid foundation (JSON-RPC, message schemas)
- Build incrementally with continuous testing
- Prioritize interoperability from day one
- Focus on clean, idiomatic Elixir API design

### Long-term Vision
- Become the standard MCP server implementation for Elixir
- Enable rich AI integrations in Elixir applications
- Contribute back to MCP specification development
- Foster Elixir community adoption of MCP protocol 
# Windsurf Agent Rules for MCPEX Project

## Project Context

MCPEX is an Elixir implementation of the Machine Chat Protocol (MCP). The project requires Elixir 1.18+ with Erlang/OTP 27 and follows standard Elixir development practices.

## Technical Guidelines

1. **Build System**:
   - Use `mix` as the build system
   - Run `mix compile` to compile the project
   - Ensure code compiles without warnings
   - Format code with `mix format`
   - Follow project coding standards (`mix credo`)

2. **Dependency Management**:
   - Use `">="` for library versions in `mix.exs`
   - Never pin dependencies to specific versions
   - Always use the latest versions of libraries when possible
   - Minimize external dependencies
   - Document any new dependencies in README.md

3. **JSON Handling**:
   - Always use the built-in `JSON` module for all JSON operations
   - Do not add Jason or other JSON libraries as dependencies
   - Refer to `docs/json_usage.md` for detailed guidelines

4. **Code Style**:
   - Use pattern matching instead of complex `with` statements
   - Handle errors explicitly with `:ok`/`:error` tuples
   - Fail fast and handle errors appropriately
   - Add proper logging with `Logger`
   - Prefer non-raising versions of library calls
   - Keep functions small and focused on a single responsibility
   - Follow Elixir best practices and idioms

## Workflow Guidelines

1. **Development Process**:
   - Start with small, simple solutions
   - Design at a high level before implementation
   - Document your implementation plan in `docs/`
   - Frequently ask for feedback and clarification
   - Use feature flags for new functionality with `:fun_with_flags`
   - Update documentation regularly

2. **Testing**:
   - Run tests with `mix test`
   - Create comprehensive test coverage
   - Write tests for all new functionality
   - Use `Mox` for mocking when appropriate
   - Ensure all tests pass before committing

3. **Documentation**:
   - Document with `@moduledoc`, `@doc`, `@spec`
   - Keep documentation up-to-date with code changes
   - Update README.md when adding significant features
   - Reference hexdocs.pm for Elixir documentation
   - Track progress and decisions in the docs/ folder

## Project-Specific Notes

1. **Error Handling**:
   - Ensure proper error handling with `{:error, reason}` tuples
   - Define clear error paths
   - Use proper logging with context

2. **Performance**:
   - Consider performance implications of changes
   - Use Elixir's concurrency features appropriately
   - Optimize critical paths when necessary

3. **Best Practices**:
   - Follow Elixir best practices and idioms
   - Write clean, maintainable, and efficient code
   - Keep the codebase consistent with existing patterns
   - Always read the entire docs/ folder before starting any task

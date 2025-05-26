# OpenHands Agent Rules for MCPEX Project

## Project Context

MCPEX is an Elixir implementation of the Machine Chat Protocol (MCP). The project requires Elixir 1.18+ with Erlang/OTP 27 and follows standard Elixir development practices.

## Technical Guidelines

1. **JSON Usage**:
   - Always use the built-in `JSON` module for all JSON operations
   - Do not add Jason or other JSON libraries as dependencies
   - Refer to `docs/json_usage.md` for detailed guidelines

2. **Elixir Best Practices**:
   - Use pattern matching instead of complex `with` statements
   - Handle errors explicitly with `:ok`/`:error` tuples
   - Fail fast and handle errors appropriately
   - Add proper logging with `Logger`
   - Prefer non-raising versions of library calls
   - Follow project coding standards (`mix format`, `mix credo`)

3. **Documentation**:
   - Document with `@moduledoc`, `@doc`, `@spec`
   - Keep documentation up-to-date with code changes
   - Update README.md when adding significant features
   - Always read the entire docs/ folder before starting any task
   - Track progress and decisions in the docs/ folder

4. **Testing**:
   - Write comprehensive ExUnit tests for all new functionality
   - Run tests with `mix test` before submitting changes
   - Use `Mox` for mocking when appropriate
   - Use Docker-based testing for consistent environments (see Docker Testing section below)

## Workflow Guidelines

1. **Development Process**:
   - Start with small, simple solutions
   - Design at a high level before implementation
   - Document your implementation plan in `docs/`
   - Frequently ask for feedback and clarification
   - Use feature flags for new functionality with `:fun_with_flags`
   - Update your implementation documentation regularly

2. **Git Workflow**:
   - Create meaningful branch names that describe changes
   - Make focused commits with clear messages
   - Reference issue numbers in commit messages and PRs
   - Follow the PR template when creating pull requests

3. **Code Review**:
   - Address all feedback from code reviews
   - Explain your reasoning for implementation choices
   - Be open to alternative approaches

## Communication Preferences

1. **Task Understanding**:
   - Clarify requirements before starting implementation
   - Ask specific questions when requirements are unclear
   - Provide multiple options when appropriate

2. **Progress Updates**:
   - Allcommunication is through Github Issues, PRs or by documenting them in the `docs/` folder
   - Provide clear summaries of completed work
   - Highlight any challenges or blockers
   - Suggest next steps based on current progress

3. **Technical Discussions**:
   - Use code examples to illustrate points
   - Reference Elixir documentation when relevant
   - Explain trade-offs between different approaches

## Project-Specific Notes

1. **Dependencies**:
   - Always use the latest libraries when possible
   - Minimize external dependencies
   - Document any new dependencies in README.md

2. **Error Handling**:
   - Ensure everything handles `{:error, reason}` appropriately
   - Define clear error paths
   - Use proper logging with context

3. **Performance**:
   - Consider performance implications of changes
   - Use Elixir's concurrency features appropriately
   - Optimize critical paths when necessary

## Docker Testing

1. **Building the Docker Image**:
   - Use `make docker-build` to build the Docker image
   - The image includes Elixir 1.18.4 with OTP 27 and all dependencies

2. **Running Tests in Docker**:
   - Use `make docker-test` to run the full test suite in Docker
   - For specific tests: `make docker-exec CMD='mix test path/to/test.exs:line_number'`
   - Example: `make docker-exec CMD='mix test test/mcpex/rate_limiter/genserver_test.exs:35'`

3. **Docker Environment**:
   - Provides consistent testing environment across all development machines
   - Isolates tests from host system dependencies
   - Ensures reproducible test results
   - Simplifies CI/CD integration

4. **Troubleshooting Docker**:
   - If Docker daemon isn't running: `dockerd > /tmp/docker.log 2>&1 &`
   - Check Docker logs: `cat /tmp/docker.log`
   - View Docker status: `docker ps`
   - Get a shell in the container: `make docker-shell`


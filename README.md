# Mcpex

MCPEX is an Elixir implementation of the Machine Chat Protocol (MCP).

## Development Setup

### Automated Setup

For a quick setup in the development VM, run:

```bash
./setup.sh
```

This script will:
1. Install Erlang and Elixir
2. Install Hex package manager and Rebar
3. Fetch project dependencies
4. Compile the project
5. Run tests to verify the setup

### Using the Makefile

The project includes a Makefile to simplify common development tasks:

```bash
# Setup development environment
make setup

# Get dependencies
make deps

# Compile the project
make compile

# Run tests
make test

# Run the application
make run

# Format code
make format

# Run static code analysis
make lint

# Generate documentation
make docs

# Docker tasks
make docker-build
make docker-run
make docker-stop

# Show all available commands
make help
```

### Manual Setup

If you prefer to set up manually:

1. Install Erlang and Elixir:
   ```bash
   apt-get update
   apt-get install -y elixir erlang-dev
   ```

2. Install Hex package manager and Rebar:
   ```bash
   mix local.hex --force
   mix local.rebar --force
   ```

3. Fetch dependencies:
   ```bash
   mix deps.get
   ```

4. Compile the project:
   ```bash
   mix compile
   ```

5. Run tests:
   ```bash
   mix test
   ```

## Running the Application

### Running Locally

To start the application locally:

```bash
mix run --no-halt
```

### Running with Docker

The project includes Docker configuration for easy containerized deployment:

1. Build and start the container:
   ```bash
   docker-compose up
   ```

2. Or build and run in detached mode:
   ```bash
   docker-compose up -d
   ```

3. To stop the container:
   ```bash
   docker-compose down
   ```

## Using as a Dependency

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mcpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mcpex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/mcpex>.


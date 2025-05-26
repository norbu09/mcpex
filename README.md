# Mcpex

MCPEX is an Elixir implementation of the Machine Chat Protocol (MCP).

## Development Setup

### Requirements

- Elixir 1.18.3 with Erlang/OTP 27
- The project includes a `.tool-versions` file for use with [asdf](https://asdf-vm.com/)

### Automated Setup

For a quick setup in the development VM, run:

```bash
./setup.sh
```

This script will:
1. Install asdf version manager
2. Install Erlang 27.0 and Elixir 1.18.3 using asdf (note: Erlang compilation may take 10-20 minutes)
3. Install Hex package manager and Rebar
4. Fetch project dependencies
5. Compile the project
6. Run tests to verify the setup

> **Note:** Erlang compilation can take a significant amount of time (10-20 minutes) as it builds from source. You can monitor the progress in another terminal with:
> ```bash
> tail -f ~/.asdf/plugins/erlang/kerl-home/builds/asdf_*/otp_build*.log
> ```

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

1. Install asdf version manager:
   ```bash
   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
   echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
   echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
   source ~/.asdf/asdf.sh
   ```

2. Install Erlang and Elixir using asdf:
   ```bash
   # Install required dependencies for building Erlang
   apt-get update
   apt-get install -y build-essential autoconf m4 libncurses5-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-17-jdk
   
   # Install asdf plugins
   asdf plugin add erlang
   asdf plugin add elixir
   
   # Install versions from .tool-versions file
   asdf install
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


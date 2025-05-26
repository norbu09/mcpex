#!/bin/bash
set -e

echo "Setting up MCPEX development environment..."

# Check if Docker is installed
if command -v docker >/dev/null 2>&1; then
  echo "Docker is installed. You can use Docker for development."
  DOCKER_AVAILABLE=true
else
  echo "Docker is not installed. Will set up local development environment."
  DOCKER_AVAILABLE=false
fi

# Function to setup local environment with asdf
setup_local_env() {
  # Install dependencies for asdf and building Erlang
  echo "Installing dependencies..."
  apt-get update
  apt-get install -y git curl build-essential autoconf m4 libncurses5-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-17-jdk

  # Install asdf
  echo "Setting up asdf version manager..."
  if [ ! -d "$HOME/.asdf" ]; then
    echo "Installing asdf..."
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
    echo '. "$HOME/.asdf/asdf.sh"' >>~/.bashrc
    echo '. "$HOME/.asdf/completions/asdf.bash"' >>~/.bashrc
  else
    echo "asdf already installed, skipping installation..."
  fi

  # Source asdf
  if [ -f "$HOME/.asdf/asdf.sh" ]; then
    source "$HOME/.asdf/asdf.sh"
  else
    echo "Error: asdf.sh not found. Please check your asdf installation."
    exit 1
  fi

  # Install Erlang and Elixir plugins
  echo "Installing asdf plugins for Erlang and Elixir..."
  asdf plugin add erlang || echo "Erlang plugin already installed"
  asdf plugin add elixir || echo "Elixir plugin already installed"

  # Install Erlang and Elixir versions from .tool-versions
  echo "Installing Erlang and Elixir using asdf..."
  echo "Note: This may take a while as Erlang needs to be compiled from source."
  echo "You can check the progress in another terminal with: tail -f ~/.asdf/plugins/erlang/kerl-home/builds/asdf_*/otp_build*.log"

  # Try to install Elixir first as it's faster
  asdf install elixir || echo "Failed to install Elixir. Continuing with Erlang..."

  # Install Erlang (this will take a while)
  echo "Installing Erlang (this may take 10-20 minutes)..."
  asdf install erlang || echo "Failed to install Erlang. Please check your .tool-versions file."

  # Verify installations
  if asdf which erl >/dev/null 2>&1 && asdf which elixir >/dev/null 2>&1; then
    echo "Erlang and Elixir installed successfully!"

    # Install Hex package manager and Rebar
    echo "Installing Hex package manager and Rebar..."
    asdf exec mix local.hex --force
    asdf exec mix local.rebar --force
  else
    echo "Warning: Erlang and/or Elixir installation may not be complete."
    echo "You may need to run 'asdf install' manually after setup completes."
  fi

  # Get dependencies
  echo "Fetching project dependencies..."
  mix deps.get

  # Compile the project
  echo "Compiling the project..."
  mix compile

  # Run tests to verify setup
  echo "Running tests to verify setup..."
  mix test
}

# Function to setup Docker environment
setup_docker_env() {
  echo "Setting up Docker environment..."

  # Check if docker-compose is installed
  if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Installing docker-compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi

  # Build Docker image
  echo "Building Docker image..."
  docker-compose build

  # Run tests in Docker to verify setup
  echo "Running tests in Docker to verify setup..."
  docker-compose run --rm mcpex mix test
}

# Ask user which setup to use
if [ "$DOCKER_AVAILABLE" = true ]; then
  setup_docker_env
else
  setup_local_env
fi

echo "Setup complete! Your MCPEX development environment is ready."
echo ""
echo "To start the application:"
if [ "$DOCKER_AVAILABLE" = true ] && [ "$choice" = "1" ]; then
  echo "  - With Docker: docker-compose up"
  echo "  - To run tests: docker-compose run --rm mcpex mix test"
  echo "  - To get a shell: docker-compose run --rm mcpex bash"
else
  echo "  - Locally: mix run --no-halt"
  echo "  - To run tests: mix test"
fi
echo ""
echo "You can also use the Makefile commands:"
echo "  - make run         # Run the application"
echo "  - make test        # Run tests"
echo "  - make docker-run  # Run with Docker"
echo "  - make help        # Show all available commands"


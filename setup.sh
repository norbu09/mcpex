#!/bin/bash
set -e

echo "Setting up MCPEX development environment..."

# Install Erlang and Elixir
echo "Installing Erlang and Elixir..."
apt-get update
apt-get install -y elixir erlang-dev

# Install Hex package manager and Rebar
echo "Installing Hex package manager and Rebar..."
mix local.hex --force
mix local.rebar --force

# Get dependencies
echo "Fetching project dependencies..."
mix deps.get

# Compile the project
echo "Compiling the project..."
mix compile

# Run tests to verify setup
echo "Running tests to verify setup..."
mix test

echo "Setup complete! Your MCPEX development environment is ready."
echo "To start the application, run: mix run --no-halt"
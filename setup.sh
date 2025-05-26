#!/bin/bash
set -e

echo "Setting up MCPEX development environment..."

# Install dependencies for asdf and building Erlang
echo "Installing dependencies..."
apt-get update
apt-get install -y git curl build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk

# Install asdf
echo "Installing asdf version manager..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.asdf/asdf.sh

# Install Erlang and Elixir plugins
echo "Installing asdf plugins for Erlang and Elixir..."
asdf plugin add erlang
asdf plugin add elixir

# Install Erlang and Elixir versions from .tool-versions
echo "Installing Erlang and Elixir using asdf..."
asdf install

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
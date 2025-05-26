FROM elixir:1.16-slim

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Copy dependencies files
COPY config ./config

# Get dependencies
RUN mix deps.get

# Copy the rest of the application
COPY . .

# Compile the application
RUN mix compile

# Run the application
CMD ["mix", "run", "--no-halt"]

# Expose the default port
EXPOSE 4000
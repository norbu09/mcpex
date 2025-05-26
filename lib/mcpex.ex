defmodule Mcpex do
  @moduledoc """
  Mcpex is an Elixir implementation of the Model Context Protocol (MCP).
  
  This module provides the main API for working with the MCP protocol.
  """

  @doc """
  Starts the MCP server with the specified options.
  
  ## Options
  
  - `:name` - The name of the server (default: `Mcpex.Server`)
  - `:server_info` - Information about the server (name, version, etc.)
  - `:capabilities` - Map of capabilities the server supports
  
  ## Returns
  
  - `{:ok, pid}` - The PID of the server process
  - `{:error, reason}` - If the server failed to start
  """
  def start_server(opts \\ []) do
    Mcpex.Server.start_link(opts)
  end

  @doc """
  Registers a capability with the MCP server.
  
  ## Parameters
  
  - `capability_name` - The name of the capability (e.g., :resources, :prompts, :tools)
  - `module` - The module that implements the capability
  - `config` - Optional configuration for the capability
  
  ## Returns
  
  - `{:ok, pid}` - The PID of the registered capability
  - `{:error, reason}` - If registration failed
  """
  def register_capability(capability_name, module, config \\ %{}) do
    Mcpex.Registry.register(capability_name, module, config)
  end

  @doc """
  Lists all registered capabilities.
  
  ## Returns
  
  A map of capability names to their implementations.
  """
  def list_capabilities do
    Mcpex.Registry.list_capabilities()
  end

  @doc """
  Starts the MCP server with the default capabilities.
  
  This is a convenience function that starts the server and registers
  the default capabilities (resources, prompts, tools).
  
  ## Options
  
  - `:name` - The name of the server (default: `Mcpex.Server`)
  - `:server_info` - Information about the server (name, version, etc.)
  
  ## Returns
  
  - `{:ok, pid}` - The PID of the server process
  - `{:error, reason}` - If the server failed to start
  """
  def start_with_default_capabilities(opts \\ []) do
    # Start the server
    {:ok, server} = start_server(opts)
    
    # Register default capabilities
    register_capability(:resources, Mcpex.Capabilities.Resources)
    register_capability(:prompts, Mcpex.Capabilities.Prompts)
    register_capability(:tools, Mcpex.Capabilities.Tools)
    
    {:ok, server}
  end
end

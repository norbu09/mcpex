defmodule Mcpex.Registry do
  @moduledoc """
  Central registry for MCP feature registration and discovery.
  
  This module provides functions to register and discover MCP capabilities
  at runtime, allowing for a decoupled architecture where capabilities
  can be added without modifying the core server.
  """

  @doc """
  Starts the registry as part of the application supervision tree.
  """
  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  Registers a capability with the registry.
  
  ## Parameters
  
  - `capability_name`: The name of the capability (e.g., :resources, :prompts, :tools)
  - `module`: The module that implements the capability
  - `config`: Optional configuration for the capability
  
  ## Returns
  
  - `{:ok, pid}` if registration was successful
  - `{:error, reason}` if registration failed
  """
  def register(capability_name, module, config \\ %{}) do
    Registry.register(__MODULE__, capability_name, %{
      module: module,
      config: config
    })
  end

  @doc """
  Looks up a capability in the registry.
  
  ## Parameters
  
  - `capability_name`: The name of the capability to look up
  
  ## Returns
  
  - `{:ok, {pid, %{module: module, config: config}}}` if the capability is registered
  - `{:error, :not_found}` if the capability is not registered
  """
  def lookup(capability_name) do
    case Registry.lookup(__MODULE__, capability_name) do
      [] -> {:error, :not_found}
      [{pid, value}] -> {:ok, {pid, value}}
      entries when is_list(entries) -> {:ok, entries}
    end
  end

  @doc """
  Lists all registered capabilities.
  
  ## Returns
  
  A map of capability names to their implementations.
  """
  def list_capabilities do
    Registry.select(__MODULE__, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  @doc """
  Unregisters a capability from the registry.
  
  ## Parameters
  
  - `capability_name`: The name of the capability to unregister
  
  ## Returns
  
  - `:ok` if unregistration was successful
  """
  def unregister(capability_name) do
    Registry.unregister(__MODULE__, capability_name)
  end
end
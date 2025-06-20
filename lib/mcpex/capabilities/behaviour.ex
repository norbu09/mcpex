defmodule Mcpex.Capabilities.Behaviour do
  @moduledoc """
  Behaviour for MCP capabilities.

  This module defines the behaviour that all MCP capabilities must implement.
  """

  @doc """
  Checks if the capability is supported by the client.

  ## Parameters

  - `client_capabilities` - The capabilities advertised by the client

  ## Returns

  - `true` - If the capability is supported
  - `false` - If the capability is not supported
  """
  @callback supports?(client_capabilities :: map()) :: boolean()

  @doc """
  Gets the server capabilities for this capability.

  ## Parameters

  - `config` - The configuration for the capability

  ## Returns

  - A map of capability-specific server capabilities
  """
  @callback get_server_capabilities(config :: map()) :: map()

  @doc """
  Handles a request for this capability.

  ## Parameters

  - `method` - The method being called
  - `params` - The parameters for the method
  - `session_id` - The session ID for the client

  ## Returns

  - `{:ok, result}` - The result to send back to the client
  - `{:error, error}` - If an error occurred
  """
  @callback handle_request(method :: String.t(), params :: map(), session_id :: String.t()) ::
              {:ok, map()} | {:error, map()}
end

defmodule Mcpex.Handlers.Initialization do
  @moduledoc """
  Handlers for initialization requests and notifications.

  This module handles:
  - Initialize request/response handling
  - Capability advertisement
  - Protocol version negotiation
  """

  require Logger

  @doc """
  Handles an initialization request.

  ## Parameters

  - `params` - The parameters from the initialize request
  - `session_id` - The session ID for the client

  ## Returns

  - `{:ok, result}` - The result to send back to the client
  - `{:error, error}` - If an error occurred
  """
  def handle_initialize(params, session_id) do
    client_info = Map.get(params, "clientInfo", %{})
    client_capabilities = Map.get(params, "capabilities", %{})

    Logger.info("Initializing session #{session_id} for client: #{inspect(client_info)}")

    # Get server info and capabilities
    server_info = get_server_info()
    server_capabilities = get_server_capabilities(client_capabilities)

    # Store session information
    store_session_info(session_id, client_info, client_capabilities, server_capabilities)

    # Return server info and capabilities
    {:ok,
     %{
       "serverInfo" => server_info,
       "capabilities" => server_capabilities
     }}
  end

  @doc """
  Handles the initialized notification.

  ## Parameters

  - `params` - The parameters from the initialized notification
  - `session_id` - The session ID for the client

  ## Returns

  - `:ok` - If the notification was processed successfully
  - `{:error, error}` - If an error occurred
  """
  def handle_initialized(params, session_id) do
    Logger.info("Session #{session_id} initialized with params: #{inspect(params)}")
    mark_session_as_initialized(session_id)
    :ok
  end

  @doc """
  Handles a shutdown request.

  ## Parameters

  - `params` - The parameters from the shutdown request
  - `session_id` - The session ID for the client

  ## Returns

  - `{:ok, result}` - The result to send back to the client
  - `{:error, error}` - If an error occurred
  """
  def handle_shutdown(params, session_id) do
    Logger.info("Shutting down session #{session_id} with params: #{inspect(params)}")
    cleanup_session(session_id)
    {:ok, %{}}
  end

  @doc """
  Handles an exit notification.

  ## Parameters

  - `params` - The parameters from the exit notification
  - `session_id` - The session ID for the client

  ## Returns

  - `:ok` - If the notification was processed successfully
  - `{:error, error}` - If an error occurred
  """
  def handle_exit(params, session_id) do
    Logger.info(
      "Exit notification received for session #{session_id} with params: #{inspect(params)}"
    )

    cleanup_session(session_id)
    :ok
  end

  # Private functions

  defp get_server_info do
    %{
      "name" => "mcpex",
      "version" => "1.0.0"
    }
  end

  defp get_server_capabilities(client_capabilities) do
    # Get all registered capabilities from the registry
    registered_capabilities = Mcpex.Registry.list_capabilities()

    # Filter and transform capabilities based on client capabilities
    Enum.reduce(registered_capabilities, %{}, fn {capability_name,
                                                  %{module: module, config: config}},
                                                 acc ->
      if module.supports?(client_capabilities) do
        Map.put(acc, Atom.to_string(capability_name), module.get_server_capabilities(config))
      else
        acc
      end
    end)
  end

  defp store_session_info(session_id, client_info, client_capabilities, server_capabilities) do
    # This would typically store the session information in a session store
    # For now, we'll just log it
    Logger.debug(
      "Storing session info for #{session_id}: client_info=#{inspect(client_info)}, " <>
        "client_capabilities=#{inspect(client_capabilities)}, " <>
        "server_capabilities=#{inspect(server_capabilities)}"
    )
  end

  defp mark_session_as_initialized(session_id) do
    # This would typically mark the session as initialized in a session store
    # For now, we'll just log it
    Logger.debug("Marking session #{session_id} as initialized")
  end

  defp cleanup_session(session_id) do
    # This would typically clean up the session in a session store
    # For now, we'll just log it
    Logger.debug("Cleaning up session #{session_id}")
  end
end

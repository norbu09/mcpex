defmodule Mcpex.Server do
  @moduledoc """
  Main server GenServer for the MCP protocol.
  
  This module handles:
  - Initialization handshake
  - Capability negotiation
  - Request routing
  - Handler registration
  """

  use GenServer
  require Logger

  alias Mcpex.Protocol.JsonRpc
  alias Mcpex.Protocol.Errors

  # Client API

  @doc """
  Starts the MCP server.
  
  ## Options
  
  - `:name` - The name of the server (default: `Mcpex.Server`)
  - `:server_info` - Information about the server (name, version, etc.)
  - `:capabilities` - Map of capabilities the server supports
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Processes an incoming JSON-RPC message.
  
  ## Parameters
  
  - `server` - The server process or name
  - `message` - The JSON-RPC message as a string or map
  - `session_id` - Optional session ID for the client
  
  ## Returns
  
  - `{:ok, response}` - The response to send back to the client
  - `{:error, reason}` - If an error occurred
  - `:noreply` - If no response is needed (e.g., for notifications)
  """
  def process_message(server, message, session_id \\ nil) do
    GenServer.call(server, {:process_message, message, session_id})
  end

  @doc """
  Sends a notification to a client.
  
  ## Parameters
  
  - `server` - The server process or name
  - `method` - The notification method
  - `params` - The notification parameters
  - `session_id` - The session ID of the client to notify
  
  ## Returns
  
  - `:ok` - If the notification was sent
  - `{:error, reason}` - If an error occurred
  """
  def notify(server, method, params, session_id) do
    GenServer.cast(server, {:notify, method, params, session_id})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    server_info = Keyword.get(opts, :server_info, %{
      name: "mcpex",
      version: "1.0.0"
    })
    
    capabilities = Keyword.get(opts, :capabilities, %{})
    
    state = %{
      server_info: server_info,
      capabilities: capabilities,
      sessions: %{},
      initialized_sessions: MapSet.new()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:process_message, message, session_id}, _from, state) do
    case JsonRpc.parse(message) do
      {:ok, parsed_message} ->
        handle_parsed_message(parsed_message, session_id, state)
      
      {:error, error} ->
        Logger.error("Failed to parse JSON-RPC message: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_cast({:notify, method, params, session_id}, state) do
    notification = JsonRpc.notification(method, params)
    
    # Here you would send the notification to the client
    # This depends on your transport implementation
    Logger.info("Sending notification to session #{session_id}: #{inspect(notification)}")
    
    {:noreply, state}
  end

  # Private functions

  defp handle_parsed_message(%{jsonrpc: "2.0", method: method} = request, session_id, state) do
    # Handle request based on method
    case method do
      "initialize" ->
        handle_initialize(request, session_id, state)
      
      other_method when is_binary(other_method) ->
        if is_session_initialized?(session_id, state) do
          route_request(request, session_id, state)
        else
          error = Errors.server_not_initialized()
          response = JsonRpc.error_response(request["id"], error)
          {:reply, {:ok, response}, state}
        end
      
      _ ->
        error = Errors.method_not_found()
        response = JsonRpc.error_response(request["id"], error)
        {:reply, {:ok, response}, state}
    end
  end

  defp handle_initialize(%{id: id, params: params}, session_id, state) do
    # Process initialization request
    client_info = Map.get(params, "clientInfo", %{})
    client_capabilities = Map.get(params, "capabilities", %{})
    
    # Determine which capabilities to advertise based on client capabilities
    # and registered capabilities in the registry
    advertised_capabilities = get_advertised_capabilities(client_capabilities)
    
    # Create response with server info and capabilities
    response_params = %{
      "serverInfo" => state.server_info,
      "capabilities" => advertised_capabilities
    }
    
    response = JsonRpc.response(id, response_params)
    
    # Update state with new session
    new_sessions = Map.put(state.sessions, session_id, %{
      client_info: client_info,
      client_capabilities: client_capabilities,
      server_capabilities: advertised_capabilities
    })
    
    # Mark session as initialized
    new_initialized_sessions = MapSet.put(state.initialized_sessions, session_id)
    
    new_state = %{
      state | 
      sessions: new_sessions,
      initialized_sessions: new_initialized_sessions
    }
    
    # Send initialized notification
    # This would typically be done by the transport layer
    _initialized_notification = JsonRpc.notification("initialized", %{})
    Logger.info("Sending initialized notification to session #{session_id}")
    
    {:reply, {:ok, response}, new_state}
  end

  defp route_request(%{method: method, id: id, params: params}, session_id, state) do
    # Route the request to the appropriate handler based on the method
    # This uses the registry to find the appropriate handler
    case get_handler_for_method(method) do
      {:ok, handler_module} ->
        try do
          case apply(handler_module, :handle_request, [method, params, session_id]) do
            {:ok, result} ->
              response = JsonRpc.response(id, result)
              {:reply, {:ok, response}, state}
            
            {:error, error} ->
              response = JsonRpc.error_response(id, error)
              {:reply, {:ok, response}, state}
          end
        rescue
          e ->
            Logger.error("Error handling request: #{inspect(e)}")
            error = Errors.internal_error("Unexpected error: #{inspect(e)}")
            response = JsonRpc.error_response(id, error)
            {:reply, {:ok, response}, state}
        end
      
      {:error, :not_found} ->
        error = Errors.method_not_found()
        response = JsonRpc.error_response(id, error)
        {:reply, {:ok, response}, state}
    end
  end

  defp is_session_initialized?(session_id, %{initialized_sessions: initialized_sessions}) do
    MapSet.member?(initialized_sessions, session_id)
  end

  defp get_advertised_capabilities(client_capabilities) do
    # Get all registered capabilities from the registry
    registered_capabilities = Mcpex.Registry.list_capabilities()
    
    # Filter and transform capabilities based on client capabilities
    Enum.reduce(registered_capabilities, %{}, fn {capability_name, %{module: module, config: config}}, acc ->
      if module.supports?(client_capabilities) do
        Map.put(acc, capability_name, module.get_server_capabilities(config))
      else
        acc
      end
    end)
  end

  defp get_handler_for_method(method) do
    # Map method to capability and look up in registry
    {capability, _specific_method} = parse_method(method)
    
    case Mcpex.Registry.lookup(capability) do
      {:ok, {_pid, %{module: module}}} -> {:ok, module}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp parse_method(method) do
    case String.split(method, "/", parts: 2) do
      [capability, specific_method] -> {String.to_atom(capability), specific_method}
      [capability] -> {String.to_atom(capability), nil}
    end
  end
end
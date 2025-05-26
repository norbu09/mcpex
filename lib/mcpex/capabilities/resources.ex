defmodule Mcpex.Capabilities.Resources do
  @moduledoc """
  Resources capability implementation.
  
  This module implements the resources capability, which allows clients to:
  - List available resources
  - Read resource contents
  - Subscribe to resource changes
  - Receive notifications about resource changes
  """

  @behaviour Mcpex.Capabilities.Behaviour

  require Logger
  alias Mcpex.Protocol.Errors

  # Capability behaviour implementation

  @impl true
  def supports?(_client_capabilities) do
    # Resources capability is always supported
    true
  end

  @impl true
  def get_server_capabilities(_config) do
    %{
      "supportsSubscriptions" => true,
      "supportsFiltering" => true
    }
  end

  @impl true
  def handle_request(method, params, session_id) do
    case method do
      "resources/list" -> handle_list(params, session_id)
      "resources/read" -> handle_read(params, session_id)
      "resources/subscribe" -> handle_subscribe(params, session_id)
      "resources/unsubscribe" -> handle_unsubscribe(params, session_id)
      _ -> {:error, Errors.method_not_found()}
    end
  end

  # Request handlers

  defp handle_list(params, session_id) do
    Logger.info("Listing resources for session #{session_id} with params: #{inspect(params)}")
    
    # Get resources from the registry or other storage
    resources = get_resources(params)
    
    {:ok, %{"resources" => resources}}
  end

  defp handle_read(params, session_id) do
    Logger.info("Reading resource for session #{session_id} with params: #{inspect(params)}")
    
    uri = Map.get(params, "uri")
    
    if uri do
      case read_resource(uri) do
        {:ok, content} ->
          {:ok, %{"contents" => [%{"uri" => uri, "text" => content}]}}
        
        {:error, reason} ->
          {:error, Errors.internal_error("Failed to read resource: #{reason}")}
      end
    else
      {:error, Errors.invalid_params("Missing required parameter: uri")}
    end
  end

  defp handle_subscribe(params, session_id) do
    Logger.info("Subscribing to resources for session #{session_id} with params: #{inspect(params)}")
    
    uri = Map.get(params, "uri")
    
    if uri do
      # Register subscription in the registry
      subscribe_to_resource(uri, session_id)
      
      {:ok, %{"subscriptionId" => "resource:#{uri}"}}
    else
      {:error, Errors.invalid_params("Missing required parameter: uri")}
    end
  end

  defp handle_unsubscribe(params, session_id) do
    Logger.info("Unsubscribing from resources for session #{session_id} with params: #{inspect(params)}")
    
    subscription_id = Map.get(params, "subscriptionId")
    
    if subscription_id do
      # Unregister subscription in the registry
      unsubscribe_from_resource(subscription_id, session_id)
      
      {:ok, %{}}
    else
      {:error, Errors.invalid_params("Missing required parameter: subscriptionId")}
    end
  end

  # Helper functions

  defp get_resources(_params) do
    # This would typically get resources from a storage system
    # For now, we'll return a static list
    [
      %{"uri" => "file://example.txt", "name" => "Example File", "mimeType" => "text/plain"},
      %{"uri" => "file://example.json", "name" => "Example JSON", "mimeType" => "application/json"}
    ]
  end

  defp read_resource(uri) do
    # This would typically read a resource from a storage system
    # For now, we'll return static content based on the URI
    case uri do
      "file://example.txt" -> {:ok, "This is an example text file."}
      "file://example.json" -> {:ok, ~s({"example": "This is an example JSON file."})}
      _ -> {:error, "Resource not found"}
    end
  end

  defp subscribe_to_resource(uri, session_id) do
    # This would typically register a subscription in a subscription store
    # For now, we'll just log it
    Logger.debug("Registered subscription for session #{session_id} to resource #{uri}")
  end

  defp unsubscribe_from_resource(subscription_id, session_id) do
    # This would typically unregister a subscription in a subscription store
    # For now, we'll just log it
    Logger.debug("Unregistered subscription #{subscription_id} for session #{session_id}")
  end
end
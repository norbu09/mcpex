defmodule Mcpex.Capabilities.Prompts do
  @moduledoc """
  Prompts capability implementation.
  
  This module implements the prompts capability, which allows clients to:
  - List available prompts
  - Retrieve prompt templates
  - Handle prompt arguments
  - Receive notifications about prompt changes
  """

  @behaviour Mcpex.Capabilities.Behaviour

  require Logger
  alias Mcpex.Protocol.Errors

  # Capability behaviour implementation

  @impl true
  def supports?(_client_capabilities) do
    # Prompts capability is always supported
    true
  end

  @impl true
  def get_server_capabilities(_config) do
    %{
      "supportsSubscriptions" => true,
      "supportsArguments" => true
    }
  end

  @impl true
  def handle_request(method, params, session_id) do
    case method do
      "prompts/list" -> handle_list(params, session_id)
      "prompts/get" -> handle_get(params, session_id)
      "prompts/subscribe" -> handle_subscribe(params, session_id)
      "prompts/unsubscribe" -> handle_unsubscribe(params, session_id)
      _ -> {:error, Errors.method_not_found()}
    end
  end

  # Request handlers

  defp handle_list(params, session_id) do
    Logger.info("Listing prompts for session #{session_id} with params: #{inspect(params)}")
    
    # Get prompts from the registry or other storage
    prompts = get_prompts(params)
    
    {:ok, %{"prompts" => prompts}}
  end

  defp handle_get(params, session_id) do
    Logger.info("Getting prompt for session #{session_id} with params: #{inspect(params)}")
    
    name = Map.get(params, "name")
    
    if name do
      case get_prompt(name) do
        {:ok, prompt} ->
          {:ok, %{"prompt" => prompt}}
        
        {:error, reason} ->
          {:error, Errors.internal_error("Failed to get prompt: #{reason}")}
      end
    else
      {:error, Errors.invalid_params("Missing required parameter: name")}
    end
  end

  defp handle_subscribe(params, session_id) do
    Logger.info("Subscribing to prompts for session #{session_id} with params: #{inspect(params)}")
    
    name = Map.get(params, "name")
    
    if name do
      # Register subscription in the registry
      subscribe_to_prompt(name, session_id)
      
      {:ok, %{"subscriptionId" => "prompt:#{name}"}}
    else
      {:error, Errors.invalid_params("Missing required parameter: name")}
    end
  end

  defp handle_unsubscribe(params, session_id) do
    Logger.info("Unsubscribing from prompts for session #{session_id} with params: #{inspect(params)}")
    
    subscription_id = Map.get(params, "subscriptionId")
    
    if subscription_id do
      # Unregister subscription in the registry
      unsubscribe_from_prompt(subscription_id, session_id)
      
      {:ok, %{}}
    else
      {:error, Errors.invalid_params("Missing required parameter: subscriptionId")}
    end
  end

  # Helper functions

  defp get_prompts(_params) do
    # This would typically get prompts from a storage system
    # For now, we'll return a static list
    [
      %{
        "name" => "greeting",
        "description" => "A simple greeting prompt",
        "argumentSchema" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{
              "type" => "string",
              "description" => "The name to greet"
            }
          }
        }
      },
      %{
        "name" => "summary",
        "description" => "A prompt to summarize text",
        "argumentSchema" => %{
          "type" => "object",
          "properties" => %{
            "text" => %{
              "type" => "string",
              "description" => "The text to summarize"
            },
            "length" => %{
              "type" => "integer",
              "description" => "The desired summary length in words"
            }
          },
          "required" => ["text"]
        }
      }
    ]
  end

  defp get_prompt(name) do
    # This would typically get a prompt from a storage system
    # For now, we'll return static content based on the name
    case name do
      "greeting" ->
        {:ok, %{
          "name" => "greeting",
          "description" => "A simple greeting prompt",
          "template" => "Hello, {{name}}!",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{
                "type" => "string",
                "description" => "The name to greet"
              }
            }
          }
        }}
      
      "summary" ->
        {:ok, %{
          "name" => "summary",
          "description" => "A prompt to summarize text",
          "template" => "Please summarize the following text in {{length}} words or less:\n\n{{text}}",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{
                "type" => "string",
                "description" => "The text to summarize"
              },
              "length" => %{
                "type" => "integer",
                "description" => "The desired summary length in words"
              }
            },
            "required" => ["text"]
          }
        }}
      
      _ -> {:error, "Prompt not found"}
    end
  end

  defp subscribe_to_prompt(name, session_id) do
    # This would typically register a subscription in a subscription store
    # For now, we'll just log it
    Logger.debug("Registered subscription for session #{session_id} to prompt #{name}")
  end

  defp unsubscribe_from_prompt(subscription_id, session_id) do
    # This would typically unregister a subscription in a subscription store
    # For now, we'll just log it
    Logger.debug("Unregistered subscription #{subscription_id} for session #{session_id}")
  end
end
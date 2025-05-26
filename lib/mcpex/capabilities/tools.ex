defmodule Mcpex.Capabilities.Tools do
  @moduledoc """
  Tools capability implementation.

  This module implements the tools capability, which allows clients to:
  - List available tools
  - Execute tools
  - Receive progress updates
  - Receive notifications about tool changes
  """

  @behaviour Mcpex.Capabilities.Behaviour

  require Logger
  alias Mcpex.Protocol.Errors

  # Capability behaviour implementation

  @impl true
  def supports?(_client_capabilities) do
    # Tools capability is always supported
    true
  end

  @impl true
  def get_server_capabilities(_config) do
    %{
      "supportsProgress" => true,
      "supportsSubscriptions" => true
    }
  end

  @impl true
  def handle_request(method, params, session_id) do
    case method do
      "tools/list" -> handle_list(params, session_id)
      "tools/execute" -> handle_execute(params, session_id)
      "tools/cancel" -> handle_cancel(params, session_id)
      "tools/subscribe" -> handle_subscribe(params, session_id)
      "tools/unsubscribe" -> handle_unsubscribe(params, session_id)
      _ -> {:error, Errors.method_not_found()}
    end
  end

  # Request handlers

  defp handle_list(params, session_id) do
    Logger.info("Listing tools for session #{session_id} with params: #{inspect(params)}")

    # Get tools from the registry
    tools = get_tools(params)

    {:ok, %{"tools" => tools}}
  end

  defp handle_execute(params, session_id) do
    Logger.info("Executing tool for session #{session_id} with params: #{inspect(params)}")

    name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})

    if name do
      # Execute the tool
      case execute_tool(name, arguments, session_id) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          {:error, Errors.internal_error("Failed to execute tool: #{reason}")}
      end
    else
      {:error, Errors.invalid_params("Missing required parameter: name")}
    end
  end

  defp handle_cancel(params, session_id) do
    Logger.info("Cancelling tool execution for session #{session_id} with params: #{inspect(params)}")

    execution_id = Map.get(params, "executionId")

    if execution_id do
      # Cancel the tool execution
      cancel_tool_execution(execution_id, session_id)
      {:ok, %{}}
    else
      {:error, Errors.invalid_params("Missing required parameter: executionId")}
    end
  end

  defp handle_subscribe(params, session_id) do
    Logger.info("Subscribing to tools for session #{session_id} with params: #{inspect(params)}")

    name = Map.get(params, "name")

    if name do
      # Register subscription in the registry
      subscribe_to_tool(name, session_id)

      {:ok, %{"subscriptionId" => "tool:#{name}"}}
    else
      {:error, Errors.invalid_params("Missing required parameter: name")}
    end
  end

  defp handle_unsubscribe(params, session_id) do
    Logger.info("Unsubscribing from tools for session #{session_id} with params: #{inspect(params)}")

    subscription_id = Map.get(params, "subscriptionId")

    if subscription_id do
      # Unregister subscription in the registry
      unsubscribe_from_tool(subscription_id, session_id)

      {:ok, %{}}
    else
      {:error, Errors.invalid_params("Missing required parameter: subscriptionId")}
    end
  end

  # Helper functions

  defp get_tools(_params) do
    # Query the registry for registered tools
    case Mcpex.Registry.lookup(:tools_registry) do
      {:ok, {_pid, %{config: %{tools: tools}}}} -> tools
      _ -> []
    end
  end

  defp execute_tool(name, arguments, _session_id) do
    # Get tool executors from registry
    case Mcpex.Registry.lookup(:tool_executors) do
      {:ok, {_pid, %{config: %{executors: executors}}}} ->
        case Map.get(executors, name) do
          nil -> {:error, "Unknown tool: #{name}"}
          executor when is_function(executor) -> executor.(arguments)
        end
      _ ->
        {:error, "No tool executors found"}
    end
  end

  defp cancel_tool_execution(execution_id, _session_id) do
    # This would typically cancel a tool execution
    # For now, we'll just log it
    Logger.debug("Cancelled tool execution #{execution_id}")
    :ok
  end

  defp subscribe_to_tool(name, session_id) do
    # This would typically register a subscription in a subscription store
    # For now, we'll just log it
    Logger.debug("Registered subscription for session #{session_id} to tool #{name}")
  end

  defp unsubscribe_from_tool(subscription_id, session_id) do
    # This would typically unregister a subscription in a subscription store
    # For now, we'll just log it
    Logger.debug("Unregistered subscription #{subscription_id} for session #{session_id}")
  end
end
defmodule Mcpex.Protocol.Messages do
  @moduledoc """
  MCP-specific message schemas and validation helpers.

  This module defines the structure and validation for Model Context Protocol
  messages, including initialization, capability negotiation, and core MCP
  operations.
  """

  @type client_info :: %{
          name: String.t(),
          version: String.t()
        }

  @type server_info :: %{
          name: String.t(),
          version: String.t()
        }

  @type capabilities :: %{
          resources: map() | nil,
          prompts: map() | nil,
          tools: map() | nil,
          sampling: map() | nil
        }

  @type initialize_params :: %{
          protocolVersion: String.t(),
          capabilities: capabilities(),
          clientInfo: client_info()
        }

  @type initialize_result :: %{
          protocolVersion: String.t(),
          capabilities: capabilities(),
          serverInfo: server_info()
        }

  @doc """
  MCP protocol version supported by this implementation.
  """
  @spec protocol_version() :: String.t()
  def protocol_version, do: "2025-03-26"

  @doc """
  Creates an initialize request message.
  """
  @spec initialize_request(client_info(), capabilities(), String.t()) :: map()
  def initialize_request(client_info, capabilities, id) do
    %{
      jsonrpc: "2.0",
      method: "initialize",
      params: %{
        protocolVersion: protocol_version(),
        capabilities: normalize_capabilities(capabilities),
        clientInfo: client_info
      },
      id: id
    }
  end

  @doc """
  Creates an initialize response message.
  """
  @spec initialize_response(server_info(), capabilities(), String.t()) :: map()
  def initialize_response(server_info, capabilities, id) do
    %{
      jsonrpc: "2.0",
      result: %{
        protocolVersion: protocol_version(),
        capabilities: normalize_capabilities(capabilities),
        serverInfo: server_info
      },
      id: id
    }
  end

  @doc """
  Creates an initialized notification message.
  """
  @spec initialized_notification() :: map()
  def initialized_notification do
    %{
      jsonrpc: "2.0",
      method: "initialized"
    }
  end

  @doc """
  Creates a resources/list request message.
  """
  @spec list_resources_request(String.t()) :: map()
  def list_resources_request(id) do
    %{
      jsonrpc: "2.0",
      method: "resources/list",
      id: id
    }
  end

  @doc """
  Creates a resources/read request message.
  """
  @spec read_resource_request(String.t(), String.t()) :: map()
  def read_resource_request(uri, id) do
    %{
      jsonrpc: "2.0",
      method: "resources/read",
      params: %{uri: uri},
      id: id
    }
  end

  @doc """
  Creates a prompts/list request message.
  """
  @spec list_prompts_request(String.t()) :: map()
  def list_prompts_request(id) do
    %{
      jsonrpc: "2.0",
      method: "prompts/list",
      id: id
    }
  end

  @doc """
  Creates a prompts/get request message.
  """
  @spec get_prompt_request(String.t(), map(), String.t()) :: map()
  def get_prompt_request(name, arguments, id) do
    params = %{name: name}
    params = if arguments && map_size(arguments) > 0, do: Map.put(params, :arguments, arguments), else: params

    %{
      jsonrpc: "2.0",
      method: "prompts/get",
      params: params,
      id: id
    }
  end

  @doc """
  Creates a tools/list request message.
  """
  @spec list_tools_request(String.t()) :: map()
  def list_tools_request(id) do
    %{
      jsonrpc: "2.0",
      method: "tools/list",
      id: id
    }
  end

  @doc """
  Creates a tools/call request message.
  """
  @spec call_tool_request(String.t(), map(), String.t()) :: map()
  def call_tool_request(name, arguments, id) do
    params = %{name: name}
    params = if arguments && map_size(arguments) > 0, do: Map.put(params, :arguments, arguments), else: params

    %{
      jsonrpc: "2.0",
      method: "tools/call",
      params: params,
      id: id
    }
  end

  @doc """
  Creates a notification for resource list changes.
  """
  @spec resources_list_changed_notification() :: map()
  def resources_list_changed_notification do
    %{
      jsonrpc: "2.0",
      method: "notifications/resources/list_changed"
    }
  end

  @doc """
  Creates a notification for prompt list changes.
  """
  @spec prompts_list_changed_notification() :: map()
  def prompts_list_changed_notification do
    %{
      jsonrpc: "2.0",
      method: "notifications/prompts/list_changed"
    }
  end

  @doc """
  Creates a notification for tool list changes.
  """
  @spec tools_list_changed_notification() :: map()
  def tools_list_changed_notification do
    %{
      jsonrpc: "2.0",
      method: "notifications/tools/list_changed"
    }
  end

  @doc """
  Validates an initialize request parameters.
  """
  @spec validate_initialize_params(map()) :: {:ok, initialize_params()} | {:error, String.t()}
  def validate_initialize_params(params) when is_map(params) do
    with {:ok, protocol_version} <- validate_protocol_version(params),
         {:ok, capabilities} <- validate_capabilities(params),
         {:ok, client_info} <- validate_client_info(params) do
      {:ok, %{
        protocolVersion: protocol_version,
        capabilities: capabilities,
        clientInfo: client_info
      }}
    end
  end

  def validate_initialize_params(_), do: {:error, "Initialize params must be an object"}

  @doc """
  Validates MCP capabilities object.
  """
  @spec validate_capabilities(map()) :: {:ok, capabilities()} | {:error, String.t()}
  def validate_capabilities(%{"capabilities" => capabilities}) when is_map(capabilities) do
    {:ok, normalize_capabilities(capabilities)}
  end

  def validate_capabilities(%{capabilities: capabilities}) when is_map(capabilities) do
    {:ok, normalize_capabilities(capabilities)}
  end

  def validate_capabilities(%{}) do
    {:ok, %{resources: nil, prompts: nil, tools: nil, sampling: nil}}
  end

  def validate_capabilities(_), do: {:error, "Capabilities must be an object"}

  # Private functions

  defp validate_protocol_version(%{"protocolVersion" => version}) when is_binary(version) do
    {:ok, version}
  end

  defp validate_protocol_version(%{protocolVersion: version}) when is_binary(version) do
    {:ok, version}
  end

  defp validate_protocol_version(%{}) do
    {:error, "Missing protocolVersion"}
  end

  defp validate_protocol_version(_) do
    {:error, "protocolVersion must be a string"}
  end

  defp validate_client_info(%{"clientInfo" => %{"name" => name, "version" => version}})
    when is_binary(name) and is_binary(version) do
    {:ok, %{name: name, version: version}}
  end

  defp validate_client_info(%{"clientInfo" => %{"name" => name}}) when is_binary(name) do
    {:ok, %{name: name, version: "unknown"}}
  end

  defp validate_client_info(%{clientInfo: %{name: name, version: version}})
    when is_binary(name) and is_binary(version) do
    {:ok, %{name: name, version: version}}
  end

  defp validate_client_info(%{clientInfo: %{name: name}}) when is_binary(name) do
    {:ok, %{name: name, version: "unknown"}}
  end

  defp validate_client_info(%{}) do
    {:error, "Missing clientInfo"}
  end

  defp validate_client_info(_) do
    {:error, "clientInfo must be an object with name and version"}
  end

  defp normalize_capabilities(capabilities) when is_map(capabilities) do
    %{
      resources: Map.get(capabilities, :resources) || Map.get(capabilities, "resources"),
      prompts: Map.get(capabilities, :prompts) || Map.get(capabilities, "prompts"),
      tools: Map.get(capabilities, :tools) || Map.get(capabilities, "tools"),
      sampling: Map.get(capabilities, :sampling) || Map.get(capabilities, "sampling")
    }
  end

  defp normalize_capabilities(_) do
    %{resources: nil, prompts: nil, tools: nil, sampling: nil}
  end
end

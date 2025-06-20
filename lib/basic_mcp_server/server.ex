defmodule BasicMcpServer.Server do
  @moduledoc """
  This module implements the main MCP server functionality.
  It handles the initialization and routing of MCP requests.

  This server is a wrapper around the Mcpex library, providing a complete
  implementation of the Model Context Protocol (MCP) with all capabilities.
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the MCP server with the given options.

  ## Options

  - `:name` - The name to register the server process under (default: `__MODULE__`)
  - `:port` - The port to listen on for HTTP requests (default: 4000)
  - `:sse_port` - The port to listen on for SSE connections (default: 4001)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Stops the MCP server.
  """
  def stop(server \\ __MODULE__) do
    GenServer.stop(server)
  end

  @doc """
  Processes an incoming MCP message and returns the response.

  This function delegates to the Mcpex.Server implementation.
  """
  @spec process_message(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def process_message(message, session_id \\ nil) do
    Mcpex.Server.process_message(Mcpex.Server, message, session_id)
  end

  @doc """
  Handles an incoming MCP message and returns the response.

  This function is called by the transport layers and delegates to process_message.
  """
  @spec handle_message(map()) :: {:ok, map()} | {:error, term()}
  def handle_message(message) do
    # Extract session ID from the message context if available
    # For now, we'll use a default session ID
    session_id = "default-session"
    process_message(message, session_id)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Start the Mcpex server with all capabilities
    server_info = %{
      name: "BasicMcpServer",
      version: "1.0.0",
      description: "A complete MCP server implementation using the mcpex library"
    }

    {:ok, mcpex_server} = Mcpex.start_with_default_capabilities(
      name: Mcpex.Server,
      server_info: server_info
    )

    # Register example resources
    register_example_resources()

    # Register example prompts
    register_example_prompts()

    # Register example tools
    register_example_tools()

    # Register example sampling capability
    register_example_sampling()

    # Start the transport layers
    http_port = Keyword.get(opts, :port, 4000)
    sse_port = Keyword.get(opts, :sse_port, 4001)

    Logger.info("BasicMcpServer.Server starting with opts: #{inspect(opts)}")
    Logger.info("BasicMcpServer.Server using HTTP port: #{http_port}, SSE port: #{sse_port}")

    http_transport = case BasicMcpServer.Transport.StreamableHTTP.start_link(port: http_port) do
      {:ok, pid} ->
        Logger.info("HTTP transport started on port #{http_port}")
        pid
      {:error, reason} ->
        Logger.error("Failed to start HTTP transport on port #{http_port}: #{inspect(reason)}")
        nil
    end

    sse_transport = case BasicMcpServer.Transport.SSE.start_link(port: sse_port) do
      {:ok, pid} ->
        Logger.info("SSE transport started on port #{sse_port}")
        pid
      {:error, reason} ->
        Logger.error("Failed to start SSE transport on port #{sse_port}: #{inspect(reason)}")
        nil
    end

    if http_transport || sse_transport do
      Logger.info("MCP server started with available transports")
      {:ok, %{
        mcpex_server: mcpex_server,
        http_transport: http_transport,
        sse_transport: sse_transport
      }}
    else
      Logger.error("Failed to start any transport layers")
      {:error, :no_transports_available}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Stop the transports and server
    if state.http_transport, do: Supervisor.stop(state.http_transport)
    if state.sse_transport, do: Supervisor.stop(state.sse_transport)
    if state.mcpex_server, do: GenServer.stop(state.mcpex_server)

    :ok
  end

  # Private helper functions

  defp register_example_resources do
    # Register resources
    Mcpex.Registry.register(:resources_registry, Mcpex.Capabilities.Resources, %{
      resources: [
        %{
          "uri" => "file://example/readme.md",
          "name" => "README",
          "mimeType" => "text/markdown"
        },
        %{
          "uri" => "file://example/config.json",
          "name" => "Configuration",
          "mimeType" => "application/json"
        },
        %{
          "uri" => "file://example/schema.json",
          "name" => "JSON Schema",
          "mimeType" => "application/schema+json"
        }
      ]
    })

    # Register resource contents
    Mcpex.Registry.register({:resource_content, "file://example/readme.md"}, Mcpex.Capabilities.Resources, %{
      content: """
      # MCP Demo Server

      This is an example MCP server implementation using the mcpex library.

      ## Features

      - Full MCP protocol implementation
      - Resources capability
      - Prompts capability
      - Tools capability
      - Sampling capability
      - Multiple transport layers (SSE and Streamable HTTP)
      """
    })

    Mcpex.Registry.register({:resource_content, "file://example/config.json"}, Mcpex.Capabilities.Resources, %{
      content: """
      {
        "server": {
          "name": "BasicMcpServer",
          "version": "1.0.0"
        },
        "capabilities": [
          "resources",
          "prompts",
          "tools",
          "sampling"
        ],
        "transports": [
          {
            "type": "streamable_http",
            "port": 4000
          },
          {
            "type": "sse",
            "port": 4001
          }
        ]
      }
      """
    })

    Mcpex.Registry.register({:resource_content, "file://example/schema.json"}, Mcpex.Capabilities.Resources, %{
      content: """
      {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "title": "MCP Server Configuration",
        "type": "object",
        "properties": {
          "server": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "version": { "type": "string" }
            },
            "required": ["name", "version"]
          },
          "capabilities": {
            "type": "array",
            "items": { "type": "string" }
          },
          "transports": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "type": { "type": "string" },
                "port": { "type": "integer" }
              },
              "required": ["type", "port"]
            }
          }
        },
        "required": ["server", "capabilities"]
      }
      """
    })
  end

  defp register_example_prompts do
    # Register prompts
    Mcpex.Registry.register(:prompts_registry, Mcpex.Capabilities.Prompts, %{
      prompts: [
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
        },
        %{
          "name" => "code_generator",
          "description" => "A prompt to generate code",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "language" => %{
                "type" => "string",
                "description" => "The programming language to generate code in"
              },
              "task" => %{
                "type" => "string",
                "description" => "The task to generate code for"
              }
            },
            "required" => ["language", "task"]
          }
        }
      ]
    })

    # Register individual prompts
    Mcpex.Registry.register({:prompt, "greeting"}, Mcpex.Capabilities.Prompts, %{
      "name" => "greeting",
      "description" => "A simple greeting prompt",
      "template" => "Hello, {{name}}! Welcome to the MCP demo server.",
      "argumentSchema" => %{
        "type" => "object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "The name to greet"
          }
        }
      }
    })

    Mcpex.Registry.register({:prompt, "summary"}, Mcpex.Capabilities.Prompts, %{
      "name" => "summary",
      "description" => "A prompt to summarize text",
      "template" => """
      Please summarize the following text in {{length}} words or less:

      {{text}}
      """,
      "argumentSchema" => %{
        "type" => "object",
        "properties" => %{
          "text" => %{
            "type" => "string",
            "description" => "The text to summarize"
          },
          "length" => %{
            "type" => "integer",
            "description" => "The desired summary length in words",
            "default" => 100
          }
        },
        "required" => ["text"]
      }
    })

    Mcpex.Registry.register({:prompt, "code_generator"}, Mcpex.Capabilities.Prompts, %{
      "name" => "code_generator",
      "description" => "A prompt to generate code",
      "template" => """
      Please generate {{language}} code for the following task:

      {{task}}

      The code should be well-commented and follow best practices for {{language}}.
      """,
      "argumentSchema" => %{
        "type" => "object",
        "properties" => %{
          "language" => %{
            "type" => "string",
            "description" => "The programming language to generate code in",
            "enum" => ["Python", "JavaScript", "Elixir", "Rust", "Go"]
          },
          "task" => %{
            "type" => "string",
            "description" => "The task to generate code for"
          }
        },
        "required" => ["language", "task"]
      }
    })
  end

  defp register_example_tools do
    # Register tools
    Mcpex.Registry.register(:tools_registry, Mcpex.Capabilities.Tools, %{
      tools: [
        %{
          "name" => "calculator",
          "description" => "A simple calculator tool",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "expression" => %{
                "type" => "string",
                "description" => "The mathematical expression to evaluate"
              }
            },
            "required" => ["expression"]
          }
        },
        %{
          "name" => "current_time",
          "description" => "Get the current time",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "timezone" => %{
                "type" => "string",
                "description" => "The timezone to get the time for (default: UTC)"
              }
            }
          }
        },
        %{
          "name" => "random_number",
          "description" => "Generate a random number",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "min" => %{
                "type" => "integer",
                "description" => "The minimum value (inclusive)"
              },
              "max" => %{
                "type" => "integer",
                "description" => "The maximum value (inclusive)"
              }
            },
            "required" => ["min", "max"]
          }
        }
      ]
    })

    # Register tool executors
    Mcpex.Registry.register(:tool_executors, Mcpex.Capabilities.Tools, %{
      executors: %{
        "calculator" => fn arguments ->
          expression = Map.get(arguments, "expression", "")
          execution_id = "exec-#{:erlang.system_time(:millisecond)}"

          # This is a simplified example - in a real implementation, you would
          # validate the expression and use a proper parser/evaluator
          result =
            case Code.string_to_quoted(expression) do
              {:ok, ast} ->
                try do
                  {result, _} = Code.eval_quoted(ast)
                  "#{result}"
                rescue
                  _ -> "Error evaluating expression"
                end

              {:error, _} ->
                "Invalid expression"
            end

          {:ok,
           %{
             "executionId" => execution_id,
             "content" => [
               %{
                 "type" => "text",
                 "text" => "Result: #{result}"
               }
             ]
           }}
        end,

        "current_time" => fn arguments ->
          timezone = Map.get(arguments, "timezone", "UTC")
          execution_id = "exec-#{:erlang.system_time(:millisecond)}"

          # In a real implementation, you would handle different timezones
          current_time = DateTime.utc_now() |> DateTime.to_string()

          {:ok,
           %{
             "executionId" => execution_id,
             "content" => [
               %{
                 "type" => "text",
                 "text" => "Current time (#{timezone}): #{current_time}"
               }
             ]
           }}
        end,

        "random_number" => fn arguments ->
          min = Map.get(arguments, "min", 1)
          max = Map.get(arguments, "max", 100)
          execution_id = "exec-#{:erlang.system_time(:millisecond)}"

          # Generate a random number between min and max (inclusive)
          random_number = :rand.uniform(max - min + 1) + min - 1

          {:ok,
           %{
             "executionId" => execution_id,
             "content" => [
               %{
                 "type" => "text",
                 "text" => "Random number between #{min} and #{max}: #{random_number}"
               }
             ]
           }}
        end
      }
    })
  end

  defp register_example_sampling do
    # Register sampling capability
    Mcpex.Registry.register(:sampling_registry, Mcpex.Capabilities.Sampling, %{
      models: [
        %{
          "id" => "default",
          "name" => "Default Model",
          "description" => "Default language model for text generation",
          "supportedSamplingParameters" => [
            "temperature",
            "topP",
            "maxTokens"
          ]
        }
      ]
    })
  end
end

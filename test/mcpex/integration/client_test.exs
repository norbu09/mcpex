defmodule Mcpex.Integration.ClientTest do
  use ExUnit.Case
  require Logger

  @moduledoc """
  Integration tests for the MCP server with an external client.
  
  These tests verify that the MCP server can be used with an external client
  like mcpixir. These tests are marked as :external and can be excluded from
  the normal test run with `mix test --exclude external`.
  """

  @tag :external
  @tag :skip
  @tag timeout: 30_000
  test "can connect with mcpixir client" do
    # Start a server for the test
    {:ok, server_pid} = start_test_server()
    
    # Register test data
    register_test_data()
    
    # Use mcpixir to connect to the server
    # Note: This requires mcpixir to be installed
    # You can install it with: mix deps.get
    if Code.ensure_loaded?(Mcpixir) do
      # Configure mcpixir client
      client_config = %{
        base_url: "http://localhost:4000/mcp",
        headers: []
      }
      
      # Initialize the client
      {:ok, client} = Mcpixir.Http.connect(client_config)
      
      # Test listing resources
      {:ok, resources} = Mcpixir.Http.list_resources(client)
      assert is_list(resources)
      assert length(resources) > 0
      
      # Test reading a resource
      resource = Enum.find(resources, fn r -> r["uri"] == "file://example.txt" end)
      assert resource != nil
      
      {:ok, contents} = Mcpixir.Http.read_resource(client, resource["uri"])
      assert contents == "This is an example text file."
      
      # Test listing prompts
      {:ok, prompts} = Mcpixir.Http.list_prompts(client)
      assert is_list(prompts)
      assert length(prompts) > 0
      
      # Test listing tools
      {:ok, tools} = Mcpixir.Http.list_tools(client)
      assert is_list(tools)
      assert length(tools) > 0
      
      # Test generating text
      {:ok, generation} = Mcpixir.Http.generate_text(client, "Hello, world!")
      assert generation["text"] != nil
      
      # Close the client
      :ok = Mcpixir.Http.close(client)
    else
      Logger.warn("Mcpixir not available, skipping external client test")
      # Skip the test if mcpixir is not available
      assert true
    end
    
    # Stop the test server
    stop_test_server(server_pid)
  end
  
  # Helper functions
  
  defp start_test_server do
    # Start the registry if not already started
    case Process.whereis(Mcpex.Registry) do
      nil -> Registry.start_link(keys: :unique, name: Mcpex.Registry)
      _ -> :ok
    end
    
    # Start the server with all capabilities
    Mcpex.start_with_default_capabilities(name: TestServer)
    
    # Note: We would need to implement a transport layer in the mcpex library
    # to make this test work. For now, we'll skip it.
    {:ok, nil}
  end
  
  defp stop_test_server(_pid) do
    # Stop the server
    GenServer.stop(TestServer)
  end
  
  defp register_test_data do
    # Register tools
    Mcpex.Registry.register(:tools_registry, nil, %{
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
        }
      ]
    })
    
    # Register tool executors
    Mcpex.Registry.register(:tool_executors, nil, %{
      executors: %{
        "calculator" => fn arguments ->
          expression = Map.get(arguments, "expression", "")
          execution_id = "exec-#{:erlang.system_time(:millisecond)}"
          
          result = "Result: #{expression} = 42"
          
          {:ok,
           %{
             "executionId" => execution_id,
             "content" => [
               %{
                 "type" => "text",
                 "text" => result
               }
             ]
           }}
        end
      }
    })
    
    # Register prompts
    Mcpex.Registry.register(:prompts_registry, nil, %{
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
        }
      ]
    })
    
    # Register individual prompts
    Mcpex.Registry.register({:prompt, "greeting"}, nil, %{
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
    })
    
    # Register resources
    Mcpex.Registry.register(:resources_registry, nil, %{
      resources: [
        %{"uri" => "file://example.txt", "name" => "Example File", "mimeType" => "text/plain"}
      ]
    })
    
    # Register resource content
    Mcpex.Registry.register({:resource_content, "file://example.txt"}, nil, %{
      content: "This is an example text file."
    })
  end
end

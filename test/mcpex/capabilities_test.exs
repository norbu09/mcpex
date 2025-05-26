defmodule Mcpex.CapabilitiesTest do
  use ExUnit.Case
  
  setup do
    # Clean up any existing registry entries
    cleanup_registry()
    
    # Register test data directly
    register_test_data()
    
    :ok
  end
  
  # Helper to clean up registry entries before each test
  defp cleanup_registry do
    # Get all keys in the registry
    keys = Registry.select(Mcpex.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    
    # Unregister each key
    Enum.each(keys, fn key ->
      Registry.unregister(Mcpex.Registry, key)
    end)
  end
  
  # Register test data for capabilities tests
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
        },
        %{
          "name" => "weather",
          "description" => "Get weather information for a location",
          "argumentSchema" => %{
            "type" => "object",
            "properties" => %{
              "location" => %{
                "type" => "string",
                "description" => "The location to get weather for"
              }
            },
            "required" => ["location"]
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
          
          # This is a simplified example - in a real implementation, you would
          # validate the expression and use a proper parser/evaluator
          result = case Code.string_to_quoted(expression) do
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
          
          {:ok, %{
            "executionId" => execution_id,
            "content" => [%{
              "type" => "text",
              "text" => "Result: #{result}"
            }]
          }}
        end,
        
        "weather" => fn arguments ->
          location = Map.get(arguments, "location", "")
          execution_id = "exec-#{:erlang.system_time(:millisecond)}"
          
          # In a real implementation, you would call a weather API
          {:ok, %{
            "executionId" => execution_id,
            "content" => [%{
              "type" => "text",
              "text" => "Weather for #{location}: Sunny, 25°C"
            }]
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
    
    Mcpex.Registry.register({:prompt, "summary"}, nil, %{
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
    })
    
    # Register resources
    Mcpex.Registry.register(:resources_registry, nil, %{
      resources: [
        %{"uri" => "file://example.txt", "name" => "Example File", "mimeType" => "text/plain"},
        %{"uri" => "file://example.json", "name" => "Example JSON", "mimeType" => "application/json"}
      ]
    })
    
    # Register resource contents
    Mcpex.Registry.register({:resource_content, "file://example.txt"}, nil, %{
      content: "This is an example text file."
    })
    
    Mcpex.Registry.register({:resource_content, "file://example.json"}, nil, %{
      content: ~s({"example": "This is an example JSON file."})
    })
  end
  
  describe "Tools capability" do
    test "lists tools from registry" do
      # Get tools
      tools = Mcpex.Capabilities.Tools.handle_request("tools/list", %{}, "test-session")
      
      # Verify result
      assert {:ok, %{"tools" => tools_list}} = tools
      assert length(tools_list) == 2
      assert Enum.any?(tools_list, fn tool -> tool["name"] == "calculator" end)
      assert Enum.any?(tools_list, fn tool -> tool["name"] == "weather" end)
    end
    
    test "executes calculator tool" do
      # Execute calculator
      result = Mcpex.Capabilities.Tools.handle_request(
        "tools/execute", 
        %{"name" => "calculator", "arguments" => %{"expression" => "2 + 2"}}, 
        "test-session"
      )
      
      # Verify result
      assert {:ok, %{"executionId" => _id, "content" => [%{"text" => text}]}} = result
      assert String.contains?(text, "Result: 4")
    end
  end
  
  describe "Prompts capability" do
    test "lists prompts from registry" do
      # Get prompts
      prompts = Mcpex.Capabilities.Prompts.handle_request("prompts/list", %{}, "test-session")
      
      # Verify result
      assert {:ok, %{"prompts" => prompts_list}} = prompts
      assert length(prompts_list) == 2
      assert Enum.any?(prompts_list, fn prompt -> prompt["name"] == "greeting" end)
      assert Enum.any?(prompts_list, fn prompt -> prompt["name"] == "summary" end)
    end
    
    test "gets specific prompt" do
      # Get greeting prompt
      result = Mcpex.Capabilities.Prompts.handle_request(
        "prompts/get", 
        %{"name" => "greeting"}, 
        "test-session"
      )
      
      # Verify result
      assert {:ok, %{"prompt" => prompt}} = result
      assert prompt["name"] == "greeting"
      assert prompt["template"] == "Hello, {{name}}!"
    end
  end
  
  describe "Resources capability" do
    test "lists resources from registry" do
      # Get resources
      resources = Mcpex.Capabilities.Resources.handle_request("resources/list", %{}, "test-session")
      
      # Verify result
      assert {:ok, %{"resources" => resources_list}} = resources
      assert length(resources_list) == 2
      assert Enum.any?(resources_list, fn resource -> resource["uri"] == "file://example.txt" end)
      assert Enum.any?(resources_list, fn resource -> resource["uri"] == "file://example.json" end)
    end
    
    test "reads resource content" do
      # Read text file
      result = Mcpex.Capabilities.Resources.handle_request(
        "resources/read", 
        %{"uri" => "file://example.txt"}, 
        "test-session"
      )
      
      # Verify result
      assert {:ok, %{"contents" => [%{"uri" => "file://example.txt", "text" => content}]}} = result
      assert content == "This is an example text file."
    end
  end
end
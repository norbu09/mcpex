defmodule Mcpex.TestSupport.DemoData do
  @moduledoc """
  Demo data for testing and examples.
  
  This module provides sample data for tools, prompts, and resources
  that can be used in tests and examples.
  """
  
  @doc """
  Registers demo tools in the registry.
  """
  def register_demo_tools do
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
  end
  
  @doc """
  Registers demo prompts in the registry.
  """
  def register_demo_prompts do
    # Register prompt list
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
  end
  
  @doc """
  Registers demo resources in the registry.
  """
  def register_demo_resources do
    # Register resource list
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
  
  @doc """
  Registers all demo data in the registry.
  """
  def register_all do
    register_demo_tools()
    register_demo_prompts()
    register_demo_resources()
  end
end
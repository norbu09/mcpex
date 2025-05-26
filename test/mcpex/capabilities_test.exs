defmodule Mcpex.CapabilitiesTest do
  use ExUnit.Case
  
  alias Mcpex.DemoData
  
  setup do
    # Start the registry
    {:ok, _} = Registry.start_link(keys: :unique, name: Mcpex.Registry)
    
    # Register demo data
    DemoData.register_all()
    
    :ok
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
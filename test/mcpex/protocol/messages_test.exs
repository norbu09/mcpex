defmodule Mcpex.Protocol.MessagesTest do
  use ExUnit.Case, async: true

  alias Mcpex.Protocol.Messages

  describe "protocol_version/0" do
    test "returns current protocol version" do
      assert Messages.protocol_version() == "2025-03-26"
    end
  end

  describe "initialize_request/3" do
    test "creates valid initialize request" do
      client_info = %{name: "test-client", version: "1.0.0"}
      capabilities = %{resources: %{}, tools: %{}}

      request = Messages.initialize_request(client_info, capabilities, "1")

      assert %{
               jsonrpc: "2.0",
               method: "initialize",
               params: %{
                 protocolVersion: "2025-03-26",
                 capabilities: %{
                   resources: %{},
                   prompts: nil,
                   tools: %{},
                   sampling: nil
                 },
                 clientInfo: %{name: "test-client", version: "1.0.0"}
               },
               id: "1"
             } = request
    end
  end

  describe "initialize_response/3" do
    test "creates valid initialize response" do
      server_info = %{name: "test-server", version: "1.0.0"}
      capabilities = %{resources: %{}, prompts: %{}}

      response = Messages.initialize_response(server_info, capabilities, "1")

      assert %{
               jsonrpc: "2.0",
               result: %{
                 protocolVersion: "2025-03-26",
                 capabilities: %{
                   resources: %{},
                   prompts: %{},
                   tools: nil,
                   sampling: nil
                 },
                 serverInfo: %{name: "test-server", version: "1.0.0"}
               },
               id: "1"
             } = response
    end
  end

  describe "initialized_notification/0" do
    test "creates initialized notification" do
      notification = Messages.initialized_notification()

      assert %{
               jsonrpc: "2.0",
               method: "initialized"
             } = notification

      refute Map.has_key?(notification, :id)
    end
  end

  describe "resource messages" do
    test "list_resources_request/1 creates correct request" do
      request = Messages.list_resources_request("1")

      assert %{
               jsonrpc: "2.0",
               method: "resources/list",
               id: "1"
             } = request
    end

    test "read_resource_request/2 creates correct request" do
      request = Messages.read_resource_request("file://test.txt", "2")

      assert %{
               jsonrpc: "2.0",
               method: "resources/read",
               params: %{uri: "file://test.txt"},
               id: "2"
             } = request
    end

    test "resources_list_changed_notification/0 creates correct notification" do
      notification = Messages.resources_list_changed_notification()

      assert %{
               jsonrpc: "2.0",
               method: "notifications/resources/list_changed"
             } = notification

      refute Map.has_key?(notification, :id)
    end
  end

  describe "prompt messages" do
    test "list_prompts_request/1 creates correct request" do
      request = Messages.list_prompts_request("1")

      assert %{
               jsonrpc: "2.0",
               method: "prompts/list",
               id: "1"
             } = request
    end

    test "get_prompt_request/3 creates correct request with arguments" do
      arguments = %{template: "greeting", name: "World"}
      request = Messages.get_prompt_request("hello", arguments, "2")

      assert %{
               jsonrpc: "2.0",
               method: "prompts/get",
               params: %{
                 name: "hello",
                 arguments: %{template: "greeting", name: "World"}
               },
               id: "2"
             } = request
    end

    test "get_prompt_request/3 creates correct request without arguments" do
      request = Messages.get_prompt_request("hello", %{}, "2")

      assert %{
               jsonrpc: "2.0",
               method: "prompts/get",
               params: %{name: "hello"},
               id: "2"
             } = request

      refute Map.has_key?(request.params, :arguments)
    end

    test "prompts_list_changed_notification/0 creates correct notification" do
      notification = Messages.prompts_list_changed_notification()

      assert %{
               jsonrpc: "2.0",
               method: "notifications/prompts/list_changed"
             } = notification

      refute Map.has_key?(notification, :id)
    end
  end

  describe "tool messages" do
    test "list_tools_request/1 creates correct request" do
      request = Messages.list_tools_request("1")

      assert %{
               jsonrpc: "2.0",
               method: "tools/list",
               id: "1"
             } = request
    end

    test "call_tool_request/3 creates correct request with arguments" do
      arguments = %{text: "Hello, World!"}
      request = Messages.call_tool_request("echo", arguments, "2")

      assert %{
               jsonrpc: "2.0",
               method: "tools/call",
               params: %{
                 name: "echo",
                 arguments: %{text: "Hello, World!"}
               },
               id: "2"
             } = request
    end

    test "call_tool_request/3 creates correct request without arguments" do
      request = Messages.call_tool_request("ping", %{}, "2")

      assert %{
               jsonrpc: "2.0",
               method: "tools/call",
               params: %{name: "ping"},
               id: "2"
             } = request

      refute Map.has_key?(request.params, :arguments)
    end

    test "tools_list_changed_notification/0 creates correct notification" do
      notification = Messages.tools_list_changed_notification()

      assert %{
               jsonrpc: "2.0",
               method: "notifications/tools/list_changed"
             } = notification

      refute Map.has_key?(notification, :id)
    end
  end

  describe "validate_initialize_params/1" do
    test "validates correct initialize params" do
      params = %{
        protocolVersion: "2025-03-26",
        capabilities: %{resources: %{}},
        clientInfo: %{name: "test", version: "1.0"}
      }

      assert {:ok, validated} = Messages.validate_initialize_params(params)
      assert validated.protocolVersion == "2025-03-26"
      assert validated.clientInfo.name == "test"
      assert validated.capabilities.resources == %{}
    end

    test "validates with minimal client info" do
      params = %{
        protocolVersion: "2025-03-26",
        capabilities: %{},
        clientInfo: %{name: "test"}
      }

      assert {:ok, validated} = Messages.validate_initialize_params(params)
      assert validated.clientInfo.version == "unknown"
    end

    test "rejects missing protocol version" do
      params = %{
        capabilities: %{},
        clientInfo: %{name: "test", version: "1.0"}
      }

      assert {:error, "Missing protocolVersion"} = Messages.validate_initialize_params(params)
    end

    test "rejects missing client info" do
      params = %{
        protocolVersion: "2025-03-26",
        capabilities: %{}
      }

      assert {:error, "Missing clientInfo"} = Messages.validate_initialize_params(params)
    end

    test "rejects non-object params" do
      assert {:error, "Initialize params must be an object"} =
               Messages.validate_initialize_params("invalid")
    end
  end

  describe "validate_capabilities/1" do
    test "validates capabilities object" do
      params = %{capabilities: %{resources: %{}, tools: %{}}}

      assert {:ok, capabilities} = Messages.validate_capabilities(params)
      assert capabilities.resources == %{}
      assert capabilities.tools == %{}
      assert capabilities.prompts == nil
      assert capabilities.sampling == nil
    end

    test "validates empty capabilities" do
      params = %{}

      assert {:ok, capabilities} = Messages.validate_capabilities(params)
      assert capabilities.resources == nil
      assert capabilities.prompts == nil
      assert capabilities.tools == nil
      assert capabilities.sampling == nil
    end

    test "handles string keys in capabilities" do
      params = %{capabilities: %{"resources" => %{}, "tools" => %{}}}

      assert {:ok, capabilities} = Messages.validate_capabilities(params)
      assert capabilities.resources == %{}
      assert capabilities.tools == %{}
    end
  end
end

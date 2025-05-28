defmodule Mcpex.Capabilities.SamplingTest do
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

  # Register test data for sampling tests
  defp register_test_data do
    # No specific registry data needed for basic sampling tests
    :ok
  end

  describe "Sampling capability" do
    test "supports any client capabilities" do
      assert Mcpex.Capabilities.Sampling.supports?(%{})
    end

    test "provides server capabilities" do
      capabilities = Mcpex.Capabilities.Sampling.get_server_capabilities(%{})
      
      assert capabilities["supportsStreaming"] == true
      assert is_list(capabilities["supportedModels"])
      
      # Check that at least one model is defined
      assert length(capabilities["supportedModels"]) > 0
      
      # Check the default model
      default_model = Enum.find(capabilities["supportedModels"], fn model -> model["id"] == "default" end)
      assert default_model != nil
      assert default_model["name"] == "Default Model"
      assert is_list(default_model["supportedSamplingParameters"])
    end

    test "generates text with default parameters" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/generate", 
        %{"prompt" => "Hello, world!"}, 
        "test-session"
      )

      assert {:ok, response} = result
      assert response["generationId"] != nil
      assert response["text"] != nil
      assert response["usage"] != nil
      assert response["usage"]["promptTokens"] > 0
      assert response["usage"]["completionTokens"] > 0
      assert response["usage"]["totalTokens"] > 0
    end

    test "generates text with custom parameters" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/generate", 
        %{
          "prompt" => "Hello, world!",
          "modelId" => "default",
          "samplingParameters" => %{
            "temperature" => 0.5,
            "maxTokens" => 50
          }
        }, 
        "test-session"
      )

      assert {:ok, response} = result
      assert response["generationId"] != nil
      assert response["text"] != nil
      assert String.contains?(response["text"], "temperature: 0.5")
      assert String.contains?(response["text"], "max_tokens: 50")
    end

    test "requires prompt parameter for generation" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/generate", 
        %{}, 
        "test-session"
      )

      assert {:error, error} = result
      assert elem(error, 0) == -32602 # Invalid params error code
    end

    test "starts streaming with valid parameters" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/stream", 
        %{"prompt" => "Hello, world!"}, 
        "test-session"
      )

      assert {:ok, response} = result
      assert response["streamId"] != nil
      assert is_binary(response["streamId"])
    end

    test "requires prompt parameter for streaming" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/stream", 
        %{}, 
        "test-session"
      )

      assert {:error, error} = result
      assert elem(error, 0) == -32602 # Invalid params error code
    end

    test "handles cancellation of streaming" do
      # First start a stream
      {:ok, %{"streamId" => stream_id}} = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/stream", 
        %{"prompt" => "Hello, world!"}, 
        "test-session"
      )

      # Then cancel it
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/cancel", 
        %{"streamId" => stream_id}, 
        "test-session"
      )

      assert {:ok, _} = result
    end

    test "requires streamId parameter for cancellation" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/cancel", 
        %{}, 
        "test-session"
      )

      assert {:error, error} = result
      assert elem(error, 0) == -32602 # Invalid params error code
    end

    test "returns method not found for unknown methods" do
      result = Mcpex.Capabilities.Sampling.handle_request(
        "sampling/unknown", 
        %{}, 
        "test-session"
      )

      assert {:error, error} = result
      assert elem(error, 0) == -32601 # Method not found error code
    end
  end
end

defmodule Mcpex.Capabilities.Sampling do
  @moduledoc """
  Sampling capability implementation.

  This module implements the sampling capability, which allows clients to:
  - Generate text using an LLM
  - Stream responses
  - Control sampling parameters
  """

  @behaviour Mcpex.Capabilities.Behaviour

  require Logger
  alias Mcpex.Protocol.Errors

  # Capability behaviour implementation

  @impl true
  def supports?(_client_capabilities) do
    # Sampling capability is always supported
    true
  end

  @impl true
  def get_server_capabilities(_config) do
    %{
      "supportsStreaming" => true,
      "supportedModels" => [
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
    }
  end

  @impl true
  def handle_request(method, params, session_id) do
    case method do
      "sampling/generate" -> handle_generate(params, session_id)
      "sampling/stream" -> handle_stream(params, session_id)
      "sampling/cancel" -> handle_cancel(params, session_id)
      _ -> {:error, Errors.method_not_found()}
    end
  end

  # Request handlers

  defp handle_generate(params, session_id) do
    Logger.info("Generating text for session #{session_id} with params: #{inspect(params)}")

    model_id = Map.get(params, "modelId", "default")
    prompt = Map.get(params, "prompt", "")
    sampling_params = Map.get(params, "samplingParameters", %{})

    if prompt == "" do
      {:error, Errors.invalid_params("Missing required parameter: prompt")}
    else
      # Generate text using the specified model and parameters
      result = generate_text(model_id, prompt, sampling_params, session_id)
      {:ok, result}
    end
  end

  defp handle_stream(params, session_id) do
    Logger.info("Streaming text for session #{session_id} with params: #{inspect(params)}")

    model_id = Map.get(params, "modelId", "default")
    prompt = Map.get(params, "prompt", "")
    sampling_params = Map.get(params, "samplingParameters", %{})

    if prompt == "" do
      {:error, Errors.invalid_params("Missing required parameter: prompt")}
    else
      # Start streaming text generation
      stream_id = start_streaming(model_id, prompt, sampling_params, session_id)
      {:ok, %{"streamId" => stream_id}}
    end
  end

  defp handle_cancel(params, session_id) do
    Logger.info("Cancelling text generation for session #{session_id} with params: #{inspect(params)}")

    stream_id = Map.get(params, "streamId")

    if stream_id do
      # Cancel the streaming text generation
      cancel_streaming(stream_id, session_id)
      {:ok, %{}}
    else
      {:error, Errors.invalid_params("Missing required parameter: streamId")}
    end
  end

  # Helper functions

  defp generate_text(model_id, prompt, sampling_params, _session_id) do
    # In a real implementation, this would call an LLM API
    # For now, we'll just return a simple response
    generation_id = "gen-#{:erlang.system_time(:millisecond)}"

    # Extract sampling parameters
    temperature = Map.get(sampling_params, "temperature", 0.7)
    max_tokens = Map.get(sampling_params, "maxTokens", 100)

    # Generate a simple response based on the prompt
    response_text = "This is a generated response to: #{prompt} (using model: #{model_id}, temperature: #{temperature}, max_tokens: #{max_tokens})"

    %{
      "generationId" => generation_id,
      "text" => response_text,
      "usage" => %{
        "promptTokens" => String.length(prompt) |> div(4),
        "completionTokens" => String.length(response_text) |> div(4),
        "totalTokens" => (String.length(prompt) + String.length(response_text)) |> div(4)
      }
    }
  end

  defp start_streaming(_model_id, prompt, _sampling_params, session_id) do
    # In a real implementation, this would start an LLM streaming process
    # For now, we'll just simulate it with a simple process
    stream_id = "stream-#{:erlang.system_time(:millisecond)}"

    # Register the stream in a registry or ETS table
    # For now, we'll just log it
    Logger.debug("Started stream #{stream_id} for session #{session_id}")

    # In a real implementation, you would start a process to handle the streaming
    # and send chunks to the client as they become available
    spawn(fn -> simulate_streaming(stream_id, prompt, session_id) end)

    stream_id
  end

  defp simulate_streaming(stream_id, prompt, session_id) do
    # This is a simplified simulation of streaming text generation
    # In a real implementation, this would be connected to an LLM API

    # Generate a response in chunks
    chunks = [
      "This is ",
      "a generated ",
      "response ",
      "to: ",
      prompt
    ]

    # Send each chunk with a delay
    Enum.each(chunks, fn chunk ->
      # In a real implementation, you would send this to the client
      # through a notification or other transport mechanism
      Logger.debug("Sending chunk for stream #{stream_id}: #{chunk}")

      # Simulate sending a notification to the client
      Mcpex.Server.notify(
        Mcpex.Server,
        "sampling/chunk",
        %{
          "streamId" => stream_id,
          "chunk" => chunk,
          "isDone" => false
        },
        session_id
      )

      # Simulate processing time
      Process.sleep(500)
    end)

    # Send the final chunk with isDone = true
    Mcpex.Server.notify(
      Mcpex.Server,
      "sampling/chunk",
      %{
        "streamId" => stream_id,
        "chunk" => "",
        "isDone" => true,
        "usage" => %{
          "promptTokens" => String.length(prompt) |> div(4),
          "completionTokens" => Enum.join(chunks, "") |> String.length() |> div(4),
          "totalTokens" => (String.length(prompt) + (Enum.join(chunks, "") |> String.length())) |> div(4)
        }
      },
      session_id
    )

    Logger.debug("Completed stream #{stream_id}")
  end

  defp cancel_streaming(stream_id, _session_id) do
    # In a real implementation, this would cancel the streaming process
    # For now, we'll just log it
    Logger.debug("Cancelled stream #{stream_id}")
    :ok
  end
end

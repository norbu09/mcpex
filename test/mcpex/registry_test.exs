defmodule Mcpex.RegistryTest do
  use ExUnit.Case

  setup do
    # Clean up any existing registry entries
    cleanup_registry()
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

  test "register and lookup capability" do
    # Define a test module
    defmodule TestCapability do
      def supports?(_), do: true
      def get_server_capabilities(_), do: %{"test" => true}
      def handle_request(_, _, _), do: {:ok, %{}}
    end

    # Register the capability
    {:ok, _pid} = Mcpex.Registry.register(:test_capability, TestCapability)

    # Look up the capability
    {:ok, {_pid, %{module: module, config: config}}} = Mcpex.Registry.lookup(:test_capability)

    # Verify the result
    assert module == TestCapability
    assert config == %{}
  end

  test "list capabilities" do
    # Define test modules
    defmodule TestCapability1 do
      def supports?(_), do: true
      def get_server_capabilities(_), do: %{"test1" => true}
      def handle_request(_, _, _), do: {:ok, %{}}
    end

    defmodule TestCapability2 do
      def supports?(_), do: true
      def get_server_capabilities(_), do: %{"test2" => true}
      def handle_request(_, _, _), do: {:ok, %{}}
    end

    # Register the capabilities
    {:ok, _} = Mcpex.Registry.register(:test_capability1, TestCapability1)
    {:ok, _} = Mcpex.Registry.register(:test_capability2, TestCapability2)

    # List the capabilities
    capabilities = Mcpex.Registry.list_capabilities()

    # Verify the result
    assert Map.has_key?(capabilities, :test_capability1)
    assert Map.has_key?(capabilities, :test_capability2)
    assert capabilities[:test_capability1][:module] == TestCapability1
    assert capabilities[:test_capability2][:module] == TestCapability2
  end

  test "unregister capability" do
    # Define a test module
    defmodule TestCapability do
      def supports?(_), do: true
      def get_server_capabilities(_), do: %{"test" => true}
      def handle_request(_, _, _), do: {:ok, %{}}
    end

    # Register the capability
    {:ok, _} = Mcpex.Registry.register(:test_capability, TestCapability)

    # Verify it's registered
    {:ok, _} = Mcpex.Registry.lookup(:test_capability)

    # Unregister the capability
    :ok = Mcpex.Registry.unregister(:test_capability)

    # Verify it's unregistered
    {:error, :not_found} = Mcpex.Registry.lookup(:test_capability)
  end
end

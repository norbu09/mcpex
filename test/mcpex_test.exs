defmodule McpexTest do
  use ExUnit.Case
  doctest Mcpex

  test "can start server" do
    # Just test that the module exists and can be called
    assert function_exported?(Mcpex, :start_server, 1)
  end
end

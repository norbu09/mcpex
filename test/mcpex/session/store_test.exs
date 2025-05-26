defmodule Mcpex.Session.StoreTest do
  use ExUnit.Case, async: false  # Not async due to session store

  alias Mcpex.Session.Store

  setup do
    # Use the same table as the main application
    :ok
  end

  describe "Plug.Session.Store behavior" do
    test "init/1 returns table name" do
      opts = [table: :test_table]
      assert Store.init(opts) == :test_table
    end

    test "init/1 uses default table when not specified" do
      assert Store.init([]) == :mcpex_sessions
    end

    test "put/4 creates new session when session_id is nil" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      session_id = Store.put(nil, nil, session_data, table)

      assert is_binary(session_id)
      assert String.length(session_id) > 0

      # Verify session was stored
      {retrieved_id, retrieved_data} = Store.get(nil, session_id, table)
      assert retrieved_id == session_id
      assert retrieved_data == session_data
    end

    test "put/4 updates existing session" do
      table = :mcpex_sessions
      initial_data = %{"user_id" => "123"}
      updated_data = %{"user_id" => "456", "name" => "John"}

      # Create initial session
      session_id = Store.put(nil, nil, initial_data, table)

      # Update session
      returned_id = Store.put(nil, session_id, updated_data, table)
      assert returned_id == session_id

      # Verify updated data
      {retrieved_id, retrieved_data} = Store.get(nil, session_id, table)
      assert retrieved_id == session_id
      assert retrieved_data == updated_data
    end

    test "get/3 returns {nil, %{}} for non-existent session" do
      table = :mcpex_sessions

      {session_id, session_data} = Store.get(nil, "non-existent", table)
      assert session_id == nil
      assert session_data == %{}
    end

    test "delete/3 removes session" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Verify it exists
      {retrieved_id, _} = Store.get(nil, session_id, table)
      assert retrieved_id == session_id

      # Delete session
      assert Store.delete(nil, session_id, table) == :ok

      # Verify it's gone
      {retrieved_id, retrieved_data} = Store.get(nil, session_id, table)
      assert retrieved_id == nil
      assert retrieved_data == %{}
    end
  end

  describe "MCP session management" do
    test "get_mcp_session/2 returns MCP session data" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Get MCP session data
      {:ok, mcp_data} = Store.get_mcp_session(session_id, table)

      assert mcp_data.id == session_id
      assert mcp_data.transport == :unknown
      assert mcp_data.initialized == false
      assert is_struct(mcp_data.created_at, DateTime)
      assert is_struct(mcp_data.last_activity, DateTime)
    end

    test "get_mcp_session/2 returns error for non-existent session" do
      table = :mcpex_sessions

      assert Store.get_mcp_session("non-existent", table) == {:error, :not_found}
    end

    test "update_mcp_session/3 updates MCP session data" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Update MCP data
      updates = %{transport: :sse, initialized: true}
      assert Store.update_mcp_session(session_id, updates, table) == :ok

      # Verify updates
      {:ok, mcp_data} = Store.get_mcp_session(session_id, table)
      assert mcp_data.transport == :sse
      assert mcp_data.initialized == true
    end

    test "update_mcp_session/3 returns error for non-existent session" do
      table = :mcpex_sessions
      updates = %{transport: :sse}

      assert Store.update_mcp_session("non-existent", updates, table) == {:error, :not_found}
    end

    test "initialize_mcp_session/4 sets client info and capabilities" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Initialize MCP session
      client_info = %{name: "test-client", version: "1.0.0"}
      capabilities = %{resources: %{}, tools: %{}}

      assert Store.initialize_mcp_session(session_id, client_info, capabilities, table) == :ok

      # Verify initialization
      {:ok, mcp_data} = Store.get_mcp_session(session_id, table)
      assert mcp_data.client_info == client_info
      assert mcp_data.capabilities == capabilities
      assert mcp_data.initialized == true
    end

    test "set_transport/3 sets transport type" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Set transport
      assert Store.set_transport(session_id, :streamable_http, table) == :ok

      # Verify transport
      {:ok, mcp_data} = Store.get_mcp_session(session_id, table)
      assert mcp_data.transport == :streamable_http
    end

    test "list_mcp_sessions/1 returns all active sessions" do
      table = :mcpex_sessions

      # Create multiple sessions
      session_id1 = Store.put(nil, nil, %{"user" => "1"}, table)
      session_id2 = Store.put(nil, nil, %{"user" => "2"}, table)

      # Set different transports
      Store.set_transport(session_id1, :sse, table)
      Store.set_transport(session_id2, :streamable_http, table)

      # List sessions
      sessions = Store.list_mcp_sessions(table)

      # Should include our sessions (and possibly others from other tests)
      session_ids = Enum.map(sessions, & &1.id)
      assert session_id1 in session_ids
      assert session_id2 in session_ids

      # Find our specific sessions
      session1 = Enum.find(sessions, &(&1.id == session_id1))
      session2 = Enum.find(sessions, &(&1.id == session_id2))

      assert session1.transport == :sse
      assert session2.transport == :streamable_http
    end
  end

  describe "session activity tracking" do
    test "get/3 updates last activity" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Get initial MCP data
      {:ok, initial_mcp_data} = Store.get_mcp_session(session_id, table)
      initial_activity = initial_mcp_data.last_activity

      # Wait a bit to ensure time difference
      :timer.sleep(10)

      # Access session via get/3
      Store.get(nil, session_id, table)

      # Check if last activity was updated
      {:ok, updated_mcp_data} = Store.get_mcp_session(session_id, table)
      updated_activity = updated_mcp_data.last_activity

      assert DateTime.compare(updated_activity, initial_activity) == :gt
    end

    test "get_mcp_session/2 updates last activity" do
      table = :mcpex_sessions
      session_data = %{"user_id" => "123"}

      # Create session
      session_id = Store.put(nil, nil, session_data, table)

      # Get initial MCP data
      {:ok, initial_mcp_data} = Store.get_mcp_session(session_id, table)
      initial_activity = initial_mcp_data.last_activity

      # Wait a bit to ensure time difference
      :timer.sleep(10)

      # Access session via get_mcp_session/2
      {:ok, updated_mcp_data} = Store.get_mcp_session(session_id, table)
      updated_activity = updated_mcp_data.last_activity

      assert DateTime.compare(updated_activity, initial_activity) == :gt
    end
  end
end

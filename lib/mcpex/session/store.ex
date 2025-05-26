defmodule Mcpex.Session.Store do
  @moduledoc """
  Custom Plug session store for MCP sessions.

  This module implements the Plug.Session.Store behavior to provide
  MCP-specific session management while being fully compatible with
  Plug's session system.

  The store manages both HTTP session data (handled by Plug) and
  MCP-specific metadata like transport type, client info, and capabilities.

  ## Usage

      plug Plug.Session,
        store: Mcpex.Session.Store,
        key: "_mcpex_session",
        table: :mcpex_sessions
  """

  @behaviour Plug.Session.Store

  require Logger

  @type session_id :: String.t()
  @type mcp_session_data :: %{
          transport: atom(),
          created_at: DateTime.t(),
          last_activity: DateTime.t(),
          client_info: map() | nil,
          capabilities: map() | nil,
          initialized: boolean()
        }

  @session_table :mcpex_sessions

  # Plug.Session.Store callbacks

  @impl Plug.Session.Store
  def init(opts) do
    Keyword.get(opts, :table, @session_table)
  end

  @impl Plug.Session.Store
  def get(_conn, session_id, table_name) do
    case :ets.lookup(table_name, session_id) do
      [{^session_id, {session_data, _mcp_data}}] ->
        # Update last activity
        update_last_activity(session_id, table_name)
        {session_id, session_data}

      [] ->
        {nil, %{}}
    end
  end

  @impl Plug.Session.Store
  def put(_conn, nil, session_data, table_name) do
    # Create new session
    session_id = generate_session_id()
    mcp_data = %{
      transport: :unknown,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      client_info: nil,
      capabilities: nil,
      initialized: false
    }

    :ets.insert(table_name, {session_id, {session_data, mcp_data}})
    Logger.debug("Created new session #{session_id}")
    session_id
  end

  @impl Plug.Session.Store
  def put(_conn, session_id, session_data, table_name) do
    case :ets.lookup(table_name, session_id) do
      [{^session_id, {_old_session_data, mcp_data}}] ->
        updated_mcp_data = Map.put(mcp_data, :last_activity, DateTime.utc_now())
        :ets.insert(table_name, {session_id, {session_data, updated_mcp_data}})
        session_id

      [] ->
        # Session doesn't exist, create new one
        put(nil, nil, session_data, table_name)
    end
  end

  @impl Plug.Session.Store
  def delete(_conn, session_id, table_name) do
    :ets.delete(table_name, session_id)
    Logger.debug("Deleted session #{session_id}")
    :ok
  end

  # MCP-specific session management functions

  @doc """
  Get MCP session data for a session ID.
  """
  @spec get_mcp_session(session_id(), atom()) :: {:ok, mcp_session_data()} | {:error, :not_found}
  def get_mcp_session(session_id, table_name \\ @session_table) do
    case :ets.lookup(table_name, session_id) do
      [{^session_id, {_session_data, mcp_data}}] ->
        update_last_activity(session_id, table_name)
        {:ok, Map.put(mcp_data, :id, session_id)}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Update MCP session data.
  """
  @spec update_mcp_session(session_id(), map(), atom()) :: :ok | {:error, :not_found}
  def update_mcp_session(session_id, updates, table_name \\ @session_table) do
    case :ets.lookup(table_name, session_id) do
      [{^session_id, {session_data, mcp_data}}] ->
        updated_mcp_data =
          mcp_data
          |> Map.merge(updates)
          |> Map.put(:last_activity, DateTime.utc_now())

        :ets.insert(table_name, {session_id, {session_data, updated_mcp_data}})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Initialize MCP session with client info and capabilities.
  """
  @spec initialize_mcp_session(session_id(), map(), map(), atom()) :: :ok | {:error, :not_found}
  def initialize_mcp_session(session_id, client_info, capabilities, table_name \\ @session_table) do
    updates = %{
      client_info: client_info,
      capabilities: capabilities,
      initialized: true
    }
    update_mcp_session(session_id, updates, table_name)
  end

  @doc """
  Set the transport type for a session.
  """
  @spec set_transport(session_id(), atom(), atom()) :: :ok | {:error, :not_found}
  def set_transport(session_id, transport, table_name \\ @session_table) do
    update_mcp_session(session_id, %{transport: transport}, table_name)
  end

  @doc """
  List all active MCP sessions.
  """
  @spec list_mcp_sessions(atom()) :: [mcp_session_data()]
  def list_mcp_sessions(table_name \\ @session_table) do
    :ets.tab2list(table_name)
    |> Enum.map(fn {session_id, {_session_data, mcp_data}} ->
      Map.put(mcp_data, :id, session_id)
    end)
  end

  # Private functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  defp update_last_activity(session_id, table_name) do
    case :ets.lookup(table_name, session_id) do
      [{^session_id, {session_data, mcp_data}}] ->
        updated_mcp_data = Map.put(mcp_data, :last_activity, DateTime.utc_now())
        :ets.insert(table_name, {session_id, {session_data, updated_mcp_data}})

      [] ->
        :ok
    end
  end
end

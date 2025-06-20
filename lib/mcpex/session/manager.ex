defmodule Mcpex.Session.Manager do
  @moduledoc """
  Session manager for MCP connections.

  This module provides session management capabilities that integrate with
  Plug's session handling. It manages MCP session state, including:

  - Session creation and validation
  - Session storage and retrieval
  - Session cleanup and expiration
  - Integration with transport layers

  The session manager uses ETS for fast in-memory storage and integrates
  with Plug's session management for HTTP session handling.
  """

  use GenServer
  require Logger

  alias Mcpex.Transport.Behaviour
  alias Plug.Conn

  @type session_id :: String.t()
  @type session_data :: %{
          id: session_id(),
          transport: atom(),
          created_at: DateTime.t(),
          last_activity: DateTime.t(),
          client_info: map() | nil,
          capabilities: map() | nil,
          initialized: boolean()
        }

  @session_table :mcpex_sessions
  @cleanup_interval :timer.minutes(5)
  @session_timeout :timer.hours(1)

  # Client API

  @doc """
  Start the session manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a new session.
  """
  @spec create_session(atom(), map()) :: {:ok, session_id()} | {:error, term()}
  def create_session(transport, opts \\ %{}) do
    GenServer.call(__MODULE__, {:create_session, transport, opts})
  end

  @doc """
  Get session data by ID.
  """
  @spec get_session(session_id()) :: {:ok, session_data()} | {:error, :not_found}
  def get_session(session_id) do
    case :ets.lookup(@session_table, session_id) do
      [{^session_id, session_data}] ->
        # Update last activity
        update_last_activity(session_id)
        {:ok, session_data}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Update session data.
  """
  @spec update_session(session_id(), map()) :: :ok | {:error, :not_found}
  def update_session(session_id, updates) do
    GenServer.call(__MODULE__, {:update_session, session_id, updates})
  end

  @doc """
  Mark session as initialized with client info and capabilities.
  """
  @spec initialize_session(session_id(), map(), map()) :: :ok | {:error, :not_found}
  def initialize_session(session_id, client_info, capabilities) do
    updates = %{
      client_info: client_info,
      capabilities: capabilities,
      initialized: true
    }

    update_session(session_id, updates)
  end

  @doc """
  Delete a session.
  """
  @spec delete_session(session_id()) :: :ok
  def delete_session(session_id) do
    GenServer.call(__MODULE__, {:delete_session, session_id})
  end

  @doc """
  List all active sessions.
  """
  @spec list_sessions() :: [session_data()]
  def list_sessions do
    :ets.tab2list(@session_table)
    |> Enum.map(fn {_id, session_data} -> session_data end)
  end

  @doc """
  Get session ID from Plug connection.

  This function integrates with Plug's session handling to extract or create
  a session ID. It first checks for the MCP-Session-Id header, then falls back
  to Plug's session management.
  """
  @spec get_session_id_from_conn(Conn.t()) :: {session_id() | nil, Conn.t()}
  def get_session_id_from_conn(conn) do
    # First check for MCP-Session-Id header (for Streamable HTTP)
    case Conn.get_req_header(conn, "mcp-session-id") do
      [session_id] when is_binary(session_id) and session_id != "" ->
        {session_id, conn}

      _ ->
        # Fall back to Plug session or create new
        case Conn.get_session(conn, "mcp_session_id") do
          nil ->
            # Create new session ID
            session_id = Behaviour.generate_session_id()
            conn = Conn.put_session(conn, "mcp_session_id", session_id)
            {session_id, conn}

          session_id ->
            {session_id, conn}
        end
    end
  end

  @doc """
  Set session ID in Plug connection.
  """
  @spec put_session_id_in_conn(Conn.t(), session_id()) :: Conn.t()
  def put_session_id_in_conn(conn, session_id) do
    conn
    |> Conn.put_session("mcp_session_id", session_id)
    |> Conn.put_resp_header("mcp-session-id", session_id)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for session storage
    :ets.new(@session_table, [:named_table, :public, :set, {:read_concurrency, true}])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("MCP Session Manager started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_session, transport, opts}, _from, state) do
    session_id = Behaviour.generate_session_id()
    now = DateTime.utc_now()

    session_data = %{
      id: session_id,
      transport: transport,
      created_at: now,
      last_activity: now,
      client_info: Map.get(opts, :client_info),
      capabilities: Map.get(opts, :capabilities),
      initialized: false
    }

    :ets.insert(@session_table, {session_id, session_data})

    Logger.debug("Created session #{session_id} for transport #{transport}")
    {:reply, {:ok, session_id}, state}
  end

  @impl true
  def handle_call({:update_session, session_id, updates}, _from, state) do
    case :ets.lookup(@session_table, session_id) do
      [{^session_id, session_data}] ->
        updated_data =
          session_data
          |> Map.merge(updates)
          |> Map.put(:last_activity, DateTime.utc_now())

        :ets.insert(@session_table, {session_id, updated_data})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:delete_session, session_id}, _from, state) do
    :ets.delete(@session_table, session_id)
    Logger.debug("Deleted session #{session_id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup_sessions, state) do
    cleanup_expired_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp update_last_activity(session_id) do
    case :ets.lookup(@session_table, session_id) do
      [{^session_id, session_data}] ->
        updated_data = Map.put(session_data, :last_activity, DateTime.utc_now())
        :ets.insert(@session_table, {session_id, updated_data})

      [] ->
        :ok
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_sessions, @cleanup_interval)
  end

  defp cleanup_expired_sessions do
    now = DateTime.utc_now()
    timeout_threshold = DateTime.add(now, -@session_timeout, :millisecond)

    expired_sessions =
      :ets.tab2list(@session_table)
      |> Enum.filter(fn {_id, session_data} ->
        DateTime.compare(session_data.last_activity, timeout_threshold) == :lt
      end)

    Enum.each(expired_sessions, fn {session_id, _session_data} ->
      :ets.delete(@session_table, session_id)
      Logger.debug("Cleaned up expired session #{session_id}")
    end)

    if length(expired_sessions) > 0 do
      Logger.info("Cleaned up #{length(expired_sessions)} expired sessions")
    end
  end
end

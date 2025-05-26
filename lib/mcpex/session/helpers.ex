defmodule Mcpex.Session.Helpers do
  @moduledoc """
  Helper functions for working with MCP sessions in Plug connections.

  This module provides convenience functions for managing MCP sessions
  that integrate seamlessly with Plug's session system.
  """

  alias Mcpex.Session.Store
  alias Plug.Conn

  @type session_id :: String.t()

  @doc """
  Get the session ID from a Plug connection.

  This function extracts the session ID from either the MCP-Session-Id header
  (for Streamable HTTP) or from the Plug session.
  """
  @spec get_session_id(Conn.t()) :: session_id() | nil
  def get_session_id(conn) do
    # First check for MCP-Session-Id header (for Streamable HTTP)
    case Conn.get_req_header(conn, "mcp-session-id") do
      [session_id] when is_binary(session_id) and session_id != "" ->
        session_id

      _ ->
        # Fall back to Plug session
        Conn.get_session(conn, "session_id")
    end
  end

  @doc """
  Ensure a session exists and return the session ID.

  If no session exists, a new one will be created.
  """
  @spec ensure_session(Conn.t()) :: {session_id(), Conn.t()}
  def ensure_session(conn) do
    case get_session_id(conn) do
      nil ->
        # Create new session by putting empty data
        conn = Conn.put_session(conn, "session_id", "new")
        session_id = Conn.get_session(conn, "session_id")
        {session_id, conn}

      session_id ->
        {session_id, conn}
    end
  end

  @doc """
  Set the session ID in the connection response headers.

  This adds the MCP-Session-Id header for Streamable HTTP compatibility.
  """
  @spec put_session_header(Conn.t(), session_id()) :: Conn.t()
  def put_session_header(conn, session_id) do
    Conn.put_resp_header(conn, "mcp-session-id", session_id)
  end

  @doc """
  Get MCP session data for the current connection.
  """
  @spec get_mcp_session(Conn.t()) :: {:ok, Store.mcp_session_data()} | {:error, :not_found}
  def get_mcp_session(conn) do
    case get_session_id(conn) do
      nil -> {:error, :not_found}
      session_id -> Store.get_mcp_session(session_id)
    end
  end

  @doc """
  Update MCP session data for the current connection.
  """
  @spec update_mcp_session(Conn.t(), map()) :: :ok | {:error, :not_found}
  def update_mcp_session(conn, updates) do
    case get_session_id(conn) do
      nil -> {:error, :not_found}
      session_id -> Store.update_mcp_session(session_id, updates)
    end
  end

  @doc """
  Initialize MCP session with client info and capabilities.
  """
  @spec initialize_mcp_session(Conn.t(), map(), map()) :: :ok | {:error, :not_found}
  def initialize_mcp_session(conn, client_info, capabilities) do
    case get_session_id(conn) do
      nil -> {:error, :not_found}
      session_id -> Store.initialize_mcp_session(session_id, client_info, capabilities)
    end
  end

  @doc """
  Set the transport type for the current session.
  """
  @spec set_transport(Conn.t(), atom()) :: :ok | {:error, :not_found}
  def set_transport(conn, transport) do
    case get_session_id(conn) do
      nil -> {:error, :not_found}
      session_id -> Store.set_transport(session_id, transport)
    end
  end
end

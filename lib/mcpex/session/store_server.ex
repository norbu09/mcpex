defmodule Mcpex.Session.StoreServer do
  @moduledoc """
  GenServer for managing MCP session cleanup and ETS table lifecycle.

  This module is separate from the Plug.Session.Store implementation
  to avoid behavior conflicts.
  """

  use GenServer
  require Logger

  @session_table :mcpex_sessions
  @cleanup_interval :timer.minutes(5)
  @session_timeout :timer.hours(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    table_name = Keyword.get(opts, :table, @session_table)

    # Create ETS table for session storage
    :ets.new(table_name, [:named_table, :public, :set, {:read_concurrency, true}])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("MCP Session Store Server started with table #{table_name}")
    {:ok, %{table: table_name}}
  end

  @impl GenServer
  def handle_info(:cleanup_sessions, %{table: table_name} = state) do
    cleanup_expired_sessions(table_name)
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_sessions, @cleanup_interval)
  end

  defp cleanup_expired_sessions(table_name) do
    now = DateTime.utc_now()
    timeout_threshold = DateTime.add(now, -@session_timeout, :millisecond)

    expired_sessions =
      :ets.tab2list(table_name)
      |> Enum.filter(fn {_session_id, {_session_data, mcp_data}} ->
        DateTime.compare(mcp_data.last_activity, timeout_threshold) == :lt
      end)

    Enum.each(expired_sessions, fn {session_id, _data} ->
      :ets.delete(table_name, session_id)
      Logger.debug("Cleaned up expired session #{session_id}")
    end)

    if length(expired_sessions) > 0 do
      Logger.info("Cleaned up #{length(expired_sessions)} expired sessions")
    end
  end
end

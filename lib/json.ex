defmodule JSON.DecodeError do
  @moduledoc """
  Error raised when JSON decoding fails.
  """
  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    "JSON decode error: #{inspect(reason)}"
  end
end

defmodule JSON.EncodeError do
  @moduledoc """
  Error raised when JSON encoding fails.
  """
  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    "JSON encode error: #{inspect(reason)}"
  end
end

defmodule JSON do
  @moduledoc """
  A wrapper around Jason for JSON encoding and decoding.

  This module is intended to be used as a temporary solution until the project
  can be migrated to Elixir 1.18, which includes a built-in JSON module.

  Once the project is migrated to Elixir 1.18, this module should be removed
  and all references should use the built-in JSON module.
  """

  @doc """
  Decodes a JSON string into an Elixir term.

  ## Examples

      iex> JSON.decode(~s({"name": "John"}))
      {:ok, %{"name" => "John"}}

      iex> JSON.decode("invalid")
      {:error, %JSON.DecodeError{}}
  """
  def decode(json) do
    case Jason.decode(json) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, %JSON.DecodeError{reason: error.data}}
    end
  end

  @doc """
  Decodes a JSON string into an Elixir term, raising an exception on error.

  ## Examples

      iex> JSON.decode!(~s({"name": "John"}))
      %{"name" => "John"}
  """
  def decode!(json) do
    Jason.decode!(json)
  end

  @doc """
  Encodes an Elixir term into a JSON string.

  ## Examples

      iex> JSON.encode(%{name: "John"})
      {:ok, ~s({"name":"John"})}
  """
  def encode(term) do
    case Jason.encode(term) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, %JSON.EncodeError{reason: error}}
    end
  end

  @doc """
  Encodes an Elixir term into a JSON string, raising an exception on error.

  ## Examples

      iex> JSON.encode!(%{name: "John"})
      ~s({"name":"John"})
  """
  def encode!(term) do
    Jason.encode!(term)
  end
end

defmodule JSON.DecodeError do
  @moduledoc """
  Error raised when JSON decoding fails.
  """
  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    "JSON decode error: #{inspect(reason)}"
  end
end

defmodule JSON.EncodeError do
  @moduledoc """
  Error raised when JSON encoding fails.
  """
  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    "JSON encode error: #{inspect(reason)}"
  end
end
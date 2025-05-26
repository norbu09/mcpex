defmodule JSON do
  @moduledoc """
  A wrapper around Jason to simulate the built-in JSON module in Elixir 1.18.
  
  This module provides the same interface as the built-in JSON module in Elixir 1.18,
  but delegates to Jason for the actual implementation.
  """

  @doc """
  Encodes an Elixir value into a JSON string.
  """
  @spec encode(term) :: {:ok, String.t()} | {:error, Jason.EncodeError.t()}
  def encode(value) do
    Jason.encode(value)
  end

  @doc """
  Encodes an Elixir value into a JSON string, raising an exception on error.
  """
  @spec encode!(term) :: String.t() | no_return
  def encode!(value) do
    Jason.encode!(value)
  end

  @doc """
  Decodes a JSON string into an Elixir value.
  """
  @spec decode(String.t()) :: {:ok, term} | {:error, Jason.DecodeError.t()}
  def decode(string) do
    Jason.decode(string)
  end

  @doc """
  Decodes a JSON string into an Elixir value, raising an exception on error.
  """
  @spec decode!(String.t()) :: term | no_return
  def decode!(string) do
    Jason.decode!(string)
  end

  defmodule DecodeError do
    @moduledoc """
    Error raised when JSON decoding fails.
    """
    defexception [:message]
  end

  defmodule EncodeError do
    @moduledoc """
    Error raised when JSON encoding fails.
    """
    defexception [:message]
  end
end
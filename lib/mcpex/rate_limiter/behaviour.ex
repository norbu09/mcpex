defmodule Mcpex.RateLimiter.Behaviour do
  @moduledoc """
  A behaviour for implementing rate limiting strategies.

  This behaviour defines the contract for modules that provide
  rate limiting functionality. It allows for different strategies
  (e.g., token bucket, fixed window, sliding window using libraries like ExRated or custom ETS logic) 
  to be implemented and swapped out.

  An `identifier` is used to track the entity being rate-limited (e.g., a session ID, 
  user ID, or IP address). A `rule_name` (an atom) specifies which configured rate limit 
  rule should be applied, allowing for different limits for different types of actions 
  (e.g., `:default_mcp_request`, `:expensive_tool_call`).
  """

  @typedoc "The state of the rate limiter instance, specific to the implementing strategy."
  @opaque state :: any()

  @typedoc "An identifier for the entity being rate-limited (e.g., session ID, user ID, IP address)."
  @type identifier :: String.t() | atom()

  @typedoc "The name of the rule or context for rate limiting (e.g., :api_request, :login_attempt)."
  @type rule_name :: atom()

  @typedoc """
  Details about the rate limit check.
  For successful checks, may include `:remaining` tokens and an approximate `:reset_at` Unix timestamp.
  For rate-limited checks, may include `:retry_after_seconds` and an exact `:reset_at` Unix timestamp.
  """
  @type limit_details :: %{
    optional(:remaining) => non_neg_integer(),
    optional(:limit) => non_neg_integer(), # Max number of requests for the window
    optional(:reset_at) => non_neg_integer(), # Unix timestamp for when the limit window resets
    optional(:retry_after_seconds) => non_neg_integer(),
    optional(:reason) => String.t() # For non-error cases like unknown rule
  }

  @doc """
  Initializes the rate limiter with given options.
  """
  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, any()}

  @doc """
  Checks if the given identifier is within the defined limits for the rule_name
  and updates the limit state.

  ## Arguments

    * `state`: The current state of the rate limiter.
    * `identifier`: The identifier for the entity to check (e.g., session ID).
    * `rule_name`: The specific rule to apply (e.g., :default_message_limit).

  ## Returns

    * `{:ok, new_state, details}`: If the request is allowed. `details` is a map
      containing information like remaining requests or reset time.
    * `{:error, :rate_limited, new_state, details}`: If the request is denied due
      to rate limiting. `details` contains information like when to retry.
  """
  @callback check_and_update_limit(state :: state(), identifier :: identifier(), rule_name :: rule_name()) ::
              {:ok, new_state :: state(), details :: limit_details()}
              | {:error, :rate_limited, new_state :: state(), details :: limit_details()}
end

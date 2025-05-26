# JSON Usage in MCPEX

## Overview

As of Elixir 1.18, the language includes a built-in `JSON` module that provides standard JSON encoding and decoding functionality. MCPEX uses this built-in module instead of external dependencies like Jason.

## Guidelines

1. **Always use the built-in `JSON` module** for all JSON encoding and decoding operations:

   ```elixir
   # Correct usage
   JSON.encode(data)
   JSON.decode(json_string)
   JSON.encode!(data)
   JSON.decode!(json_string)
   ```

2. **Do not add Jason or other JSON libraries as dependencies**. The built-in `JSON` module provides all necessary functionality.

3. **Error handling**: The `JSON` module provides both safe and bang versions of its functions:
   - Safe versions (`encode/1`, `decode/1`) return tuples like `{:ok, result}` or `{:error, reason}`
   - Bang versions (`encode!/1`, `decode!/1`) return the result directly or raise an exception

## Examples

### Encoding Elixir data to JSON

```elixir
# Safe version with pattern matching
case JSON.encode(data) do
  {:ok, json_string} -> 
    # Handle successful encoding
  {:error, error} -> 
    # Handle encoding error
end

# Bang version (raises on error)
json_string = JSON.encode!(data)
```

### Decoding JSON to Elixir data

```elixir
# Safe version with pattern matching
case JSON.decode(json_string) do
  {:ok, decoded_data} -> 
    # Handle successful decoding
  {:error, error} -> 
    # Handle decoding error
end

# Bang version (raises on error)
decoded_data = JSON.decode!(json_string)
```

## Testing

When running tests on Elixir versions prior to 1.18, the project includes a compatibility module that wraps Jason to provide the same interface as the built-in `JSON` module. This is only for testing purposes and should not be used in production code.
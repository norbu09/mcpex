# Elixir JSON Usage Rules

## JSON Library

We use Elixir 1.18 or later which has built-in support for JSON through the `JSON` library.

**NEVER use Jason** - Always use the built-in `JSON` module.

For details on JSON please refer to: https://hexdocs.pm/elixir/JSON.html

## Usage Examples

### Encoding
```elixir
# Encode to binary
JSON.encode!(data)

# Encode to iodata (more efficient for IO)
JSON.encode_to_iodata!(data)
```

### Decoding
```elixir
# Decode with error handling
case JSON.decode(binary) do
  {:ok, decoded} -> decoded
  {:error, reason} -> handle_error(reason)
end

# Decode with exception on error
JSON.decode!(binary)
```

### Plug Configuration
```elixir
plug(Plug.Parsers, parsers: [:json, :urlencoded, :multipart], json_decoder: JSON)
```

## Error Handling

The `JSON.decode/1` function returns:
- `{:ok, decoded}` on success
- `{:error, reason}` on error

Error reasons include:
- `{:unexpected_end, offset}` - incomplete JSON
- `{:invalid_byte, offset, byte}` - unexpected or invalid UTF-8 byte
- `{:unexpected_sequence, offset, bytes}` - invalid UTF-8 escape 
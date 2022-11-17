# KV Store

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kv_store` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kv_store, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/first_assignment>.

## To run in iex

1. Set port
```bash
export PORT=1234
```

2. Run the following command
```bash
iex --sname name1 -S mix
```

For other nodes, set `PORT` and `--sname` to other values accordingly 

## To run a release

1. Build the release
```bash
MIX_ENV=prod mix release foo
```
```bash
MIX_ENV=prod mix release bar
```

2. Run the release
```bash
_build/prod/rel/foo/bin/foo start
```
```bash
_build/prod/rel/bar/bin/bar start
```

## To run tests

```bash
elixir --sname foo -S mix test apps/kv_server/test/transaction_test.exs
```
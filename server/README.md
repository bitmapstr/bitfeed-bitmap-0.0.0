## Building and Running the Bitfeed API Server

#### Prerequisites
 - [Elixir](https://elixir-lang.org/install.html)
 - [Bitcoin Full Node](https://bitcoin.org/en/full-node)
 	- unpruned
 	- indexed
 	- running in server mode
 	- with ZMQ enabled
 	- [(see an example bitcoin.conf file here)](https://github.com/bitfeed-project/bitfeed/blob/master/server/bitcoin.conf.example)

#### Installation

Set the `MIX_TARGET` environment variable to choose a build target (defaults to "personal")

"personal" - tailored to low traffic personal deployments. resource-intensive features & dependencies disabled

```shell
export MIX_TARGET=personal
```

or

"public" - tailored to high traffic, high performance public deployments.

```shell
export MIX_TARGET=public
```

✅❌

| feature | "public" | "personal" |
|---|---|---|
| Spend index | ✅ | ❌ |



```shell
mix do deps.get
mix do deps.compile
```

#### Configuration

The API server expects the following environment variables to be set:

| variable | usage |
|---|---|
| MIX_ENV | compilation environment, either "prod" or "dev" |
| PORT | Port to expose the API (front end connects to this) |
| LOG_LEVEL | Tailor logging verbosity. either "error", "info" (default) or "debug" |
| RPC_POOLS | Number of connection pools for RPC requests to Bitcoin Core |
| RPC_POOL_SIZE | Number of connections maintained per pool (RPC_POOLS x RPC_POOL_SIZE should be substantially lower than `rpcworkqueue` in bitcoin.conf) |
| TARGET | build target "public" or "personal" |
| BITCOIN_HOST | Bitcoin node host address |
| BITCOIN_ZMQ_RAWBLOCK_PORT | Bitcoin node ZMQ port for block events (to match `zmqpubrawblock` in bitcoin.conf) |
| BITCOIN_ZMQ_RAWTX_PORT | Bitcoin node ZMQ port for transaction events (to match `zmqpubrawtx` in bitcoin.conf) |
| BITCOIN_ZMQ_SEQUENCE_PORT | Bitcoin node ZMQ port for sequence events (to match `zmqpubsequence` in bitcoin.conf) |
| BITCOIN_RPC_PORT | Bitcoin node RPC port |
| either | |
| BITCOIN_RPC_USER | Bitcoin node RPC user |
| BITCOIN_RPC_PASS | Bitcoin node RPC password |
| or | |
| BITCOIN_RPC_COOKIE | absolute path to a Bitcoin node RPC authentication .cookie file |


#### Running in development

Compile and run in an interactive local shell:

```shell
iex -S mix
```

#### Building for production

```shell
mix release
```

#### Running production build

```shell
_build/prod/rel/prod/bin/prod start
```

# Transform

## Install

```
brew install elixir # something similar on linux
mix deps.get
npm install
mix ecto.create
mix ecto.migrate
export AWS_ACCESS_KEY_ID=<your id>
export AWS_SECRET_ACCESS_KEY=<your key>

# set the `transform/blobs/bucket` setting in `config.exs` to an S3 bucket accessible with these creds
```

## Run

```
PORT=4000 iex -S mix phoenix.server
```

## Features

- **Transform script frontend:** Kick off a job from the browser by specifying a transform script and uploading a file.
- **Fast preview:** streams first N (configurable) rows to the browser, while the rest is still uploading and transforming.
- **Dancing histograms:** the backend maintains streaming histogram for each column and sends updates to the browser.
- **S3** Writes basic table chunks to **S3**, (TODO: allowing job to be rerun (e.g. with a different transform or because of a failure) without re-uploading or re-decoding). Also writes results to S3; they can be pulled, diffed, and upserted from there.
- **Transform retry / fault tolerance:** A record is written to Postgres for each basic table chunk received, and it is then marked done when it has been transformed. The `ChunkHerder` polls the database for chunks which have failed to transform, and retries them a configurable number of times. Because of this, if the entire system is killed and restarted, running transforms will finish. (TODO: write aggregator state to a durable store).
- **Backpressure and exponential backoff:** The basic table and transform phases maintain configurable "high water marks" for their work queues, and the stages upstream of them implement exponential backoff. This backpressure extends all the way to reading from the upload socket, ensuring that the memory usage of these stages will remain bounded.
- **Multi-node:** Start up multiple Erlang VMs (see below), each of which runs the phoenix app. If you start a job in the UI served from one, but view that job with the UI served by another, the UI will update since events are being relayed between VMs.

### Multi node

Start a node named socrates
```
  PORT=4000 iex --name socrates@10.0.0.10 --cookie monster -S mix phoenix.server
```
Which will register in zookeeper. Make sure `dev.exs` has the correct zk config. Or change it as appropriate for the environment (test, prod)

Becuase of dockerization/mesos/marathon, we'll need to use zk to manage dynamic cluster membership.

To end the erlang app gracefully and facilitate the removal of the node from zk, don't ctrl+c out of the repl, use `:init.stop` to allow processes to perform cleanup on exit

Start a node named plato
```
  PORT=4001 iex --name plato@10.0.0.10 --cookie monster -S mix phoenix.server
```

You should see log messages from plato indicating that it found socrates and successfully pinged it, which means both the nodes know about each other, and the pg2 groups will be linked.

### Dockerizing
Before you build, make sure the postgres host and zookeeper host are pointing at the correct IP addresses. These values life in `config/prod.exs`

``` docker build --tag=neato```

If the output is `81d74957d398`, then run
```
docker run -p 4000:4000
  -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
  -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
  -it 81d74957d398 iex -S mix phoenix.server
```

Make sure you have the aws creds set

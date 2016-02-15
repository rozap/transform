# Transform

### Multi node

Start a node named socrates
```
  PORT=4000 iex --name socrates@10.0.0.10 --cookie monster -S mix phoenix.server
```
Which will register in zookeeper. Make sure `dev.exs` has the correct zk config. Or change it as appropriate for the environment (test, prod)

Becuase of dockerization/mesos/marathon, we'll need to use zk to manage dynamic cluster membership.

To end the erlang app gracefully and facilitate the removal of the node from zk, don't ctrl+c out of the repl, use `:init.stop` to allow processes to perform cleanup on exit


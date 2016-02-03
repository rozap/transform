// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"
import {
  Socket
}
from "phoenix"


let socket = new Socket("/socket", {
  params: {}
})
socket.connect()



class Transformer {
  constructor() {
    // Now that you are connected, you can join channels with a topic:
    let channel = socket.channel("transform:ffff-ffff", {})
    channel.join()
      .receive("ok", this._onJoin.bind(this))
      .receive("error", this._onError.bind(this));

    channel.on("dataset:row", payload => {
      // console.log(payload)
    })

    channel.on("dataset:header", header => {
      console.log("got the header", header)
    })
  }

  _onJoin(resp) {
    console.log("join with", resp);
  }

  _onError(resp) {
    console.error("error with", resp);
  }
}


new Transformer()
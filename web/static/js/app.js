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

var $ = require('./jquery');

import _ from 'web/static/js/underscore';

let socket = new Socket("/socket", {
  params: {}
})



socket.connect();

class Transformer {
  constructor() {
    // Now that you are connected, you can join channels with a topic:
    let channel = socket.channel("transform:ffff-ffff", {})
    channel.join()
      .receive("ok", this._onJoin.bind(this))
      .receive("error", this._onError.bind(this));


    var $b = $('table');
    var counter = 0;
    channel.on("dataset:chunk", ({transformed: transformed, errors: errors}) => {
      counter++;

      var toCols = (row) => {
        return row.map((col) => `<td>${col}</td>`).join(' ');
      }

      transformed.forEach((row) => {
        $b.append(`<tr>${toCols(row)}</tr>`);
      });

    })

    channel.on("dataset:header", ({header: {columns: columns}}) => {
      var toHeaders = (cs) => {
        return cs.map((col) => `<th>${col}</th>`).join(' ');
      }
      console.log("HEADER IS", columns)
      $b.prepend(`<tr>${toHeaders(columns)}</tr>`);
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
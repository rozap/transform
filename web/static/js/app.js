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
import "phoenix_html";
import {
  Socket
}
from "phoenix";
import xhrPolyfill from './xhr-poly';

window.$ = require('./lib/jquery');

import _ from 'web/static/js/lib/underscore';
import chart from './lib/histogram';

let socket = new Socket("/socket", {
  params: {}
});

class UploadView {
  constructor(channel, fourfour) {
    this.name = "No file selected";
    this.$el = $('#upload');
    this.render();

    $('#upload input').change((e) => {
      var reader = new FileReader();

      reader.onload = () => {
        var xhr = new XMLHttpRequest();
        xhr.open(
          "POST",
          `/api/basictable/${fourfour}`
        );
        xhr.overrideMimeType("application/octet-stream");
        xhr.sendAsBinary(reader.result);
      };

      var file = e.currentTarget.files[0];
      var blob = file.slice(0, file.size);
      reader.readAsBinaryString(blob);
    });
  }


  render() {
    this.$el.html(`
    <input id="upload" type="file"></input>
    `);
  }
}

class Histogram {
  constructor(column) {
    this._name = column;
    this._width = 256;
    this.elName = `histogram${column.hashCode()}`;

    this.render();


    this._updateChart = chart(this.selector, this._width, 120);
  }

  render() {
    $('#histograms').append(
      `<td class="histogram" id="${this.elName}"></td>`
    );
  }

  get selector() {
    return '#' + this.elName;
  }

  update(value, width) {
    d3.select(this.selector)
      .datum(value)
      .call(this._updateChart);
  }
}

class ProgressView {
  constructor(channel) {
    this.$el = $('#progress')
    channel.on("dataset:progress", this.update.bind(this));
  }

  update({rows: rows}) {
    this._count = rows;
    this.render();
  }

  render() {
    this.$el.html(`
      Processed ${this._count} rows
    `)
  }
}

class ErrorsView {
  constructor(channel) {
    this.$el = $('#errors')
    channel.on("dataset:errors", this._appendError.bind(this));
    this._errors = [];
  }

  render() {
    this.$el.html(
      `<ul class="errors">
        ${this._errors.map((error) => `<li>${error}</li>`).join('')}
      </ul>`
    )
  }

  _appendError({result: errors}) {
    this._errors = this._errors.concat(errors);
    this.render();
    console.log(errors)
  }
}


class TableView {
  constructor(channel) {
    this._channel = channel;

    this.$table = $('#results');
    this._seen = 0;

    channel.on("dataset:transform", this._appendChunk.bind(this));
    channel.on("dataset:aggregate", _.throttle(this._addAggregate.bind(this), 500));
  }

  _addAggregate(agg) {
    var widths = this.$table.find('th').map((i, e) => $(e).width());
    _.zip(this._columns, widths).forEach(([col, width]) => {
      var values = agg[col];
      if(this._histograms[col]) this._histograms[col].update(values, width)
    });

  }

  _appendChunk({result: transformed}) {
    if (this._seen === 0) {
      var [row] = transformed;
      this._columns = Object.keys(row);
      this._histograms = {};

      var toHeaders = (cs) => {
        return cs.map((col) => `
          <th>
            ${col}
          </th>
        `).join(' ');
      };
      this.$table.prepend(`<tr>${toHeaders(this._columns)}</tr>`);

      this._columns.map((col) => {
        this._histograms[col] = new Histogram(col);
      });
    }

    this._seen++;

    var toCols = (r) => {
      return this._columns.map((col) => `<td>${r[col]}</td>`).join(' ');
    };

    transformed.forEach((r) => {
      this.$table.append(`<tr>${toCols(r)}</tr>`);
    });
  }
}



socket.connect();

class Transformer {
  constructor() {
    // Now that you are connected, you can join channels with a topic:
    this.channel = socket.channel(`transform:${datasetId}`, {});
    this.channel.join()
      .receive("ok", this._onJoin.bind(this))
      .receive("error", this._onError.bind(this));
  }

  _onJoin(resp) {
    console.log("join with", resp);
    var fourfour = window.location.pathname.split('/')[1];
    var channelView = new TableView(this.channel);
    var uploadView = new UploadView(this.channel, fourfour);
    var errorsView = new ErrorsView(this.channel);
    var progressView = new ProgressView(this.channel);

    $('#do-the-thing').on('click', () => {
      var text = $('textarea').val();
      var ts = [];
      try {
        ts = JSON.parse(text);
      } catch (e) {
        //ok
      }
      this.channel.push("transform", {
        transforms: ts
      });
    });
  }

  _onError(resp) {
    console.error("error with", resp);
  }
}


$(() => {
  new Transformer();
});
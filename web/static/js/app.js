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

class UploadView {
  constructor(fourfour) {
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



$(() => {
  let socket = new Socket("/socket", {
    params: {}
  });
  socket.connect();

  let channel = socket.channel(`transform:${datasetId}`, {});
  channel.join()
    .receive("ok", () => {
      console.log('joined');
    })
    .receive("error", (err) => {
      console.log('join error', err);
    });

  let elmModule = Elm.embed(Elm.Main, document.getElementById('elm-container'), {
    phoenixDatasetProgress: 0,
    phoenixDatasetErrors: [],
    phoenixDatasetTransform: [],
    phoenixDatasetAggregate: []
  });
  // phoenix channels => elm
  channel.on("dataset:progress", (evt) => elmModule.ports.phoenixDatasetProgress.send(evt.rows));
  channel.on("dataset:errors", (evt) => elmModule.ports.phoenixDatasetErrors.send(evt.result));
  channel.on("dataset:transform", (evt) =>
    elmModule.ports.phoenixDatasetTransform.send(
      evt.result.map((row) =>
        Object.keys(row).map((colName) => [colName, row[colName]])
      )
    )
  );
  channel.on("dataset:aggregate", (evt) =>
    elmModule.ports.phoenixDatasetAggregate.send(
      Object.keys(evt).map((colName) =>
        [colName, evt[colName]]
      )
    )
  );
  // elm => histogram stuff
  let histograms = {};
  elmModule.ports.createHistograms.subscribe((colNames) => {
    console.log('make histograms')
    colNames.map((name) => {
      histograms[name] = new Histogram(name);
    });
  });
  elmModule.ports.updateHistograms.subscribe(([columns, newHistos]) => {
    console.log('update histograms');
    let agg = {};
    newHistos.forEach(([name, histo]) => {
      agg[name] = histo;
    });
    var widths = $('#histograms').find('th').map((i, e) => $(e).width());
    _.zip(columns, widths).forEach(([col, width]) => {
      var values = agg[col];
      if(histograms[col]) histograms[col].update(values, width);
    });
  });
  elmModule.ports.updateTransform.subscribe((transform) => {
    channel.push('transform', {transforms: transform});
  });

  new UploadView(datasetId);
});

import _ from 'web/static/js/lib/underscore';


function chart(el, width, height) {
  var margin = {
    top: 16,
    right: 16,
    bottom: 16,
    left: 16
  };

  width = width - margin.left - margin.right;
  height = height - margin.top - margin.bottom;
  var x = d3.scale.ordinal().rangeRoundBands([0, width]);
  var y = d3.scale.linear().range([height, 0]);

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")
    .ticks(10);
  var svg = d3.select(el).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform",
      "translate(" + margin.left + "," + margin.top + ")");



  var tooltip = d3.select("body").append("div")
    .attr("class", "tooltip")
    .style("opacity", 0);

  return function(selection) {
    selection.each(function(data) {
      data = _.map(data, (count, key) => {
        return {
          name: key,
          frequency: count
        };
      }).sort((a, b) => a.name < b.name ? -1 : 1);

      data = data.slice(0, 50)
      x.domain(data.map(function(d) {
        return d.name;
      }));
      y.domain([0, d3.max(data, function(d) {
        return d.frequency;
      })]);

      var bars = svg.selectAll(".bar").data(data, (d) => d.name);

      bars.exit().remove();

      bars
        .attr("width", x.rangeBand())
        .transition()
        .attr("height", (d) => height - y(d.frequency))
        .duration(500)
        .attr("x", (d) => x(d.name))
        .attr("y", (d) => y(d.frequency))



      bars.enter()
        .append("rect")
        .attr("class", "bar")
        .on("mouseover", (d) => {
          tooltip.transition()
            .duration(200)
            .style("opacity", .9);
          tooltip.html(`
            <span class="text-muted">Value:</span>
            <span class="name">${d.name}</span>
            <br>
            <span class="text-muted">Count:</span>
            <span class="frequency">${d.frequency}</span>

          `)
            .style("left", (d3.event.pageX) + "px")
            .style("top", (d3.event.pageY - 28) + "px");
        })
        .on("mouseout", () => tooltip.transition().duration(200).style("opacity", 0))

    });

  }

}

export default chart;
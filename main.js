var width = 960,
    height = 960;

var projection = d3.geo.orthographic()
    .scale(270)
    .translate([width / 2, height / 2])
    .clipAngle(90)
    .precision(.1);

var drag = d3.behavior.drag()
          .origin(function() { var r = projection.rotate(); return {x: r[0], y: -r[1]}; })
          .on("drag", dragged)
          .on("dragstart", dragstarted)
          .on("dragend", dragended);

var path = d3.geo.path()
    .projection(projection);

var graticule = d3.geo.graticule();

var svg = d3.select("#globe").append("svg")
    .attr("width", width)
    .attr("height", height)
    .call(drag);

var pathG = svg.append("g");

pathG.append("defs").append("path")
    .datum({type: "Sphere"})
    .attr("id", "sphere")
    .attr("d", path);

pathG.append("use")
    .attr("class", "stroke")
    .attr("xlink:href", "#sphere");

pathG.append("use")
    .attr("class", "fill")
    .attr("xlink:href", "#sphere");

pathG.append("path")
    .datum(graticule)
    .attr("class", "graticule")
    .attr("d", path);

pathG.selectAll("circle")
  .data(b).enter()
  .append("circle")
  .attr("cx", function (d) { return projection(d)[0]; })
  .attr("cy", function (d) { return projection(d)[1]; })
  .attr("r", "8px")
  .attr("fill", "blue");

var links = [];
data.forEach(function(data){
  links.push({
        type: "LineString",
            coordinates: data
    });
});

var pathArcs = pathG.selectAll(".arc")
            .data(links);

    //enter
    pathArcs.enter()
        .append("path").attr({
            'class': 'arc'
        }).style({ 
            fill: 'none',
        });

    //update
    pathArcs.attr({
            d: path
        })
        .style({
            stroke: '#0000ff',
            'stroke-width': '2px'
        });

function dragstarted(d) 
{
  //stopPropagation prevents dragging to "bubble up" which triggers same event for all elements below this object
  d3.event.sourceEvent.stopPropagation();
  d3.select(this).classed("dragging", true);
}

function dragged() {
  projection.rotate([d3.event.x, -d3.event.y]);
  pathG.selectAll("path").attr("d", path);
  pathG.selectAll("circle")
    .attr("cx", function (d) { return projection(d)[0]; })
    .attr("cy", function (d) { return projection(d)[1]; })
}

function dragended(d) 
{
  d3.select(this).classed("dragging", false);
}

d3.select(self.frameElement).style("height", height + "px");
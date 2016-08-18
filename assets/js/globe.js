var width = 500,
    height = 500;

var projection = d3.geo.orthographic()
    .translate([width / 2, height / 2])
    //.scale(width / 2 - 20)
    .scale(400)
    .clipAngle(90)
    .precision(0.6);

var canvas = d3.select("body").append("canvas")
    .attr("width", width)
    .attr("height", height);

var c = canvas.node().getContext("2d");

var path = d3.geo.path()
    .projection(projection)
    .pointRadius(1)
    .context(c);

var title = d3.select("h1");

var aa = [47.112728, 17.613137];
var locs = canvas.append('g')
		    	    .attr('id', 'locs');

var trips = canvas.append('g')
		    	    .attr('id', 'trips');

queue()
    .defer(d3.json, "world-110m.json")
    .defer(d3.tsv, "world-country-names.tsv")
    .defer(d3.json, "journey_data.json")
    .await(ready);

function ready(error, world, names, journeys) {
  if (error) throw error;

  // Plot the positions on the map:
  circles = locs.selectAll('path')
    .data(journeys.locations)
    .enter()
    .append('path')
      .attr('class', 'geo-node')
      .attr('d', path);

  // Plot the positions on the map:
  lines = trips.selectAll('path')
    .data(journeys.journeys)
    .enter()
    .append('path')
      .attr('class', 'geo-node')
      .attr('d', path);

  var globe = {type: "Sphere"},
      land = topojson.feature(world, world.objects.land),
      countries = topojson.feature(world, world.objects.countries).features,
      borders = topojson.mesh(world, world.objects.countries, function(a, b) { return a !== b; }),
      i = -1,
      n = countries.length;

  countries = countries.filter(function(d) {
    return names.some(function(n) {
      if (d.id == n.id) return d.name = n.name;
    });
  }).sort(function(a, b) {
    return a.name.localeCompare(b.name);
  });

  (function transition() {
    d3.transition()
        .duration(1250)
        .each("start", function() {
          title.text(countries[i = (i + 1) % n].name);
        })
        .tween("rotate", function() {
          var p = d3.geo.centroid(countries[i]),
              r = d3.interpolate(projection.rotate(), [-p[0], -p[1]]);
          return function(t) {
            projection.rotate(r(t));
            c.clearRect(0, 0, width, height);
            c.fillStyle = "#ccc", c.beginPath(), path(land), c.fill();
            c.fillStyle = "#f00", c.beginPath(), path(countries[i]), c.fill();
            c.strokeStyle = "#fff", c.lineWidth = .5, c.beginPath(), path(borders), c.stroke();
            c.strokeStyle = "#000", c.lineWidth = 2, c.beginPath(), path(globe), c.stroke();

            for(l=0; l<journeys.locations.length; l++) {
              c.fillStyle = "#00f", c.beginPath(), path(journeys.locations[l]), c.fill();
            }
            for(j=0; j<journeys.journeys.length; j++) {
              if(journeys.journeys[j].properties.transport == "Plane") {
                c.lineWidth = 0.2;
              } else {
                c.lineWidth = 1;
              }
              c.strokeStyle = "#00f", c.beginPath(), path(journeys.journeys[j]), c.stroke();
            }
          };
        })
      .transition()
        .each("end", transition);
  })();
}

d3.select(self.frameElement).style("height", height + "px");

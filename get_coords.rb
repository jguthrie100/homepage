require 'csv'
require 'net/http'
require 'json'
require 'cgi'
require 'byebug'

# Get co-ordinates for a specific location
def get_coords(address)

  # Initiate @retries to 0 unless running method recursively
  unless caller[0][/`.*'/][1..-2] == __method__.to_s
    @retries = 0
  end

  name = address.split(",")[0]
  puts "Getting coords for #{address}..."

  # Get json from API call for specified location
  uri = URI("https://maps.googleapis.com/maps/api/geocode/json?address=" + CGI.escape("#{address}"))
  json = Net::HTTP.get(uri)
  out = JSON.parse(json)

  sleep 0.3

  # Recursively call method again if error is returned
  if out["status"] != "OK"
    # Exit with error after too many retries
    if @retries > 3
      @errors.push("Error getting coords for: #{address[0]}")
      return [name, address, "ERROR", "ERROR"]
    end

    @retries += 1
    return get_coords(address)
  end

  # Grab lat/lng from API output
  lat = out["results"][0]["geometry"]["location"]["lat"]
  lng = out["results"][0]["geometry"]["location"]["lng"]

  return [name, address, lat, lng]
end

def add_location(address)
  # See if CSV location has already been saved
  @data["locations"].each do |loc|
    if loc["address"] == address
      return -1
    end
  end

  @retries = 0
  coords = get_coords(address)

  if @data["locations"].empty?
    id = 1
  else
    id = @data["locations"].last["id"] + 1
  end

  location = {
    "id" => id,
    "name" => coords[0],
    "address" => coords[1],
    "lat" => coords[2],
    "lng" => coords[3]
  }
  @data["locations"].push(location)
end

def add_journey(journey_row)
  loc_id = []
  [0, 1].each do |i|
    @data["locations"].each do |loc|
      if loc["address"] == journey_row[i]
        loc_id[i] = loc["id"]
      end
    end
  end

  if @data["journeys"].empty?
    id = 1
  else
    id = @data["journeys"].last["id"] + 1
  end

  journey = {
    "id" => id,
    "from" => loc_id[0],
    "to" => loc_id[1],
    "depart" => journey_row[2],
    "arrive" => journey_row[3],
    "transport" => journey_row[4]
  }

  @data["journeys"].push(journey)
end

# Import locations from CSV file
def parse_csv(csv_file)

  # Loop through all entries in CSV file
  CSV.foreach(csv_file, :quote_char => "\"") do |row|
    next if row[0] == "From" && row[1] == "To"
    next if row[0].nil?

    # [0, 1] refers to the 2 addresses in the csv file
    [0, 1].each do |i|
      add_location(row[i])
    end

    add_journey(row)
  end
end

def convert_to_geojson
	geoJSON = {
		"type" => "FeatureCollection",
		"locations" => Array.new,
    "journeys" => Array.new
	}

  @data["journeys"].each do |journey|
    from = @data["locations"][(journey["from"]-1)]
    to = @data["locations"][(journey["to"]-1)]
    journey = {
      "type" => "Feature",
      "geometry" => {
        "type" => "LineString",
        "coordinates" => [ [from["lng"], from["lat"]], [to["lng"], to["lat"]] ]
      },
      "properties" => {
        "from" => from["address"],
        "to" => to["address"],
        "depart" => journey["depart"],
        "arrive" => journey["arrive"],
        "transport" => journey["transport"]
      }
    }
    geoJSON["journeys"].push(journey)
  end

	@data["locations"].each do |loc|
    location = {
			"type" => "Feature",
			"geometry" => {
				"type" => "Point",
				"coordinates" => [loc["lng"], loc["lat"]]
		  },
		  "properties" => {
			  "name": loc["name"]
		  }
		}
    geoJSON["locations"].push(location)
  end

	return geoJSON
end

@errors = Array.new
@data = {"locations" => Array.new, "journeys" => Array.new}

parse_csv("journeys.csv")
geojson_data = convert_to_geojson
File.write('journey_data.json', JSON.pretty_generate(geojson_data))
puts "Wrote output to 'journey_data.js'"
puts "Errors: #{@errors.to_s}"

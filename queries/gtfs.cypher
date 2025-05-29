:param basedir => 'https://raw.githubusercontent.com/tullanders/gtfs_neo4j/main/data/';


/*
Below is data from Trafikverket (Swedish Transport Administration)
*/

// Data from Trafikverket
// this will give us all stations in Sweden
CALL apoc.load.json($basedir + "trv/stations.json")
YIELD value
unwind value.RESPONSE.RESULT[0].TrainStation as ts
WITH ts, ts.Geometry.WGS84 AS pointString where ts.point is null
WITH ts, split(substring(pointString, 7, size(pointString) - 8), " ") AS coords
WITH ts, toFloat(coords[0]) AS longitude, toFloat(coords[1]) AS latitude
merge (s:stops {signature:toUpper(ts.LocationSignature)})
set s.stop_name = ts.AdvertisedLocationName,
s.point = point({latitude: latitude, longitude: longitude});


// Dataset for setting GTFS-ID for Trafikverket stops
// This dataset is required for mapping GTFS stops to Trafikverket stops
LOAD CSV WITH HEADERS FROM "https://api.trafiklab.se/v2/samtrafiken/gtfs/extra/trafikverket_stops.txt" as row
merge (s:stops {signature:toupper(row.trafikverket_signature)})
set s.stop_id = row.stop_id;


/*
Below is data from ERA (European Railway Agency) that connect stops to each other
*/

// Update every stops with the ERA-id
LOAD CSV WITH HEADERS FROM $basedir + "era/operational_point_se.csv" as row
FIELDTERMINATOR ';'
with row,
toupper(replace(row['Unique OP ID'],'SE','')) as signature,
tointeger(replace(row['OP TAF TAP primary code'],'SE','')) as uic_code,
row['Normal running direction'] as direction,
row['Load capability line category'] as linecat,
split(row['Geographical location of Operational Point'],', ') as point

with row, signature, uic_code, direction, linecat, 
tofloat(replace(point[0],',','.')) as latitude,
tofloat(replace(point[1],',','.')) as longitude

MERGE (s:stops {signature:signature})
set s.era_id = row['Unique OP ID'];


// Create relationships between stops with the ERA-id
LOAD CSV WITH HEADERS FROM $basedir + "era/section_of_line_se.csv" as row
FIELDTERMINATOR ';'
with row, row['Start Unique OP ID'] as from, 
row['End Unique OP ID'] as to,
row['National line ID'] as track,
tofloat(replace(replace(row.Length,' km',''),',','.')) as length,
row['Normal running direction'] as direction,
row['Load capability line category'] as linecat

match (f:stops {era_id:from}) where not (f)-->(:stops)
match (t:stops {era_id:to}) where not (:stops)-->(t)
merge (f)-[r:SECTION]->(t)
on create
set r.line_category = linecat,
r.direction = direction,
r.track_id = track,
r.length = length;


/*
 Below is the actual GTFS data import
*/

// agency
CREATE CONSTRAINT uc_agency_agency_id IF NOT EXISTS FOR (n:agency) REQUIRE (n.agency_id) IS UNIQUE;
CREATE INDEX index_agency_agency_id IF NOT EXISTS FOR (n:agency) ON (n.agency_id);

LOAD CSV WITH HEADERS FROM $basedir + "gtfs/agency.txt" as row
MERGE (n:agency {agency_id: row.agency_id})
SET n.agency_name = row.agency_name, 
n.agency_url = row.agency_url,
n.agency_timezone = row.agency_timezone,
n.agency_lang = row.agency_lang,
n.agency_fare_url = row.agency_fare_url;

// routes
CREATE CONSTRAINT uc_routes_route_id IF NOT EXISTS FOR (n:routes) REQUIRE (n.route_id) IS UNIQUE;
CREATE INDEX index_routes_route_id IF NOT EXISTS FOR (n:routes) ON (n.route_id);
CREATE INDEX index_routes_agency_id IF NOT EXISTS FOR (n:routes) ON (n.agency_id);
LOAD CSV WITH HEADERS FROM $basedir + "gtfs/routes.txt" as row
MERGE (n:routes {route_id:row.route_id})
SET n.agency_id = row.agency_id, 
n.route_short_name = row.route_short_name,
n.route_long_name = row.route_long_name,
n.route_type = row.route_type,
n.route_desc = row.route_desc;

// trips
CREATE CONSTRAINT uc_trips_trip_id IF NOT EXISTS FOR (n:trips) REQUIRE (n.trip_id) IS UNIQUE;
CREATE INDEX index_trips_trip_id IF NOT EXISTS FOR (n:trips) ON (n.trip_id);
CREATE INDEX index_trips_route_id IF NOT EXISTS FOR (n:trips) ON (n.route_id);
CREATE INDEX index_trips_service_id IF NOT EXISTS FOR (n:trips) ON (n.service_id);
CREATE INDEX index_trips_shape_id IF NOT EXISTS FOR (n:trips) ON (n.service_id);
LOAD CSV WITH HEADERS FROM $basedir + "gtfs/trips.txt" as row
MERGE (n:trips {trip_id:row.trip_id})
SET n.route_id = row.route_id, 
n.service_id = row.service_id,
n.trip_headsign = row.trip_headsign,
n.direction_id = tointeger(row.direction_id),
n.route_type = tointeger(row.route_type),
n.shape_id = row.shape_id,
n.route_desc = row.route_desc;

// calendar_dates
CREATE INDEX index_calendar_dates_service_id IF NOT EXISTS FOR (n:calendar_dates) ON (n.service_id);
CREATE INDEX index_calendar_dates_date IF NOT EXISTS FOR (n:calendar_dates) ON (n.date);
LOAD CSV WITH HEADERS FROM $basedir + "gtfs/calendar_dates.txt" as row
// if using AuraDB Free - we must reduce size of the data
with row where date(row.date) >= date()
MERGE (n:calendar_dates {service_id:row.service_id, `date`: date(row.date)})
SET n.exception_type = row.exception_type;

// stop_times
CREATE INDEX index_stop_times_trip_id IF NOT EXISTS FOR (n:stop_times) ON (n.trip_id);
CREATE INDEX index_stop_times_stop_id IF NOT EXISTS FOR (n:stop_times) ON (n.stop_id);
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM $basedir + 'gtfs/stop_times.txt' as row return row",
"MERGE (n:stop_times {trip_id:row.trip_id, stop_id:row.stop_id})
SET n.arrival_time = row.arrival_time,
n.departure_time = row.departure_time,
n.stop_sequence = tointeger(row.stop_sequence),
n.stop_headsign = row.stop_headsign,
n.pickup_type = tointeger(row.pickup_type),
n.drop_off_type = tointeger(row.drop_off_type),
n.shape_dist_traveled = row.shape_dist_traveled,
n.timepoint = tointeger(row.timepoint)",
  {batchSize:10000, parallel:true,params: { basedir: $basedir}});


// stops
CREATE INDEX index_stops_stop_id IF NOT EXISTS FOR (n:stops) ON (n.stop_id);
CREATE INDEX index_stops_point IF NOT EXISTS FOR (n:stops) ON (n.point);
LOAD CSV WITH HEADERS FROM $basedir + "gtfs/stops.txt" as row
MERGE (n:stops {stop_id:row.stop_id})
SET n.stop_name = row.stop_name, 
n.stop_lat = tofloat(row.stop_lat),
n.stop_lon = tofloat(row.stop_lon),
n.point = point({longitude: tofloat(row.stop_lon),latitude: tofloat(row.stop_lat)}),
n.location_type = tointeger(row.location_type),
n.parent_station = row.parent_station,
n.platform_code = row.platform_code;

// routes_technical.txt
CREATE INDEX index_trips_technical_route_number IF NOT EXISTS FOR (n:routes) ON (n.technical_route_number);
LOAD CSV WITH HEADERS FROM "https://api.trafiklab.se/v2/samtrafiken/gtfs/extra/routes_technical.txt" as row
with row where row.technical_route_number <> 'null'
match (r:routes {route_id:row.route_id})
set r.technical_route_number = row.technical_route_number;

// trips_technical.txt
CREATE INDEX index_trips_technical_trip_number IF NOT EXISTS FOR (n:trips) ON (n.technical_trip_number);
LOAD CSV WITH HEADERS FROM "https://api.trafiklab.se/v2/samtrafiken/gtfs/extra/trips_technical.txt" as row
with row where row.technical_trip_number <> 'null'
match (t:trips {trip_id:row.trip_id})
set t.technical_trip_number = row.technical_trip_number;

// RELATIONS:
// agency -> routes
match (a:agency)
match (r:routes {agency_id: a.agency_id})
merge (a)-[:HAS_ROUTES]->(r);

// routes -> trips
match (r:routes)
match (t:trips {route_id: r.route_id})
merge (r)-[:HAS_TRIPS]->(t);

// trips -> calendar_dates
CALL apoc.periodic.iterate(
"match (t:trips)
match (c:calendar_dates {service_id: t.service_id}) return t,c",
"merge (t)-[:HAS_CALENDAR_DATES]->(c)",
  {batchSize:10000, parallel:true});


// trips -> stop_times
CALL apoc.periodic.iterate(
"match (t:trips)
match (s:stop_times {trip_id: t.trip_id}) return t,s",
"merge (t)-[:HAS_STOP_TIMES]->(s)",
  {batchSize:10000, parallel:true});


// stop_times -> stops
CALL apoc.periodic.iterate(
"match (st:stop_times)
match (s:stops {stop_id: st.stop_id}) return st,s",
"merge (st)-[:HAS_STOPS]->(s)",
  {batchSize:10000, parallel:true});

// transfers stop_times -> stop_times
LOAD CSV WITH HEADERS FROM $basedir + "gtfs/transfers.txt" as row
with row, 
tostring(tointeger(row.to_trip_id)) as trip_to,
tostring(tointeger(row.from_trip_id)) as trip_from
where row.to_trip_id is not null

match (t_from:trips {trip_id:trip_from})-->(st_from:stop_times)-->(:stops {stop_id:row.from_stop_id})
match (t_to:trips {trip_id:trip_to})-->(st_to:stop_times)-->(:stops {stop_id:row.to_stop_id})
create (st_from)-[:TRANSFER]->(st_to);

// next stop mellan alla hålltider i en trip:
CALL apoc.periodic.iterate(
"match (st1:stop_times)<--(:trips)-->(st2:stop_times) 
where st2.stop_sequence = st1.stop_sequence +1 return st1,st2",
"merge (st1)-[:NEXT_STOP]->(st2)",
  {batchSize:1000, parallel:true});


// convert the arrival and departure times to duration object for easier calculations
CALL apoc.periodic.iterate(
  "match (st:stop_times) where st.arrival_time2 is null
with st, split(st.arrival_time,':') as arrivaltime,
split(st.departure_time,':') as departuretime
with st,
tointeger(arrivaltime[0]) as arrival_hours, 
tointeger(arrivaltime[1]) as arrival_minutes,
tointeger(departuretime[0]) as departure_hours,
tointeger(departuretime[1]) as departure_minutes
return st,departure_hours, departure_minutes,arrival_hours, arrival_minutes,
tointeger(floor(arrival_hours/24)) as arrival_offset,
tointeger(floor(departure_hours/24)) as departure_offset",
"set st.arrival_duration = duration({hours:arrival_hours, minutes:arrival_minutes}),
st.departure_duration = duration({hours:departure_hours, minutes:departure_minutes})",
  {batchSize:10000, parallel:true});

// update trips with from and to signatures
match (t:trips)-[:HAS_STOP_TIMES]->(st:stop_times)-[:HAS_STOPS]->(s:stops)
with t, st, s order by st.stop_sequence
with t, collect(s) as s, collect(st) as st
set t.from_signature = s[0].signature,
t.to_signature = s[size(s)-1].signature;

// Fix train id
// The GTFS-dataset has train numbers spread in both routes and trips
// We will consolidate this into the routes
match (a:agency)--(r:routes)--(t:trips)--(c:calendar_dates) 
with r, t, case 
    when size(r.route_short_name) <= size(coalesce(r.technical_route_number, t.technical_trip_number)) then r.route_short_name
    else coalesce(r.technical_route_number, t.technical_trip_number)
end as train_id 
set r.train_id = train_id, t.train_id = train_id;

// Create operational stop_times
// It make traversing the graph easier - this is NOT GTFS-standard
CALL apoc.periodic.iterate(
  "match (c:calendar_dates)<-[:HAS_CALENDAR_DATES]-(:trips)-[:HAS_STOP_TIMES]->(st:stop_times)
  with c, st, localdatetime({year:c.date.year, month:c.date.month, day:c.date.day}) as dt
  where not (st)-[:HAS_OPERATIONAL_STOP_TIMES]->() return c, st, dt",
  "create (st)-[:HAS_OPERATIONAL_STOP_TIMES]->(op:operational_stop_times 
      {
          arrival_datetime: dt + st.arrival_duration,
          departure_datetime: dt + st.departure_duration,
          start_date: c.date
      }
  )",
{batchSize:10000, parallel:true});
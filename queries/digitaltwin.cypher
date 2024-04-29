// LOAD TRAIN MESSAGES FROM TRV
CALL apoc.load.json("https://raw.githubusercontent.com/tullanders/gtfs_neo4j/main/data/trv/trainmessage.json")
YIELD value
with value.RESPONSE.RESULT[0].TrainMessage as TrainMessage
unwind TrainMessage as trainmessage
merge (tm:train_message {id:trainmessage.EventId})
set tm.header = trainmessage.Header,
tm.description = trainmessage.ExternalDescription,
tm.start_datetime = datetime(trainmessage.StartDateTime),
tm.end_datetime = datetime(trainmessage.PrognosticatedEndDateTimeTrafficImpact)
with tm, trainmessage
unwind trainmessage.TrafficImpact as trafficimpact
unwind trafficimpact.FromLocation  as fromlocation
match (s:stops {signature:toupper(fromlocation)})
merge (tm)-[:TRAIN_MESSAGE_FROM]->(s)

with trafficimpact
unwind trafficimpact.ToLocation  as tolocation
match (s:stops {signature:toupper(tolocation)})
merge (tm)-[:TRAIN_MESSAGE_TO]->(s)
with trafficimpact, tm
foreach (l in trafficimpact.AffectedLocation | set tm.affected_locations = tm.affected_locations+l.LocationSignature);

// GET WEATHER FORECAST (temperature) FROM SMHI
// Create a forecast nodes
CALL apoc.periodic.iterate("
with datetime({year:date().year, month:date().month, day:date().day, hour:time().hour-2}) as date
with replace(replace(tostring(date),':',''),'-','') as validTimeString
with 'https://opendata-download-metfcst.smhi.se/api/category/pmp3g/version/2/geotype/multipoint/validtime/' + validTimeString + '/parameter/t/leveltype/hl/level/2/data.json?with-geo=true&sample=4' as url
CALL apoc.load.jsonParams(url,
  {`Accept-Encoding`:'gzip'},
  null
) yield value
with value.referenceTime as referenceTime, range(0, size(value.geometry.coordinates)-1) as range, value.geometry.coordinates as coords
unwind range as r
with referenceTime, r, coords, Point({latitude: coords[r][1], longitude:  coords[r][0]}) as point

return point, r
",
"
merge (fp:forecast_point {point:point, index:r})
",
{batchSize:10000, parallel:true});

// Create relationship between forecast point and station
CALL apoc.periodic.iterate("
match (s:stops) where (s)--(:stop_times)
call {
    with s
    match (f:forecast_point) where point.distance(s.point, f.point) < 100000
    return f order by point.distance(s.point, f.point) limit 1
}
return s, f",
"merge (s)-[r:HAS_FORECAST_POINT]->(f)
on create
set r.distance = point.distance(s.point, f.point)",
{batchSize:500, parallel:true});

// Remove unused forecast points
match (fp:forecast_point) where not (fp)--() delete fp;

// Hämta väderobservation från SMHI för hela Sverige
CALL apoc.periodic.iterate(
"with [1,5,9] as hours,'4' as sample
unwind hours as h
with datetime({year:date().year, month:date().month, day:date().day, hour:time().hour}) as date, h, sample
with date + duration({hours:time().hour + h}) as date, sample
with replace(replace(tostring(date),':',''),'-','') as validTimeString, sample

CALL apoc.load.jsonParams(
'https://opendata-download-metfcst.smhi.se/api/category/pmp3g/version/2/geotype/multipoint/validtime/' + validTimeString + '/parameter/t/leveltype/hl/level/2/data.json?with-geo=true&downsample=' + sample,
  {`Accept-Encoding`:'gzip'},
  null
) yield value

with value.referenceTime as referenceTime, 
range(0, size(value.geometry.coordinates)-1) as range, value.timeSeries[0].parameters[0].values as values, 
value.geometry.coordinates as coords,
value.timeSeries[0].validTime as validTime
unwind range as r
with validTime, referenceTime, r, values, coords, Point({latitude: coords[r][1], longitude:  coords[r][0]}) as point

match (fp:forecast_point {point:point})
return validTime, referenceTime, fp, values[r] as temperature",
"create (f:forecast {referenceTime:datetime(referenceTime), validTime:datetime(validTime)})
set f.t = temperature
create (fp)-[:HAS_FORECAST]->(f)",
{batchSize:500, parallel:true});


// QUERY TRAIN MESSAGES
// We have a signal failure that affects Gävle and Sundsvall
// check which trains are affected
match (tm:train_message {id:'4649189'})--(s:stops) 
where tm.start_datetime < datetime() <tm.end_datetime

match (s)--(st:stop_times)--(t:trips)--(:calendar_dates {date:date('2024-04-26')})
where localtime(tm.start_datetime) < localtime(st.arrival_time2) 
and localtime(tm.end_datetime) > localtime(st.departure_time2)
return s, st, t, tm;

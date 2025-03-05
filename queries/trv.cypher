:param trvbasedir => 'https://raw.githubusercontent.com/tullanders/gtfs_neo4j/main/data/trv/';


CALL apoc.load.json($trvbasedir + "stations.json")
YIELD value
unwind value.RESPONSE.RESULT[0].TrainStation as ts
WITH ts, ts.Geometry.WGS84 AS pointString where ts.point is null
WITH ts, split(substring(pointString, 7, size(pointString) - 8), " ") AS coords
WITH ts, toFloat(coords[0]) AS longitude, toFloat(coords[1]) AS latitude
merge (s:stops {signature:toUpper(ts.LocationSignature)})
set s.stop_name = ts.AdvertisedLocationName,
s.point = point({latitude: latitude, longitude: longitude})
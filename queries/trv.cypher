:param trvbasedir => 'https://raw.githubusercontent.com/tullanders/gtfs_neo4j/main/data/trv/';


CALL apoc.load.json($trvbasedir + "stations.json")
YIELD value
unwind value.RESPONSE.RESULT[0].TrainStation as ts
WITH ts, "POINT (16.379834602609762 61.47103478880923)" AS pointString where ts.point is null
WITH ts, split(substring(pointString, 7, size(pointString) - 8), " ") AS coords
WITH ts, toFloat(coords[0]) AS longitude, toFloat(coords[1]) AS latitude
MATCH (s:stops {signature:toUpper(ts.LocationSignature)})
set s.stop_name = ts.AdvertisedLocationName,
s.point = point({latitude: latitude, longitude: longitude})
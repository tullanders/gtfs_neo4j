:param erabasedir => 'https://raw.githubusercontent.com/tullanders/gtfs_neo4j/main/data/era/';

//Load Swedish Operational Points from ERA:
LOAD CSV WITH HEADERS FROM $erabasedir + "operational_point_se.csv" as row
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

set s.uic_code = uic_code,
//s.stop_name = row['Name of Operational point'],
s.era_id = row['Unique OP ID'],
s.point = Point({latitude: latitude, longitude: longitude});


// Load Swedish relationships
LOAD CSV WITH HEADERS FROM $erabasedir + "section_of_line_se.csv" as row
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




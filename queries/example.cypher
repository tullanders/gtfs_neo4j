// Match all stations around Stockholm (signature: 'CST')
match (s1:stops {signature:'CST'})-[:SECTION]-(s2:stops)
return s1, s2

// Match all stations around Stockholm max two stops away
match (s1:stops {signature:'CST'})-[:SECTION*1..2]-(s2:stops)
return s1, s2

// Match all stations that starts with Stockholm
match (s:stops) where s.stop_name starts with 'Stockholm'
return s

// Find all agencies that stops at Karlstad today:
match (a:agency)-->(r:routes)-->(t:trips)-->(st:stop_times)-->(s:stops)
where (t)-->(:calendar_dates {date:date()}) and s.stop_name starts with 'Karlstad'
return *

// Match the two shortest paths between Avesta (AVKY) and Falun (FLN)
match p= shortest 2 (:stops {signature:'AVKY'})-[:SECTION]-+(:stops {signature:'FLN'})
RETURN [n in nodes(p) | n.signature] AS stops, apoc.coll.sum([r in relationships(p) | r.length]) as km

// Using dijsktra to find the shortest path between Avesta (AVKY) and Falun (FLN)
match (start:stops {signature:'AVKY'}), (end:stops {signature:'FLN'})
CALL apoc.algo.dijkstra(start, end, 'SECTION', 'length') YIELD path, weight
RETURN path, weight

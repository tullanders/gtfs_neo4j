// Delete all nodes and relationships in the database
:auto MATCH (n) 
CALL { WITH n 
DETACH DELETE n 
} IN TRANSACTIONS OF 50000 ROWS;


// convert the arrival and departure times to time object and add the offset
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
tointeger(floor(departure_hours/24)) as departure_offset,
localtime('00:00') as t",
"set st.arrival_time2 = t + duration({hours:arrival_hours, minutes:arrival_minutes}),
st.arrival_offset = arrival_offset,
st.departure_offset = departure_offset,
st.departure_time2 = t + duration({hours:departure_hours, minutes:departure_minutes})",
  {batchSize:10000, parallel:true})


// Quantized path pattern:
with date() as date
match p = 
(
    (:stops {signature:'MRC'})<--(st:stop_times)<--(t1:trips)-->(:stop_times)
    where st.departure_time2 > localtime('10:00')    
)

(
    (a:stop_times)-->(:stops)<--(b:stop_times)<--(t2:trips)-->(:stop_times)
    where a.arrival_time2 < b.departure_time2
    and (t2)-->(:calendar_dates {date:date})
    and duration.between(a.departure_time2, b.arrival_time2).minutes < 30
){0,1}

(:stop_times)-->(s:stops) where s.stop_name starts with 'Gävle'
with p order by st.departure_time2 limit 2 
with collect(p) as p
unwind nodes(p[0]) as n
optional match (n)--(r:routes)
return n, r

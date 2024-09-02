// Delete all nodes and relationships in the database
:auto MATCH ()-[r]-()
CALL { WITH r
DELETE r
} IN TRANSACTIONS OF 50000 ROWS;

:auto MATCH (n) 
CALL { WITH n 
DELETE n 
} IN TRANSACTIONS OF 50000 ROWS;

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

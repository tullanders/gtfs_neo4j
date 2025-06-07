// Delete all nodes and relationships in the database
:auto MATCH ()-[r]-()
CALL { WITH r
DELETE r
} IN TRANSACTIONS OF 50000 ROWS;

:auto MATCH (n) 
CALL { WITH n 
DELETE n 
} IN TRANSACTIONS OF 50000 ROWS;


// Annan variant

CALL apoc.periodic.iterate(
  "MATCH ()-[r]-() RETURN r",
  "DELETE r",
  {batchSize:100000, parallel:false}
);


CALL apoc.periodic.iterate(
  "MATCH (n) RETURN n",
  "DETACH DELETE n",
  {batchSize:100000, parallel:false}
);
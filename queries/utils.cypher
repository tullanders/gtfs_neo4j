// Delete all nodes and relationships in the database
:auto MATCH (n) 
CALL { WITH n 
DETACH DELETE n 
} IN TRANSACTIONS OF 50000 ROWS;
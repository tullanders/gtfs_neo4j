# Digital Twin for railway and trains
Simple project for setting up a simple Digital Railway Twin
 with neo4j database.


## Data
### GTFS-dataset
#### What is GTFS?
[GTFS](https://gtfs.org/) stands for General Transit Feed Specification. It is a set of open standards that define formats for public transportation schedules and associated geographic information. 

#### Data
The GTFS-files is downloaded from [Trafiklab.se](https://www.trafiklab.se/api/trafiklab-apis/gtfs-sverige-2/) (GTFS Sverige-2). The files are really large because they contains all public transportation in Sweden, both busses and trains. To reduce the filesize you could use the provided Jupyter Notebook (/notebooks/extract_trains.ipynb). 
![Schema](/schema.png)

Other data included:
* Stations (from [RINF](https://data-interop.era.europa.eu/search) and [Trafikverket](https://data.trafikverket.se/home))
* Sections - relationships between stations (from RINF)

## Setup
1. Install [Neo4j Desktop (recommended) or Community Edition](https://neo4j.com/download/) or download [Neo4j Container Image](https://hub.docker.com/r/bitnami/neo4j)  
2. Open Neo4j Browser (http or desktop)
3. Run /queries/gtfs.cypher

## Neodash
You can import dashbord.json into neodash for prebuilt views
![Neodash map](/neodash_map.png)
![Neodash search train](/neodash_search_trains.png)




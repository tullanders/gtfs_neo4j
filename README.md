# Digital Twin for railway and trains
Simple project for setting up a simple Digital Railway Twin
 [GTFS](https://gtfs.org/) in a neo4j database.


## Data
### GTFS-dataset
#### What is GTFS?
GTFS stands for General Transit Feed Specification. It is a set of open standards that define formats for public transportation schedules and associated geographic information. 

#### Data
The GTFS-files is downloaded from [Trafiklab.se](https://www.trafiklab.se/api/trafiklab-apis/gtfs-sverige-2/) (GTFS Sverige-2). The files are really large because they contains all public transportation in Sweden, both busses and trains. To reduce the filesize you could use the Jupyter Notebook (/notebooks/extract_trains.ipynb). 
![Schema](/schema.png)

### ERA Dataset
Contains all stations and their relationships in the nordic countries and Germany. It's downloaded from [ERA](https://data-interop.era.europa.eu/search#)

#### Stations
Includes all stations for Sweden, Norway, Denmark, Finland and Norway with properties like name, UIC-code, coordinates.

#### Station relationships
Contains sections between all stations with properties like length (km) between the stations.
## Setup
### Database
Before running the queries, you must have a neo4j-database. Note! The dataset is to lagre for AuraDB Free. You must reduce the filesize. There is a Jupyter notebook provided in /notebook/ folder that uses Pandas.

### Running queries
The Query folder contains cypher for inserting both ERA and GTFS-data. Just copy the cypher and paste it in to your neo4j-browser. 

### Neodash
You can import dashbord.json into neodash for prebuilt views
![Neodash map](/neodash_map.png)
![Neodash search train](/neodash_search_trains.png)




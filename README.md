# About

This database is a simple random sample of $2,000$ public residential Polk County parcel/housing [sale and assessment records](https://www.assess.co.polk.ia.us/cgi-bin/web/tt/infoqry.cgi?tt=downloads/res_sales_polk) over 1990-2026, transformed using my own personal [data processing pipeline](https://github.com/RobLaughlin/polk-county-ingestion-pipeline). This database was created to develop and structure the raw residential sale records in order to perform efficient descriptive statistics, analysis, and stage for potential ML modeling in the future.

# Prerequisites

- [Git](https://git-scm.com/downloads), to clone the repository.
- [SQLite](https://sqlite.org/download.html) 3.38.0 or later, with its `sqlite3` command-line shell. Check your version with `sqlite3 --version`. `schema.sql` reads the data with `readfile()`, which only the shell has, and uses the `->>` operator added in 3.38.0.
- Linux on x86-64 to run `queries.sql`. CS50's Codespace works. The queries use `MEDIAN` from the bundled [sqlean](https://github.com/nalgeon/sqlean) `stats` extension, and the files in `sqlean-linux-x64/` only run on Linux x86-64. On another system, download the matching build from the [sqlean releases](https://github.com/nalgeon/sqlean/releases) and change the `.load` line at the top of `queries.sql`.

# Instructions

1. Clone the repository and go into it:

   ```
   git clone https://github.com/RobLaughlin/cs50_sql_final.git
   cd cs50_sql_final
   ```

2. Create the database and load the data:

   ```
   sqlite3 polk.db < schema.sql
   ```

   Run this from the repository folder, because `schema.sql` reads the data from `data/*.json`. It prints nothing when it works. It drops and recreates every table, so you can run it again at any time to start fresh. To check the load, `sqlite3 polk.db "SELECT COUNT(*) FROM dim_sales;"` should print `2000`.

3. Run the queries:

   ```
   sqlite3 -box polk.db < queries.sql
   ```

   `-box` prints each result as a table with column headers. To run one query at a time instead, open the database with `sqlite3 -box polk.db`, run `.load ./sqlean-linux-x64/stats`, then paste the query.

# Data dictionary

- Types are as declared in `schema.sql`.
- Dates are stored as `YYYY-MM-DD` text.
- Money is in whole dollars, and columns ending in `_sf` are in square feet.
- Key: **PK** is the primary key, **FK** is a foreign key, and **UNIQUE** means no two rows share the value.

## dim_sales

One row per sale (one recorded document): what describes the sale as a whole, across every parcel it covers. Both fact tables reference its `sale_id`.

| Column           | Type         | Key               | Description                                                                                                                                                                   |
| ---------------- | ------------ | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| sale_id          | INT          | PK                | One number for the document: Hashed from (book, pg).                                                                                                                          |
| book             | INTEGER      | UNIQUE (book, pg) | Recorder's book number for the document. Book numbers rise over time.                                                                                                         |
| pg               | INTEGER      | UNIQUE (book, pg) | Recorder's page number within the book. Together, book and pg identify one document.                                                                                          |
| instrument       | VARCHAR(8)   |                   | Document type: Deed, Contract or Other.                                                                                                                                       |
| analysis_quality | VARCHAR(8)   |                   | Whether the assessor uses the sale in its own market analysis: Good (used), Bad (not used) or Other.                                                                          |
| quality1         | VARCHAR(64)  |                   | First sale condition: the reason, if any, the sale isn't a normal market sale, e.g. Family or Foreclosure. Arms Length means no condition.                                    |
| quality2         | VARCHAR(64)  |                   | Second sale condition, for sales with two. No Code means no second condition.                                                                                                 |
| buyer            | VARCHAR(256) |                   | Buyer (grantee).                                                                                                                                                              |
| seller           | VARCHAR(256) |                   | Seller (grantor).                                                                                                                                                             |
| detached_structs | VARCHAR(512) |                   | Detached structures as CODE/size pairs, e.g. BBK/1584 SHD/120 for a bank barn and a shed. Common codes: GAR Garage, SHD Shed, PTC Concrete Patio, SWR Outdoor Pool, DEC Deck. |

## dim_geo_parcels

One row per geoparcel.

| Column             | Type          | Key | Description                                                  |
| ------------------ | ------------- | --- | ------------------------------------------------------------ |
| gp                 | VARCHAR(12)   | PK  | Geoparcel number, 12 digits, e.g. 802434255001.              |
| parcel_description | VARCHAR(2048) |     | Legal description of the parcel, e.g. LT 8 EAST POLK PLAT 2. |

## dim_district_parcels

One row per district parcel, with its location as of its most recent sale. Parcels that only appear as part of another parcel's sale have just dp and dp_short.

| Column          | Type         | Key                     | Description                                                                                                                                                                                                         |
| --------------- | ------------ | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| dp              | VARCHAR(14)  | PK                      | District/parcel number: the 14-digit property ID, e.g. 01000001000000. The first 3 digits are the district. Kept as text because leading zeros matter.                                                              |
| dp_short        | VARCHAR(64)  | UNIQUE                  | dp in the short form the sale records use: the district, a slash, then the parcel parts without leading zeros, with trailing 0 parts left off, e.g. 18101588000000 is 181/1588 and 17000370000379 is 170/370-0-379. |
| gp              | VARCHAR(12)  | FK → dim_geo_parcels.gp | Geoparcel number of the parcel. NULL for some parcels.                                                                                                                                                              |
| jurisdiction    | VARCHAR(256) |                         | City or township the parcel is in, e.g. ANKENY or ALLEN TWNSHP.                                                                                                                                                     |
| zip             | VARCHAR(5)   |                         | Zip code.                                                                                                                                                                                                           |
| nbhd            | VARCHAR(4)   |                         | Assessor neighborhood code, e.g. AK02. nbhd and pocket together identify a neighborhood.                                                                                                                            |
| pocket          | VARCHAR(4)   |                         | Sub-area of the neighborhood, e.g. G3.                                                                                                                                                                              |
| address         | VARCHAR(256) |                         | Street address.                                                                                                                                                                                                     |
| platname        | VARCHAR(256) |                         | Name of the recorded plat (subdivision) the parcel is in, e.g. WHITE BIRCH PLAT 1.                                                                                                                                  |
| school_district | VARCHAR(256) |                         | School district the parcel is in, e.g. Ankeny.                                                                                                                                                                      |

## dim_dp_groups

One row per dp group. A dp group is the set of district parcels a sale covers, and sales that cover the same parcels share a group. `fct_sales_groups.dp_group_id` and `bridge_dp_groups.group_id` reference its `group_id`.

| Column   | Type         | Key | Description                                                                             |
| -------- | ------------ | --- | --------------------------------------------------------------------------------------- |
| group_id | VARCHAR(256) | PK  | The dp group: a hash of the group's sorted parcels.                                     |
| dp_count | INTEGER      |     | Number of district parcels in the group: 1 for a single-parcel sale. Always at least 1. |

## dim_gp_groups

One row per gp group: the same idea as dim_dp_groups, for geoparcels. A sale that lists no geoparcels has no gp group.

| Column   | Type         | Key | Description                                            |
| -------- | ------------ | --- | ------------------------------------------------------ |
| group_id | VARCHAR(256) | PK  | The gp group: a hash of the group's sorted geoparcels. |
| gp_count | INTEGER      |     | Number of geoparcels in the group. Always at least 1.  |

## bridge_dp_groups

One row per district parcel in each dp group. Join `fct_sales_groups.dp_group_id` to `group_id` for one row per parcel. Each group is in dim_dp_groups.

| Column   | Type         | Key                                             | Description                                         |
| -------- | ------------ | ----------------------------------------------- | --------------------------------------------------- |
| dp       | VARCHAR(14)  | PK (dp, group_id), FK → dim_district_parcels.dp | A district parcel in the group.                     |
| group_id | VARCHAR(256) | PK (dp, group_id), FK → dim_dp_groups.group_id  | The dp group: a hash of the group's sorted parcels. |

## bridge_gp_groups

One row per geoparcel in each gp group: the same idea as bridge_dp_groups, for geoparcels. Join `fct_sales_groups.gp_group_id` to `group_id`. Each group is in dim_gp_groups.

| Column   | Type         | Key                                            | Description                                            |
| -------- | ------------ | ---------------------------------------------- | ------------------------------------------------------ |
| gp       | VARCHAR(12)  | PK (gp, group_id), FK → dim_geo_parcels.gp     | A geoparcel in the group.                              |
| group_id | VARCHAR(256) | PK (gp, group_id), FK → dim_gp_groups.group_id | The gp group: a hash of the group's sorted geoparcels. |

## dim_buildings

One row per building version: a building's description as it was at one or more sales. A new version starts whenever any of these columns changes, such as after a remodel.

| Column               | Type         | Key                          | Description                                                                                                                                |
| -------------------- | ------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| building_id          | VARCHAR(256) | PK                           | The building version: a hash of dp and every building column.                                                                              |
| dp                   | VARCHAR(14)  | FK → dim_district_parcels.dp | District parcel the building is on.                                                                                                        |
| occupancy            | VARCHAR(256) |                              | Kind of dwelling, e.g. Single Family, Townhouse or Condominium.                                                                            |
| residence_type       | VARCHAR(256) |                              | Number of stories and type of attic, e.g. 1 Story, 1.5 Stories or Split Foyer.                                                             |
| bldg_style           | VARCHAR(256) |                              | Architectural style, e.g. Conventional, Ranch or Cape Cod.                                                                                 |
| exterior_wall_type   | VARCHAR(256) |                              | Main exterior wall material, e.g. Vinyl Siding, Brick or Wood Siding.                                                                      |
| roof_type            | VARCHAR(256) |                              | Roof shape: Gable, Hip, Flat, Gambrel, Mansard, Shed or Other.                                                                             |
| roof_material        | VARCHAR(256) |                              | Roof covering, e.g. Asphalt Shingle, Metal or Wood Shingle.                                                                                |
| foundation           | VARCHAR(256) |                              | Foundation material, e.g. Poured Concrete, Concrete Block or Brick.                                                                        |
| heating              | VARCHAR(64)  |                              | Heating system, e.g. Gas Forced Air, Heat Pump or Geo-Thermal.                                                                             |
| fin_bsmt_qual1       | VARCHAR(64)  |                              | Finish quality of the first finished basement area: Living Quarters, Average Plus, Average or Low. NULL when there's no finished basement. |
| fin_bsmt_qual2       | VARCHAR(64)  |                              | Finish quality of the second finished basement area, with the same values as the first.                                                    |
| grade                | VARCHAR(32)  |                              | Construction quality grade, from Executive down to Sub-standard, e.g. Average.                                                             |
| grade_adjustment     | INTEGER      |                              | Adjustment to the grade, e.g. -5 for the assessor's grade 4-05 (Average, -05). 0 when there is none.                                       |
| condition            | VARCHAR(256) |                              | Physical condition, from Excellent (fully revitalized) through Normal (minor deferred maintenance) to Very Poor (uninhabitable).           |
| families             | INTEGER      |                              | Number of living units in the dwelling, usually 1.                                                                                         |
| brick_pct            | INTEGER      |                              | Percent of the house exterior that is full-height brick, 0 to 100.                                                                         |
| air_conditioning_pct | INTEGER      |                              | Percent of the living area cooled by central air, 0 to 100.                                                                                |
| completed_pct        | INTEGER      |                              | How far along an unfinished dwelling is, as a percent. NULL for finished homes.                                                            |
| garage_brick_pct     | INTEGER      |                              | Percent of the attached garage exterior that is brick, 0 to 100.                                                                           |
| year_built           | INTEGER      |                              | Year the house was originally built.                                                                                                       |
| eff_year_built       | INTEGER      |                              | Effective year built: the house's age adjusted for updates.                                                                                |
| year_remodel         | INTEGER      |                              | Year of a major remodel. NULL when there hasn't been one.                                                                                  |
| condo_year_built     | INTEGER      |                              | Year the condo unit was built. Only filled for condominium units.                                                                          |
| first_sale_date      | DATETIME     |                              | Date of the first sale that saw this building version.                                                                                     |
| last_sale_date       | DATETIME     |                              | Date of the last sale that saw this building version.                                                                                      |

## fct_sales_groups

One row per sale: what the sale covers as a whole. The price, assessed values and land area are totals for every parcel in the sale.

| Column                        | Type         | Key                         | Description                                                                                                                               |
| ----------------------------- | ------------ | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| sale_id                       | INT          | PK, FK → dim_sales.sale_id  | The sale.                                                                                                                                 |
| dp_group_id                   | VARCHAR(256) | FK → dim_dp_groups.group_id | The district parcels the sale covers, as a group.                                                                                         |
| gp_group_id                   | VARCHAR(256) | FK → dim_gp_groups.group_id | The geoparcels the sale covers, as a group. NULL when the sale lists none.                                                                |
| sale_date                     | DATETIME     |                             | Date the parties signed the deed or contract. This is the signing date, not the recording date.                                           |
| initial_entry_date            | DATETIME     |                             | Probably the date the sale was first entered into the assessor's system, usually a few days after sale_date.                              |
| price_dollars                 | INTEGER      |                             | Price paid for the real property only, without any personal property. Token prices such as 0, 1 or 10 are common on non-market transfers. |
| land_full_assessment_dollars  | INTEGER      |                             | Full assessed value of the land at the time of sale, as of January 1 of that assessment year.                                             |
| bldg_full_assessment_dollars  | INTEGER      |                             | Full assessed value of the buildings at the time of sale.                                                                                 |
| total_full_assessment_dollars | INTEGER      |                             | Full assessed value of the land and buildings together. It should equal land plus buildings.                                              |
| land_sf                       | REAL         |                             | Land area.                                                                                                                                |
| land_acres                    | REAL         |                             | Land area in acres, to 3 decimal places.                                                                                                  |

## fct_sales_single

One row per sale: the measurements of the residence on the one parcel the sale is filed under (dp), as it was sold.

| Column                 | Type         | Key                            | Description                                                                                      |
| ---------------------- | ------------ | ------------------------------ | ------------------------------------------------------------------------------------------------ |
| sale_id                | INT          | PK, FK → dim_sales.sale_id     | The sale.                                                                                        |
| dp                     | VARCHAR(14)  | FK → dim_district_parcels.dp   | District parcel the sale is filed under. In a multi-parcel sale, its dp group lists all of them. |
| building_id            | VARCHAR(258) | FK → dim_buildings.building_id | The building version at this sale. NULL when the sale has no building data.                      |
| rooms                  | INTEGER      |                                | Total number of rooms.                                                                           |
| bathrooms              | INTEGER      |                                | Full bathrooms. A three-quarter bath counts as full.                                             |
| bedrooms               | INTEGER      |                                | Bedrooms above the basement, each at least 80 sq ft with a closet.                               |
| toilet_rooms           | INTEGER      |                                | Half baths (a toilet and sink).                                                                  |
| extra_fixtures         | INTEGER      |                                | Plumbing fixtures beyond the standard ones.                                                      |
| whirlpools             | INTEGER      |                                | Built-in whirlpool tubs.                                                                         |
| hottubs                | INTEGER      |                                | Built-in hot tubs.                                                                               |
| saunas                 | INTEGER      |                                | Built-in saunas.                                                                                 |
| fireplaces             | INTEGER      |                                | Wood or gas fireplaces. Stoves and electric fireplaces aren't counted.                           |
| main_living_area_sf    | REAL         |                                | Finished living area on the main floor.                                                          |
| upper_living_area_sf   | REAL         |                                | Finished living area above the main floor.                                                       |
| fin_attic_area_sf      | REAL         |                                | Finished attic area.                                                                             |
| total_living_area_sf   | REAL         |                                | Main floor, upper floors and finished attic together.                                            |
| unfin_attic_area_sf    | REAL         |                                | Unfinished attic reached by stairs and used for storage.                                         |
| att_garage_area_sf     | REAL         |                                | Attached garage area.                                                                            |
| open_porch_area_sf     | REAL         |                                | Open or screened porch area.                                                                     |
| enclose_porch_area_sf  | REAL         |                                | Three-season porch or breezeway area.                                                            |
| patio_area_sf          | REAL         |                                | Patio area.                                                                                      |
| deck_area_sf           | REAL         |                                | Wood deck area.                                                                                  |
| canopy_area_sf         | REAL         |                                | Metal canopy area.                                                                               |
| veneer_area_sf         | REAL         |                                | Area of brick on the front wall or part of a wall.                                               |
| carport_area_sf        | REAL         |                                | Carport area.                                                                                    |
| condo_fin_liv_area_sf  | REAL         |                                | Finished living area of the condo unit. Only filled for condominium units.                       |
| basement_area_sf       | REAL         |                                | Total basement area, finished or not.                                                            |
| fin_bsmt_area_total_sf | REAL         |                                | Total finished basement area: the first and second finished areas together.                      |
| fin_bsmt_area1_sf      | REAL         |                                | First finished basement area.                                                                    |
| fin_bsmt_area2_sf      | REAL         |                                | Second finished basement area.                                                                   |
| bsmt_walkout_ft        | REAL         |                                | Length of walkout (fully exposed) basement wall, in feet.                                        |
| bsmt_garage_stalls     | INTEGER      |                                | Number of garage stalls in the basement.                                                         |

## Views

| View                   | Description                                                                                                                                                                                                                                        |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| single_parcel_sales    | One row per sale of a single district parcel (dp_count = 1), with every column of dim_sales, fct_sales_groups and fct_sales_single joined on sale_id, plus dp_count and gp_count from the group tables and the building from dim_buildings.        |
| hq_single_family_sales | The high quality single family market sales from single_parcel_sales: a deed rated Good by the assessor, with conditions Arms Length and No Code, a price of at least 10,000 dollars, positive land area, a building, and occupancy Single Family. |

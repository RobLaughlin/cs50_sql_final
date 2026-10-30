-- Randomly sample 2000 sale_ids from BigQuery, use hashing for repetition
CREATE TEMP TABLE random_sales_ids AS (
  SELECT
    sale_id,
    FARM_FINGERPRINT(CAST(sale_id AS STRING)) AS sale_hash,
  FROM `polk-county-ingestion-pipeline.marts_bridge.bridge_sales`
  ORDER BY sale_hash
  LIMIT 2000
);

-- Use the sale_ids to create random samples for fact and dimension tables in BigQuery
CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.fct_sales_groups` AS (
  SELECT 
    random_sales_ids.sale_id,
    fct_sales_groups.* EXCEPT (sale_id)
  FROM random_sales_ids
  INNER JOIN `polk-county-ingestion-pipeline.marts_facts.fct_sales_groups` AS fct_sales_groups
  ON random_sales_ids.sale_id = fct_sales_groups.sale_id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_dp_groups` AS (
  SELECT 
    dp_group_id AS group_id,
    COUNT(*) AS dp_count
  FROM `polk-county-ingestion-pipeline.random_samples.fct_sales_groups`
  GROUP BY dp_group_id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_gp_groups` AS (
  SELECT 
    gp_group_id AS group_id,
    COUNT(*) AS gp_count
  FROM `polk-county-ingestion-pipeline.random_samples.fct_sales_groups`
  WHERE gp_group_id IS NOT NULL
  GROUP BY gp_group_id
);


-- CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_sales_groups` AS (
--     SELECT 
--       random_sales_ids.sale_id,
--       dim_instruments.instrument,
--       dim_analysis_qualities.analysis_quality,
--       dim_quality1_conditions.quality AS quality1,
--       dim_quality2_conditions.quality AS quality2,
--       dim_sales_groups.* EXCEPT (sale_id, instrument_id, quality1_id, quality2_id, analysis_quality_id)
--     FROM random_sales_ids
--     INNER JOIN `polk-county-ingestion-pipeline.marts_dims.dim_sales_groups` AS dim_sales_groups
--     ON random_sales_ids.sale_id = dim_sales_groups.sale_id
--     LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_analysis_qualities` AS dim_analysis_qualities
--     ON dim_sales_groups.analysis_quality_id = dim_analysis_qualities.id
--     LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_instruments` AS dim_instruments
--     ON dim_sales_groups.instrument_id = dim_instruments.id
--     LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_quality1_conditions` AS dim_quality1_conditions
--     ON dim_sales_groups.quality1_id = dim_quality1_conditions.id
--     LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_quality2_conditions` AS dim_quality2_conditions
--     ON dim_sales_groups.quality2_id = dim_quality2_conditions.id
-- );

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_sales` AS (
    SELECT 
      random_sales_ids.sale_id,
      dim_instruments.instrument,
      dim_analysis_qualities.analysis_quality,
      dim_quality1_conditions.quality AS quality1,
      dim_quality2_conditions.quality AS quality2,
      dim_sales.* EXCEPT (sale_id, instrument_id, quality1_id, quality2_id, analysis_quality_id)
    FROM random_sales_ids
    INNER JOIN `polk-county-ingestion-pipeline.marts_dims.dim_sales` AS dim_sales USING(sale_id)
    LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_analysis_qualities` AS dim_analysis_qualities
    ON dim_sales.analysis_quality_id = dim_analysis_qualities.id
    LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_instruments` AS dim_instruments
    ON dim_sales.instrument_id = dim_instruments.id
    LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_quality1_conditions` AS dim_quality1_conditions
    ON dim_sales.quality1_id = dim_quality1_conditions.id
    LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_quality2_conditions` AS dim_quality2_conditions
    ON dim_sales.quality2_id = dim_quality2_conditions.id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.fct_sales_single` AS (
  SELECT 
    random_sales_ids.sale_id,
    fct_sales_single.* EXCEPT (sale_id)
  FROM random_sales_ids
  INNER JOIN `polk-county-ingestion-pipeline.marts_facts.fct_sales_single` AS fct_sales_single
  ON random_sales_ids.sale_id = fct_sales_single.sale_id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_buildings` AS (
  WITH building_ids AS (
    SELECT DISTINCT fct_sales_single.building_id
    FROM random_sales_ids
    INNER JOIN `polk-county-ingestion-pipeline.random_samples.fct_sales_single` AS fct_sales_single
    ON random_sales_ids.sale_id = fct_sales_single.sale_id   
  )
  SELECT
    dim_buildings.*
  FROM building_ids
  INNER JOIN `polk-county-ingestion-pipeline.marts_views.buildings_descriptive` AS dim_buildings
  ON building_ids.building_id = dim_buildings.building_id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_district_parcels` AS (
  WITH district_parcels AS (
    SELECT DISTINCT dp
    FROM `polk-county-ingestion-pipeline.random_samples.fct_sales_single` AS fct_sales_single
    UNION DISTINCT
    SELECT DISTINCT dp
    FROM `polk-county-ingestion-pipeline.marts_bridge.bridge_dp_groups` AS bridge_dp_groups
    INNER JOIN `polk-county-ingestion-pipeline.random_samples.fct_sales_groups` AS fct_sales_groups
    ON fct_sales_groups.dp_group_id = bridge_dp_groups.group_id
  )
  SELECT 
    dim_district_parcels.* EXCEPT (school_district_id),
    dim_school_districts.school_district
  FROM district_parcels
  INNER JOIN `polk-county-ingestion-pipeline.marts_dims.dim_district_parcels` AS dim_district_parcels USING (dp)
  LEFT JOIN `polk-county-ingestion-pipeline.marts_dims.dim_school_districts` AS dim_school_districts
  ON dim_district_parcels.school_district_id = dim_school_districts.id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.dim_geo_parcels` AS (
  WITH geo_parcels AS (
    SELECT DISTINCT gp
    FROM `polk-county-ingestion-pipeline.random_samples.dim_district_parcels`
    UNION DISTINCT
    SELECT DISTINCT gp
    FROM `polk-county-ingestion-pipeline.marts_bridge.bridge_gp_groups` AS bridge_gp_groups
    INNER JOIN `polk-county-ingestion-pipeline.random_samples.fct_sales_groups` AS fct_sales_groups
    ON fct_sales_groups.gp_group_id = bridge_gp_groups.group_id
  )
  SELECT 
    dim_geo_parcels.*
  FROM geo_parcels
  INNER JOIN `polk-county-ingestion-pipeline.marts_dims.dim_geo_parcels` AS dim_geo_parcels
  ON geo_parcels.gp = dim_geo_parcels.gp
);


-- Create group bridges
-- CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.bridge_sales` AS (
--   SELECT 
--     bridge_sales.*
--   FROM random_sales_ids
--   INNER JOIN `polk-county-ingestion-pipeline.marts_bridge.bridge_sales` AS bridge_sales
--   ON random_sales_ids.sale_id = bridge_sales.sale_id
-- );

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.bridge_dp_groups` AS (
  SELECT DISTINCT
    bridge_dp_groups.*
  FROM `polk-county-ingestion-pipeline.random_samples.fct_sales_groups` AS fct_sales_groups
  INNER JOIN `polk-county-ingestion-pipeline.marts_bridge.bridge_dp_groups` AS bridge_dp_groups
  ON fct_sales_groups.dp_group_id = bridge_dp_groups.group_id
);

CREATE OR REPLACE TABLE `polk-county-ingestion-pipeline.random_samples.bridge_gp_groups` AS (
  SELECT DISTINCT
    bridge_gp_groups.*
  FROM `polk-county-ingestion-pipeline.random_samples.fct_sales_groups` AS fct_sales_groups
  INNER JOIN `polk-county-ingestion-pipeline.marts_bridge.bridge_gp_groups` AS bridge_gp_groups
  ON fct_sales_groups.gp_group_id = bridge_gp_groups.group_id
);
DROP TABLE IF EXISTS random_sales_ids;


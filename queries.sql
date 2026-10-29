-- In this SQL file, write (and comment!) the typical SQL queries users will run on your database

-- Load stats extension
.load ./sqlean-linux-x64/stats

-- Median sale price of high quality single family market sales, grouped by neighborhood
SELECT 
    nbhd, 
    COUNT(*) AS num_sales,
    MEDIAN(price_dollars) AS median_sale_price_dollars
FROM hq_single_family_sales
INNER JOIN dim_district_parcels USING (dp)
GROUP BY nbhd
ORDER BY median_sale_price_dollars DESC;

-- Median sale price of high quality single family market sales, grouped by school district
SELECT 
    school_district, 
    COUNT(*) AS num_sales,
    MEDIAN(price_dollars) AS median_sale_price_dollars
FROM hq_single_family_sales
INNER JOIN dim_district_parcels USING (dp)
GROUP BY school_district
ORDER BY median_sale_price_dollars DESC;

-- Median sale price per square foot of high quality single family market sales, grouped by school district
SELECT 
    school_district, 
    COUNT(*) AS num_sales,
    ROUND(MEDIAN(price_dollars / land_sf), 2) AS sale_price_dollars_per_sf,
    ROUND(AVG(land_sf)) AS avg_land_sf
FROM hq_single_family_sales
INNER JOIN dim_district_parcels USING (dp)
GROUP BY school_district
ORDER BY sale_price_dollars_per_sf DESC;

-- Calculate percentages of high quality single family market sales with certain features
SELECT 
    ROUND(100 * SUM(CASE WHEN hottubs > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS hottub_pct,
    ROUND(100 * SUM(CASE WHEN fireplaces > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fireplace_pct,
    ROUND(100 * SUM(CASE WHEN whirlpools > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS whirlpool_pct,
    ROUND(100 * SUM(CASE WHEN saunas > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS sauna_pct,
    ROUND(100 * SUM(CASE WHEN extra_fixtures > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS extra_fixture_pct,
    ROUND(100 * SUM(CASE WHEN year_remodel IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS remodel_pct
FROM hq_single_family_sales;

-- Find the smallest MAE (mean absolute error) between the assessed value and the actual sale price of high quality single family market sales,
-- grouped by school district
SELECT
    school_district,
    COUNT(*) AS num_sales,
    AVG(ABS(price_dollars - total_full_assessment_dollars)) AS MAE_dollars,
    MAX((ABS(price_dollars - total_full_assessment_dollars))) AS max_absolute_error_dollars,
    MIN((ABS(price_dollars - total_full_assessment_dollars))) AS min_absolute_error_dollars
FROM hq_single_family_sales
INNER JOIN dim_district_parcels USING (dp)
WHERE total_full_assessment_dollars IS NOT NULL
GROUP BY school_district
ORDER BY MAE_dollars ASC;





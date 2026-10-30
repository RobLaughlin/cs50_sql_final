-- In this SQL file, write (and comment!) the schema of your database, including the CREATE TABLE, CREATE INDEX, CREATE VIEW, etc. statements that compose it

-- Temporarily disable foreign keys while dropping tables. All tables being dropped is one single transaction
PRAGMA foreign_keys = OFF;

BEGIN TRANSACTION;

-- Drop all old indices if they exist
DROP INDEX IF EXISTS idx_dim_district_parcels_nbhd;
DROP INDEX IF EXISTS idx_dim_district_parcels_school_district;

DROP INDEX IF EXISTS idx_dim_buildings_dp;

DROP INDEX IF EXISTS idx_fct_sales_groups_sale_date;
DROP INDEX IF EXISTS idx_fct_sales_groups_dp_gp_groups;
DROP INDEX IF EXISTS idx_fct_sales_groups_sale_price_dollars;
DROP INDEX IF EXISTS idx_fct_sales_groups_bldg_assessment_dollars;
DROP INDEX IF EXISTS idx_fct_sales_groups_land_assessment_dollars;
DROP INDEX IF EXISTS idx_fct_sales_groups_land_sf;
DROP INDEX IF EXISTS idx_fct_sales_groups_land_acres;

DROP INDEX IF EXISTS idx_fct_sales_single_dp;
DROP INDEX IF EXISTS idx_fct_sales_single_building_id;

-- Drop all old triggers if they exist
DROP TRIGGER IF EXISTS set_sale_id_hash;

-- Drop all old views if they exist
DROP VIEW IF EXISTS hq_single_family_sales;
DROP VIEW IF EXISTS single_parcel_sales;

-- Drop all old tables if they exist
DROP TABLE IF EXISTS dim_sales;
DROP TABLE IF EXISTS dim_geo_parcels;
DROP TABLE IF EXISTS dim_district_parcels;
DROP TABLE IF EXISTS bridge_dp_groups;
DROP TABLE IF EXISTS bridge_gp_groups;
DROP TABLE IF EXISTS dim_buildings;
DROP TABLE IF EXISTS fct_sales_groups;
DROP TABLE IF EXISTS fct_sales_single;

COMMIT;

-- Enforce foreign key constraints
PRAGMA foreign_keys = ON;

-- Create the sales bridge
CREATE TABLE dim_sales (
    -- Use INT instead of INTEGER so we don't autoincrement
    sale_id INT PRIMARY KEY,

    book INTEGER NOT NULL,
    pg INTEGER NOT NULL,

    instrument VARCHAR(8) CHECK (instrument IN ('Deed', 'Contract', 'Other')),
    analysis_quality VARCHAR(8) CHECK (analysis_quality IN ('Good', 'Bad', 'Other')),
    quality1 VARCHAR(64),
    quality2 VARCHAR(64),
    buyer VARCHAR(256),
    seller VARCHAR(256),
    detached_structs VARCHAR(512),

    UNIQUE(book, pg)
);

-- Hash (book, pg) as the default sale_id
CREATE TRIGGER set_sale_id_hash
AFTER INSERT ON dim_sales
FOR EACH ROW
WHEN NEW.sale_id IS NULL
BEGIN
    UPDATE dim_sales
    SET sale_id = (NEW.book * 1000000000 + NEW.pg)
    WHERE rowid = NEW.rowid;
END;

-- Create dim tables for parcels
CREATE TABLE dim_geo_parcels (
    gp VARCHAR(12) PRIMARY KEY CHECK (length(gp) = 12),
    parcel_description VARCHAR(2048)
);

CREATE TABLE dim_district_parcels (
    dp VARCHAR(14) PRIMARY KEY CHECK (length(dp) = 14),
    dp_short VARCHAR(64) NOT NULL UNIQUE,
    gp VARCHAR(12) CHECK (length(gp) = 12) REFERENCES dim_geo_parcels(gp) ON DELETE SET NULL,
    jurisdiction VARCHAR(256),
    zip VARCHAR(5) CHECK (length(zip) = 5),
    nbhd VARCHAR(4),
    pocket VARCHAR(4),
    address VARCHAR(256),
    platname VARCHAR(256),
    school_district VARCHAR(256)
);

-- Neighborhood index
CREATE INDEX idx_dim_district_parcels_nbhd
ON dim_district_parcels (nbhd);

CREATE INDEX idx_dim_district_parcels_school_district
ON dim_district_parcels (school_district);

-- Create the bridge groups
CREATE TABLE bridge_dp_groups (
    dp VARCHAR(14) CHECK (length(dp) = 14) NOT NULL REFERENCES dim_district_parcels(dp) ON DELETE CASCADE,
    group_id VARCHAR(256) NOT NULL,

    PRIMARY KEY(dp, group_id)
);

CREATE TABLE bridge_gp_groups (
    gp VARCHAR(12) CHECK (length(gp) = 12) NOT NULL REFERENCES dim_geo_parcels(gp) ON DELETE CASCADE,
    group_id VARCHAR(256) NOT NULL,

    PRIMARY KEY(gp, group_id)
);

-- Create the other dim tables
CREATE TABLE dim_buildings (
    building_id VARCHAR(256) PRIMARY KEY,
    dp VARCHAR(14) NOT NULL CHECK (length(dp) = 14) REFERENCES dim_district_parcels(dp) ON DELETE CASCADE,
    occupancy VARCHAR(256),
    residence_type VARCHAR(256),
    bldg_style VARCHAR(256),
    exterior_wall_type VARCHAR(256),
    roof_type VARCHAR(256),
    roof_material VARCHAR(256),
    foundation VARCHAR(256),
    heating VARCHAR(64),
    fin_bsmt_qual1 VARCHAR(64),
    fin_bsmt_qual2 VARCHAR(64),
    grade VARCHAR(32),
    grade_adjustment INTEGER,
    condition VARCHAR(256),
    families INTEGER CHECK(families >= 0),
    brick_pct INTEGER CHECK(brick_pct BETWEEN 0 AND 100),
    air_conditioning_pct INTEGER CHECK(air_conditioning_pct BETWEEN 0 AND 100),
    completed_pct INTEGER CHECK(completed_pct BETWEEN 0 AND 100),
    garage_brick_pct INTEGER CHECK(garage_brick_pct BETWEEN 0 AND 100),
    year_built INTEGER CHECK(length(year_built) = 4),
    eff_year_built INTEGER CHECK(length(eff_year_built) = 4),
    year_remodel INTEGER CHECK(length(year_remodel) = 4),
    condo_year_built INTEGER CHECK(length(condo_year_built) = 4),
    first_sale_date DATETIME,
    last_sale_date DATETIME
);

CREATE INDEX idx_dim_buildings_dp
ON dim_buildings (dp);

CREATE TABLE fct_sales_groups (
    sale_id INT PRIMARY KEY REFERENCES dim_sales(sale_id) ON DELETE CASCADE,
    dp_group_id VARCHAR(256),
    gp_group_id VARCHAR(256),
    dp_count INTEGER NOT NULL CHECK(dp_count > 0),
    sale_date DATETIME NOT NULL,
    initial_entry_date DATETIME,
    price_dollars INTEGER NOT NULL CHECK(price_dollars >= 0),
    land_full_assessment_dollars INTEGER CHECK(land_full_assessment_dollars >= 0),
    bldg_full_assessment_dollars INTEGER CHECK(bldg_full_assessment_dollars >= 0),
    total_full_assessment_dollars INTEGER CHECK(total_full_assessment_dollars >= 0),
    land_sf REAL CHECK(land_sf >= 0),
    land_acres REAL CHECK(land_acres >= 0)
);

CREATE INDEX idx_fct_sales_groups_sale_date
ON fct_sales_groups (sale_date);

CREATE INDEX idx_fct_sales_groups_dp_gp_groups
ON fct_sales_groups (dp_group_id, gp_group_id);

CREATE INDEX idx_fct_sales_groups_sale_price_dollars
ON fct_sales_groups (price_dollars);

CREATE INDEX idx_fct_sales_groups_bldg_assessment_dollars
ON fct_sales_groups (bldg_full_assessment_dollars);

CREATE INDEX idx_fct_sales_groups_land_assessment_dollars
ON fct_sales_groups (land_full_assessment_dollars);

CREATE INDEX idx_fct_sales_groups_land_sf
ON fct_sales_groups (land_sf);

CREATE INDEX idx_fct_sales_groups_land_acres
ON fct_sales_groups (land_acres);

CREATE TABLE fct_sales_single (
    sale_id INT PRIMARY KEY REFERENCES dim_sales(sale_id) ON DELETE CASCADE,
    dp VARCHAR(14) NOT NULL CHECK (length(dp) = 14) REFERENCES dim_district_parcels(dp) ON DELETE SET NULL,
    building_id VARCHAR(258) REFERENCES dim_buildings(building_id) ON DELETE SET NULL,
     
    rooms INTEGER CHECK(rooms >= 0),
    bathrooms INTEGER CHECK(bathrooms >= 0),
    bedrooms INTEGER CHECK(bedrooms >= 0),
    toilet_rooms INTEGER CHECK(toilet_rooms >= 0),
    extra_fixtures INTEGER CHECK(extra_fixtures >= 0),
    whirlpools INTEGER CHECK(whirlpools >= 0),
    hottubs INTEGER CHECK(hottubs >= 0),
    saunas INTEGER CHECK(saunas >= 0),
    fireplaces INTEGER CHECK(fireplaces >= 0),

    main_living_area_sf REAL CHECK(main_living_area_sf >= 0),
    upper_living_area_sf REAL CHECK(upper_living_area_sf >= 0),
    fin_attic_area_sf REAL CHECK(fin_attic_area_sf >= 0),
    total_living_area_sf REAL CHECK(total_living_area_sf >= 0),
    unfin_attic_area_sf REAL CHECK(unfin_attic_area_sf >= 0),
    att_garage_area_sf REAL CHECK(att_garage_area_sf >= 0),
    open_porch_area_sf REAL CHECK(open_porch_area_sf >= 0),
    enclose_porch_area_sf REAL CHECK(open_porch_area_sf >= 0),
    patio_area_sf REAL CHECK(patio_area_sf >= 0),
    deck_area_sf REAL CHECK(deck_area_sf >= 0),
    canopy_area_sf REAL CHECK(canopy_area_sf >= 0),
    veneer_area_sf REAL CHECK(veneer_area_sf >= 0),
    carport_area_sf REAL CHECK(carport_area_sf >= 0),
    condo_fin_liv_area_sf REAL CHECK(condo_fin_liv_area_sf >= 0),
    basement_area_sf REAL CHECK(basement_area_sf >= 0),
    fin_bsmt_area_total_sf REAL CHECK(fin_bsmt_area_total_sf >= 0),
    fin_bsmt_area1_sf REAL CHECK(fin_bsmt_area1_sf >= 0),
    fin_bsmt_area2_sf REAL CHECK(fin_bsmt_area2_sf >= 0),
    bsmt_walkout_ft REAL CHECK(bsmt_walkout_ft >= 0),
    bsmt_garage_stalls INTEGER CHECK(bsmt_garage_stalls >= 0)
);

CREATE INDEX idx_fct_sales_single_dp
ON fct_sales_single (dp);

CREATE INDEX idx_fct_sales_single_building_id
ON fct_sales_single (building_id);

-- Create single parcel sales
CREATE VIEW single_parcel_sales AS
SELECT * FROM dim_sales
INNER JOIN fct_sales_groups USING (sale_id)
INNER JOIN fct_sales_single USING (sale_id)
LEFT JOIN dim_buildings USING (dp, building_id)
WHERE fct_sales_groups.dp_count = 1;

-- Create a view of all single family home market sales with a sale price of: 
-- 1. At least 10k sale price
-- 2. Positive land sqft/acres
-- 3. Simple/normal quality conditions (Arms Length and No Code)
CREATE VIEW hq_single_family_sales AS
SELECT * FROM single_parcel_sales
WHERE 
    building_id IS NOT NULL
    AND price_dollars >= 10000
    AND land_sf > 0
    AND land_acres > 0
    AND instrument = 'Deed'
    AND analysis_quality = 'Good' -- Market sales
    AND quality1 = 'Arms Length'
    AND quality2 = 'No Code'
    AND occupancy = 'Single Family';

-- Insert parcel data
INSERT INTO dim_geo_parcels (
    gp,
    parcel_description
)
SELECT 
    value ->> 'gp', 
    value ->> 'parcel_description'
FROM json_each(readfile('data/dim_geo_parcels_data.json'));

INSERT INTO dim_district_parcels (
    dp,
    dp_short,
    gp,
    jurisdiction,
    zip,
    nbhd,
    pocket,
    address,
    platname,
    school_district
)
SELECT 
    value ->> 'dp', 
    value ->> 'dp_short', 
    value ->> 'gp', 
    value ->> 'jurisdiction',
    value ->> 'zip',
    value ->> 'nbhd',
    value ->> 'pocket',
    value ->> 'address',
    value ->> 'platname',
    value ->> 'school_district'
FROM json_each(readfile('data/dim_district_parcels_data.json'));

-- Insert bridge data, use (book, pg) to test the default hashing behavior
-- Insert the sales dimension data
INSERT INTO dim_sales (
    book,
    pg,
    instrument,
    analysis_quality,
    quality1,
    quality2,
    buyer,
    seller,
    detached_structs
)
SELECT 
    value ->> 'book', 
    value ->> 'pg',  
    value ->> 'instrument',
    value ->> 'analysis_quality',
    value ->> 'quality1',
    value ->> 'quality2',
    value ->> 'buyer',
    value ->> 'seller',
    value ->> 'detached_structs'
FROM json_each(readfile('data/dim_sales_data.json'));

-- Insert bridge group data
INSERT INTO bridge_dp_groups (
    dp, 
    group_id
)
SELECT 
    value ->> 'dp', 
    value ->> 'group_id'
FROM json_each(readfile('data/bridge_dp_groups_data.json'));

INSERT INTO bridge_gp_groups (
    gp, 
    group_id
)
SELECT 
    value ->> 'gp', 
    value ->> 'group_id'
FROM json_each(readfile('data/bridge_gp_groups_data.json'));

-- Insert fact data
INSERT INTO fct_sales_groups (
    sale_id,
    dp_group_id,
    gp_group_id,
    dp_count,
    sale_date,
    initial_entry_date,
    price_dollars,
    land_full_assessment_dollars,
    bldg_full_assessment_dollars,
    total_full_assessment_dollars,
    land_sf,
    land_acres
)
SELECT 
    value ->> 'sale_id', 
    value ->> 'dp_group_id',
    value ->> 'gp_group_id',
    value ->> 'dp_count',
    value ->> 'sale_date',
    value ->> 'initial_entry_date',
    value ->> 'price_dollars',
    value ->> 'land_full_assessment_dollars',
    value ->> 'bldg_full_assessment_dollars',
    value ->> 'total_full_assessment_dollars',
    value ->> 'land_sf',
    value ->> 'land_acres'
FROM json_each(readfile('data/fct_sales_groups_data.json'));

-- Insert the buildings dimension data
INSERT INTO dim_buildings (
    building_id,
    dp,
    occupancy,
    residence_type,
    bldg_style,
    exterior_wall_type,
    roof_type,
    roof_material,
    foundation,
    heating,
    fin_bsmt_qual1,
    fin_bsmt_qual2,
    grade,
    grade_adjustment,
    condition,

    families,

    brick_pct,
    air_conditioning_pct,
    completed_pct,
    garage_brick_pct,

    year_built,
    eff_year_built,
    year_remodel,
    condo_year_built,

    first_sale_date,
    last_sale_date
)
SELECT 
    value ->> 'building_id',
    value ->> 'dp',
    value ->> 'occupancy',
    value ->> 'residence_type',
    value ->> 'bldg_style',
    value ->> 'exterior_wall_type',
    value ->> 'roof_type',
    value ->> 'roof_material',
    value ->> 'foundation',
    value ->> 'heating',
    value ->> 'fin_bsmt_qual1',
    value ->> 'fin_bsmt_qual2',
    value ->> 'grade',
    value ->> 'grade_adjustment',
    value ->> 'condition',
    
    value ->> 'families',

    value ->> 'brick_pct',
    value ->> 'air_conditioning_pct',
    value ->> 'completed_pct',
    value ->> 'garage_brick_pct',

    value ->> 'year_built',
    value ->> 'eff_year_built',
    value ->> 'year_remodel',
    value ->> 'condo_year_built',

    value ->> 'first_sale_date',
    value ->> 'last_sale_date'
FROM json_each(readfile('data/dim_buildings_data.json'));

INSERT INTO fct_sales_single (
    sale_id,
    dp,
    building_id,
    rooms,
    bathrooms,
    bedrooms,
    toilet_rooms,
    extra_fixtures,
    whirlpools,
    hottubs,
    saunas,
    fireplaces,

    main_living_area_sf,
    upper_living_area_sf,
    fin_attic_area_sf,
    total_living_area_sf,
    unfin_attic_area_sf,
    att_garage_area_sf,
    open_porch_area_sf,
    enclose_porch_area_sf,
    patio_area_sf,
    deck_area_sf,
    canopy_area_sf,
    veneer_area_sf,
    carport_area_sf,
    condo_fin_liv_area_sf,
    basement_area_sf,
    fin_bsmt_area_total_sf,
    fin_bsmt_area1_sf,
    fin_bsmt_area2_sf,
    bsmt_walkout_ft,
    bsmt_garage_stalls
)
SELECT 
    value ->> 'sale_id',
    value ->> 'dp',
    value ->> 'building_id',
    value ->> 'rooms',
    value ->> 'bathrooms',
    value ->> 'bedrooms',
    value ->> 'toilet_rooms',
    value ->> 'extra_fixtures',
    value ->> 'whirlpools',
    value ->> 'hottubs',
    value ->> 'saunas',
    value ->> 'fireplaces',

    value ->> 'main_living_area_sf',
    value ->> 'upper_living_area_sf',
    value ->> 'fin_attic_area_sf',
    value ->> 'total_living_area_sf',
    value ->> 'unfin_attic_area_sf',
    value ->> 'att_garage_area_sf',
    value ->> 'open_porch_area_sf',
    value ->> 'enclose_porch_area_sf',
    value ->> 'patio_area_sf',
    value ->> 'deck_area_sf',
    value ->> 'canopy_area_sf',
    value ->> 'veneer_area_sf',
    value ->> 'carport_area_sf',
    value ->> 'condo_fin_liv_area_sf',
    value ->> 'basement_area_sf',
    value ->> 'fin_bsmt_area_total_sf',
    value ->> 'fin_bsmt_area1_sf',
    value ->> 'fin_bsmt_area2_sf',
    value ->> 'bsmt_walkout_ft',
    value ->> 'bsmt_garage_stalls'
FROM json_each(readfile('data/fct_sales_single_data.json'));
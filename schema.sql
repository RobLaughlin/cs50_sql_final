-- In this SQL file, write (and comment!) the schema of your database, including the CREATE TABLE, CREATE INDEX, CREATE VIEW, etc. statements that compose it

-- Temporarily disable foreign keys while dropping tables. All tables being dropped is one single transaction
BEGIN TRANSACTION;

PRAGMA foreign_keys = OFF;

-- Drop all old tables if they exist
DROP TABLE IF EXISTS bridge_sales;
DROP TABLE IF EXISTS dim_geo_parcels;
DROP TABLE IF EXISTS dim_district_parcels;
DROP TABLE IF EXISTS bridge_dp_groups;
DROP TABLE IF EXISTS bridge_gp_groups;
DROP TABLE IF EXISTS dim_buildings;
DROP TABLE IF EXISTS dim_sales_groups;
DROP TABLE IF EXISTS fct_sales_groups;
DROP TABLE IF EXISTS fct_sales_single;

-- Drop all old triggers if they exist
DROP TRIGGER IF EXISTS set_sale_id_hash;

-- Enforce foreign key constraints
PRAGMA foreign_keys = ON;

COMMIT;

-- Create the sales bridge
CREATE TABLE bridge_sales (
    -- Use INT instead of INTEGER so we don't autoincrement
    sale_id INT PRIMARY KEY,

    book INTEGER NOT NULL,
    pg INTEGER NOT NULL,

    UNIQUE(book, pg)
);

-- Hash (book, pg) as the default sale_id
CREATE TRIGGER set_sale_id_hash
AFTER INSERT ON bridge_sales
FOR EACH ROW
WHEN NEW.sale_id IS NULL
BEGIN
    UPDATE bridge_sales
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

-- Create the bridge groups
CREATE TABLE bridge_dp_groups (
    dp VARCHAR(14) CHECK (length(dp) = 14) NOT NULL REFERENCES dim_distrct_parcels(dp) ON DELETE CASCADE,
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
    dp VARCHAR(14) NOT NULL CHECK (length(dp) = 14) REFERENCES dim_district_parcels(dp) ON DELETE SET NULL,
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

CREATE TABLE dim_sales_groups (
    sale_id INT PRIMARY KEY REFERENCES bridge_sales(sale_id) ON DELETE CASCADE,
    instrument VARCHAR(8) CHECK (instrument IN ('Deed', 'Contract', 'Other')),
    analysis_quality VARCHAR(8) CHECK (analysis_quality IN ('Good', 'Bad', 'Other')),
    quality1 VARCHAR(64),
    quality2 VARCHAR(64),
    buyer VARCHAR(256),
    seller VARCHAR(256),
    detached_structs VARCHAR(512)
);

CREATE TABLE fct_sales_groups (
    sale_id INT PRIMARY KEY REFERENCES bridge_sales(sale_id) ON DELETE CASCADE,
    dp_group_id INTEGER UNIQUE NOT NULL REFERENCES bridge_dp_groups(group_id) ON DELETE CASCADE,
    gp_group_id INTEGER UNIQUE NOT NULL REFERENCES bridge_gp_groups(group_id) ON DELETE CASCADE,
    dp_count INTEGER NOT NULL CHECK(dp_count > 0),
    sale_date DATETIME NOT NULL,
    initial_entry_date DATETIME,
    price_dollars INTEGER NOT NULL CHECK(price_dollars >= 0),
    land_full_assessment_dollars NOT NULL CHECK(land_full_assessment_dollars >= 0),
    bldg_full_assessment_dollars NOT NULL CHECK(bldg_full_assessment_dollars >= 0),
    total_full_assessment_dollars NOT NULL CHECK(total_full_assessment_dollars >= 0),
    land_sf REAL CHECK(land_sf >= 0),
    land_acres REAL CHECK(land_acres >= 0)
);

CREATE TABLE fct_sales_single (
    sale_id INT PRIMARY KEY REFERENCES bridge_sales(sale_id) ON DELETE CASCADE,
    dp VARCHAR(14) UNIQUE NOT NULL CHECK (length(dp) = 14) REFERENCES dim_district_parcels(dp) ON DELETE CASCADE,
    building_id VARCHAR(258) UNIQUE REFERENCES dim_buildings(building_id) ON DELETE SET NULL,

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
INSERT INTO bridge_sales (
    book, 
    pg
)
SELECT 
    value ->> 'book', 
    value ->> 'pg'
FROM json_each(readfile('data/bridge_sales_data.json'));
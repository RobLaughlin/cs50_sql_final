-- In this SQL file, write (and comment!) the schema of your database, including the CREATE TABLE, CREATE INDEX, CREATE VIEW, etc. statements that compose it

-- Create the sales bridge
DROP TABLE IF EXISTS sales_bridge;
CREATE TABLE sales_bridge (
    -- Use INT instead of INTEGER so we don't autoincrement
    sale_id INT PRIMARY KEY,

    book INTEGER NOT NULL,
    pg INTEGER NOT NULL,

    UNIQUE(book, pg)
);


DROP TRIGGER IF EXISTS set_sale_id_hash;

-- Hash (book, pg) as the default sale_id
CREATE TRIGGER set_sale_id_hash
AFTER INSERT ON sales_bridge
FOR EACH ROW
WHEN NEW.sale_id IS NULL
BEGIN
    UPDATE sales_bridge
    SET sale_id = (NEW.book * 1000000000 + NEW.pg)
    WHERE rowid = NEW.rowid;
END;

-- Create the bridge groups
DROP TABLE IF EXISTS bridge_dp_groups;
CREATE TABLE bridge_dp_groups (
    dp VARCHAR(14) CHECK (length(dp) = 14) NOT NULL,
    group_id INTEGER NOT NULL,

    UNIQUE(dp, group_id)
);

DROP TABLE IF EXISTS bridge_gp_groups;
CREATE TABLE bridge_gp_groups (
    gp VARCHAR(12) CHECK (length(gp) = 12) NOT NULL,
    group_id INTEGER NOT NULL,

    UNIQUE(gp, group_id)
);

-- Create dim tables
DROP TABLE IF EXISTS dim_district_parcels;
CREATE TABLE dim_district_parcels (
    dp VARCHAR(14) PRIMARY KEY CHECK (length(dp) = 14) REFERENCES bridge_dp_groups(dp),
    dp_short TEXT NOT NULL UNIQUE,
    gp VARCHAR(12) CHECK (length(gp) = 12) REFERENCES bridge_gp_groups(gp),
    jurisdiction VARCHAR(256),
    zip VARCHAR(5) CHECK (length(zip) = 5),
    nbhd VARCHAR(4),
    pocket VARCHAR(4),
    address VARCHAR(256),
    platname VARCHAR(256),
    school_district VARCHAR(256)
);

DROP TABLE IF EXISTS dim_geo_parcels;
CREATE TABLE dim_geo_parcels (
    gp VARCHAR(12) PRIMARY KEY CHECK (length(gp) = 12) REFERENCES bridge_gp_groups(gp),
    parcel_description VARCHAR(2048)
);

DROP TABLE IF EXISTS dim_buildings;
CREATE TABLE dim_buildings (
    building_id TEXT PRIMARY KEY,
    dp VARCHAR(14) UNIQUE NOT NULL CHECK (length(dp) = 14) REFERENCES dim_district_parcels,
    occupancy VARCHAR(256),
    residence_type VARCHAR(256),
    bldg_style VARCHAR(256),
    exterior_wall_type VARCHAR(256),
    roof_type VARCHAR(256),
    roof_material VARCHAR(256),
    foundation VARCHAR(256),
    heating VARCHAR(256),
    fin_bsmt_qual1 VARCHAR(256),
    fin_bsmt_qual2 VARCHAR(256),
    grade VARCHAR(256),
    grade_adjustment INTEGER,
    condition VARCHAR(256),
    families INTEGER,
    brick_pct INTEGER,
    air_conditioning_pct INTEGER,
    completed_pct INTEGER,
    garage_brick_pct INTEGER,
    year_built INTEGER CHECK(length(year_built) = 4),
    eff_year_built INTEGER CHECK(length(eff_year_built) = 4),
    year_remodel INTEGER CHECK(length(year_remodel) = 4),
    condo_year_built INTEGER CHECK(length(condo_year_built) = 4),
    first_sale_date DATETIME,
    last_sale_date DATETIME
);

DROP TABLE IF EXISTS dim_sales_groups;
CREATE TABLE dim_sales_groups (
    sale_id PRIMARY KEY REFERENCES sales_bridge(sale_id),
    instrument VARCHAR(8) CHECK (instrument IN ('Deed', 'Contract', 'Other')),
    analysis_quality VARCHAR(8) CHECK (analysis_quality IN ('Good', 'Bad', 'Other')),
    quality1 VARCHAR(64),
    quality2 VARCHAR(64),
    buyer VARCHAR(256),
    seller VARCHAR(256),
    detached_structs VARCHAR(512)
);

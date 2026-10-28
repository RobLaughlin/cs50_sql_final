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
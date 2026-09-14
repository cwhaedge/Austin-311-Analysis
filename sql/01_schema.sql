/* ============================================================
   Austin 311 Response-Time Analysis
   01 - Schema: staging + typed tables for both datasets
   Target : SQL Server 2025 Developer
   Load   : ingest.py (SODA API -> stg.*). No BULK INSERT.
   ============================================================ */

IF DB_ID('Austin311') IS NULL CREATE DATABASE Austin311;
GO
USE Austin311;
GO
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('dw')  IS NULL EXEC('CREATE SCHEMA dw');
GO

/* ------------------------------------------------------------
   STAGING. Everything NVARCHAR. Column order must match the
   "fields" lists in ingest.py exactly -- the script inserts by
   name, so order here is for readability, but the NAMES must
   match.
   ------------------------------------------------------------ */
DROP TABLE IF EXISTS stg.sr_raw;
CREATE TABLE stg.sr_raw (
    sr_number                    NVARCHAR(50),
    sr_type_desc                 NVARCHAR(200),
    sr_department_desc           NVARCHAR(200),
    sr_method_received_desc      NVARCHAR(100),
    sr_status_desc               NVARCHAR(100),
    sr_status_date               NVARCHAR(50),
    sr_created_date              NVARCHAR(50),
    sr_updated_date              NVARCHAR(50),
    sr_closed_date               NVARCHAR(50),
    sr_location                  NVARCHAR(400),
    sr_location_street_number    NVARCHAR(50),
    sr_location_street_name      NVARCHAR(200),
    sr_location_city             NVARCHAR(100),
    sr_location_zip_code         NVARCHAR(20),
    sr_location_county           NVARCHAR(100),
    sr_location_x                NVARCHAR(50),
    sr_location_y                NVARCHAR(50),
    sr_location_lat              NVARCHAR(50),
    sr_location_long             NVARCHAR(50),
    sr_location_council_district NVARCHAR(20),
    sr_location_map_page         NVARCHAR(50),
    sr_location_map_tile         NVARCHAR(50)
);

DROP TABLE IF EXISTS stg.tpw_raw;
CREATE TABLE stg.tpw_raw (
    service_request_sr_number NVARCHAR(50),
    department                NVARCHAR(200),
    group_description         NVARCHAR(200),
    sr_description            NVARCHAR(200),
    method_received           NVARCHAR(100),
    sr_status                 NVARCHAR(100),
    is_duplicate_1_0          NVARCHAR(10),
    status_change_date        NVARCHAR(50),
    created_date              NVARCHAR(50),
    overdue_on_date           NVARCHAR(50),
    last_update_date          NVARCHAR(50),
    close_date                NVARCHAR(50),
    sr_age_days               NVARCHAR(20),
    response_days             NVARCHAR(20),
    open_count                NVARCHAR(10),
    closed_count              NVARCHAR(10),
    overdue_count             NVARCHAR(10),
    closed_on_time            NVARCHAR(10),
    closed_late               NVARCHAR(10),
    of_days_late              NVARCHAR(20),
    fiscal_year               NVARCHAR(10),
    sr_location               NVARCHAR(400),
    council_district          NVARCHAR(20)
);
GO

/* ------------------------------------------------------------
   TYPED. Run the two INSERTs after ingest.py finishes.
   Re-runnable: truncate + reload from staging.
   ------------------------------------------------------------ */
DROP TABLE IF EXISTS dw.sr;
CREATE TABLE dw.sr (
    sr_number         NVARCHAR(50)  NOT NULL,
    sr_type_desc      NVARCHAR(200) NULL,
    department_desc   NVARCHAR(200) NULL,
    method_received   NVARCHAR(100) NULL,
    status_desc       NVARCHAR(100) NULL,
    created_dt        DATETIME2(0)  NULL,
    closed_dt         DATETIME2(0)  NULL,
    council_district  SMALLINT      NULL,
    zip_code          NVARCHAR(10)  NULL,
    lat               DECIMAL(9,6)  NULL,
    lon               DECIMAL(9,6)  NULL
);

DROP TABLE IF EXISTS dw.tpw;
CREATE TABLE dw.tpw (
    sr_number         NVARCHAR(50)  NOT NULL,
    department        NVARCHAR(200) NULL,
    group_desc        NVARCHAR(200) NULL,
    sr_description    NVARCHAR(200) NULL,
    method_received   NVARCHAR(100) NULL,
    status_desc       NVARCHAR(100) NULL,
    is_duplicate      BIT           NULL,
    created_dt        DATETIME2(0)  NULL,
    overdue_on_dt     DATETIME2(0)  NULL,   -- the city's own due date, per request
    closed_dt         DATETIME2(0)  NULL,
    response_days     DECIMAL(10,3) NULL,
    is_open           BIT           NULL,
    is_closed         BIT           NULL,
    is_overdue        BIT           NULL,
    closed_on_time    BIT           NULL,
    closed_late       BIT           NULL,
    days_late         DECIMAL(10,3) NULL,
    fiscal_year       SMALLINT      NULL,
    council_district  SMALLINT      NULL
);
GO

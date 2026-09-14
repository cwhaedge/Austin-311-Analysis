/* ============================================================
   02 - Typed load: stg.* -> dw.*
   Run AFTER ingest.py has finished. Re-runnable.
   ============================================================ */
USE Austin311;
GO

/* ---------------- populate dw.sr ---------------- */
TRUNCATE TABLE dw.sr;
INSERT INTO dw.sr
SELECT
    LTRIM(RTRIM(sr_number)),
    NULLIF(LTRIM(RTRIM(sr_type_desc)), ''),
    NULLIF(LTRIM(RTRIM(sr_department_desc)), ''),
    NULLIF(LTRIM(RTRIM(sr_method_received_desc)), ''),
    NULLIF(LTRIM(RTRIM(sr_status_desc)), ''),
    TRY_CONVERT(DATETIME2(0), sr_created_date),
    TRY_CONVERT(DATETIME2(0), sr_closed_date),
    TRY_CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM(sr_location_council_district)), '')),
    NULLIF(LEFT(LTRIM(RTRIM(sr_location_zip_code)), 10), ''),
    TRY_CONVERT(DECIMAL(9,6), sr_location_lat),
    TRY_CONVERT(DECIMAL(9,6), sr_location_long)
FROM stg.sr_raw
WHERE sr_number IS NOT NULL;

/* ---------------- populate dw.tpw ---------------- */
TRUNCATE TABLE dw.tpw;
INSERT INTO dw.tpw
SELECT
    LTRIM(RTRIM(service_request_sr_number)),
    NULLIF(LTRIM(RTRIM(department)), ''),
    NULLIF(LTRIM(RTRIM(group_description)), ''),
    NULLIF(LTRIM(RTRIM(sr_description)), ''),
    NULLIF(LTRIM(RTRIM(method_received)), ''),
    NULLIF(LTRIM(RTRIM(sr_status)), ''),
    TRY_CONVERT(BIT, is_duplicate_1_0),
    TRY_CONVERT(DATETIME2(0), created_date),
    TRY_CONVERT(DATETIME2(0), overdue_on_date),
    TRY_CONVERT(DATETIME2(0), close_date),
    TRY_CONVERT(DECIMAL(10,3), response_days),
    TRY_CONVERT(BIT, open_count),
    TRY_CONVERT(BIT, closed_count),
    TRY_CONVERT(BIT, overdue_count),
    TRY_CONVERT(BIT, closed_on_time),
    TRY_CONVERT(BIT, closed_late),
    TRY_CONVERT(DECIMAL(10,3), of_days_late),
    TRY_CONVERT(SMALLINT, fiscal_year),
    TRY_CONVERT(SMALLINT, council_district)
FROM stg.tpw_raw
WHERE service_request_sr_number IS NOT NULL;
GO

CREATE CLUSTERED INDEX ix_sr_created   ON dw.sr  (created_dt);
CREATE NONCLUSTERED INDEX ix_sr_type   ON dw.sr  (sr_type_desc) INCLUDE (created_dt, closed_dt);
CREATE CLUSTERED INDEX ix_tpw_created  ON dw.tpw (created_dt);
CREATE NONCLUSTERED INDEX ix_tpw_desc  ON dw.tpw (sr_description) INCLUDE (created_dt, overdue_on_dt, closed_dt, closed_late);
GO

SELECT 'dw.sr' AS t, COUNT(*) AS n FROM dw.sr
UNION ALL
SELECT 'dw.tpw', COUNT(*) FROM dw.tpw;
GO

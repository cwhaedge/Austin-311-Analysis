/* ============================================================
   05d - Materialise the auto-close detector

   vw_autoclose_years computes a median over ~2M rows per
   service-year. As a view it is recomputed on every reference,
   and three downstream views reference it. Materialise it once
   into a small table (~2,000 rows) and point the views at that.
   Re-run this script whenever the data is refreshed.
   ============================================================ */
USE Austin311;
GO

DROP TABLE IF EXISTS dw.autoclose_years;
SELECT * INTO dw.autoclose_years FROM dw.vw_autoclose_years;
CREATE UNIQUE CLUSTERED INDEX ix_autoclose ON dw.autoclose_years (canonical_service, yr);
GO

/* Repoint the three consumers at the table */
CREATE OR ALTER VIEW dw.vw_service_degradation AS
WITH clean_base AS (
    SELECT c.*
    FROM dw.vw_cohort_sr c
    LEFT JOIN dw.autoclose_years a
      ON a.canonical_service = c.canonical_service AND a.yr = YEAR(c.created_dt)
    WHERE c.created_dt >= '2015-01-01' AND c.created_dt < '2020-01-01'
      AND c.in_trend = 1
      AND ISNULL(a.autoclose_flag, 0) = 0
),
baseline AS (
    SELECT DISTINCT canonical_service,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_close) OVER (PARTITION BY canonical_service) AS baseline_median_days,
        COUNT(*) OVER (PARTITION BY canonical_service) AS baseline_n
    FROM clean_base
),
baseline_years AS (
    SELECT canonical_service, COUNT(DISTINCT YEAR(created_dt)) AS baseline_years
    FROM clean_base GROUP BY canonical_service
),
recent AS (
    SELECT DISTINCT canonical_service,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_close) OVER (PARTITION BY canonical_service) AS recent_median_days,
        COUNT(*) OVER (PARTITION BY canonical_service) AS recent_n
    FROM dw.vw_cohort_sr
    WHERE created_dt >= '2024-01-01' AND in_trend = 1
)
SELECT
    b.canonical_service,
    m.service_group,
    CAST(b.baseline_median_days AS DECIMAL(10,3)) AS baseline_median_days,
    b.baseline_n,
    byr.baseline_years,
    CAST(r.recent_median_days AS DECIMAL(10,3))   AS recent_median_days,
    r.recent_n,
    CAST(r.recent_median_days - b.baseline_median_days AS DECIMAL(10,3)) AS abs_change_days,
    CAST(100.0 * (r.recent_median_days - b.baseline_median_days)
         / NULLIF(b.baseline_median_days, 0) AS DECIMAL(10,2))           AS pct_change,
    CAST(r.recent_n * (r.recent_median_days - b.baseline_median_days) AS DECIMAL(14,1)) AS excess_resident_days
FROM baseline b
JOIN baseline_years byr ON byr.canonical_service = b.canonical_service
JOIN recent r ON r.canonical_service = b.canonical_service
CROSS APPLY (SELECT TOP 1 service_group FROM dw.sr_type_mapping x WHERE x.canonical_service = b.canonical_service) m
WHERE b.baseline_n >= 500 AND r.recent_n >= 100;
GO

CREATE OR ALTER VIEW dw.vw_no_valid_baseline AS
SELECT a.canonical_service,
       COUNT(*) AS flagged_years,
       MIN(a.yr) AS first_flagged, MAX(a.yr) AS last_flagged,
       CAST(AVG(a.pct_in_band) AS DECIMAL(5,2)) AS avg_pct_in_band
FROM dw.autoclose_years a
WHERE a.autoclose_flag = 1 AND a.yr BETWEEN 2015 AND 2019
GROUP BY a.canonical_service
HAVING a.canonical_service NOT IN (SELECT canonical_service FROM dw.vw_service_degradation);
GO

CREATE OR ALTER VIEW dw.vw_monthly_resolution AS
WITH monthly AS (
    SELECT DISTINCT
        canonical_service, service_group, is_event_driven, created_month,
        COUNT(*) OVER (PARTITION BY canonical_service, created_month)          AS requests,
        SUM(is_censored) OVER (PARTITION BY canonical_service, created_month)  AS still_open,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_close)
            OVER (PARTITION BY canonical_service, created_month)               AS median_days,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_to_close)
            OVER (PARTITION BY canonical_service, created_month)               AS p90_days
    FROM dw.vw_cohort_sr
)
SELECT
    mo.canonical_service, mo.service_group, mo.is_event_driven, mo.created_month, mo.requests, mo.still_open,
    CAST(mo.median_days AS DECIMAL(10,3)) AS median_days,
    CAST(mo.p90_days    AS DECIMAL(10,3)) AS p90_days,
    CAST(AVG(mo.median_days) OVER (PARTITION BY mo.canonical_service ORDER BY mo.created_month
                                   ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS DECIMAL(10,3)) AS rolling_12m_median,
    LAG(mo.median_days, 12) OVER (PARTITION BY mo.canonical_service ORDER BY mo.created_month) AS median_days_prior_year,
    ISNULL(a.autoclose_flag, 0) AS autoclose_flag
FROM monthly mo
LEFT JOIN dw.autoclose_years a
  ON a.canonical_service = mo.canonical_service AND a.yr = YEAR(mo.created_month);
GO

/* ---- Checks (fast now) --------------------------------------- */
SELECT * FROM dw.vw_no_valid_baseline ORDER BY canonical_service;
SELECT * FROM dw.vw_validation_summary;
SELECT TOP 12 canonical_service, service_group, baseline_median_days, recent_median_days, abs_change_days, excess_resident_days
FROM dw.vw_service_degradation ORDER BY excess_resident_days DESC;
GO

/* ============================================================
   05b - Auto-close detection and baseline correction

   Finding: every legacy Public Works service has a 2015-2019
   median of 180-184 days. Eleven unrelated services do not
   independently converge on 180. The old PW system auto-closed
   requests at 180 days without update. Those closes are not
   resolutions, so any baseline that includes them is invalid.

   Fix: detect service-years where a large share of closes fall
   at 175-185 days, and exclude those service-years from the
   baseline. A service with no clean baseline year drops out of
   the ranking and is listed separately -- disclosed, not hidden.
   ============================================================ */
USE Austin311;
GO

/* ---- Detection: share of closes in the 175-185 day band ----- */
CREATE OR ALTER VIEW dw.vw_autoclose_years AS
SELECT
    canonical_service,
    YEAR(created_dt) AS yr,
    COUNT(*) AS n_closed,
    SUM(CASE WHEN days_to_close BETWEEN 175 AND 185 THEN 1 ELSE 0 END) AS n_in_band,
    CAST(100.0 * SUM(CASE WHEN days_to_close BETWEEN 175 AND 185 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_in_band,
    CASE WHEN 100.0 * SUM(CASE WHEN days_to_close BETWEEN 175 AND 185 THEN 1 ELSE 0 END) / COUNT(*) >= 20
         THEN 1 ELSE 0 END AS autoclose_flag
FROM dw.vw_cohort_sr
WHERE is_censored = 0
GROUP BY canonical_service, YEAR(created_dt);
GO

/* Look at it once: which services, which years */
SELECT * FROM dw.vw_autoclose_years WHERE autoclose_flag = 1 ORDER BY canonical_service, yr;
/* Expect legacy PW services, roughly 2016-2021. If the band is
   sharp (e.g. 40%+ of closes within a 10-day window) the
   auto-close reading is confirmed. */
GO

/* ---- Degradation view, baseline restricted to clean years ---- */
CREATE OR ALTER VIEW dw.vw_service_degradation AS
WITH clean_base AS (
    SELECT c.*
    FROM dw.vw_cohort_sr c
    LEFT JOIN dw.vw_autoclose_years a
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

/* ---- Services that lost their baseline to the auto-close ----
        Disclose these on the methodology page.                  */
CREATE OR ALTER VIEW dw.vw_no_valid_baseline AS
SELECT a.canonical_service,
       COUNT(*) AS flagged_years,
       MIN(a.yr) AS first_flagged, MAX(a.yr) AS last_flagged,
       CAST(AVG(a.pct_in_band) AS DECIMAL(5,2)) AS avg_pct_in_band
FROM dw.vw_autoclose_years a
WHERE a.autoclose_flag = 1 AND a.yr BETWEEN 2015 AND 2019
GROUP BY a.canonical_service
HAVING a.canonical_service NOT IN (SELECT canonical_service FROM dw.vw_service_degradation);
GO

/* ---- Monthly view gains the flag, so the chart can shade it - */
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
LEFT JOIN dw.vw_autoclose_years a
  ON a.canonical_service = mo.canonical_service AND a.yr = YEAR(mo.created_month);
GO

/* ============================================================
   CHECK: Found Animal - Pickup, +1,604%. Real or artefact?
   The AP label's 2024 median was 160 days. Look at the shape.
   A real backlog is a broad hump; a bulk-close is a spike.
   ============================================================ */
SELECT
    YEAR(created_dt) AS yr,
    COUNT(*) AS n,
    SUM(CASE WHEN days_to_close < 1   THEN 1 ELSE 0 END) AS under_1d,
    SUM(CASE WHEN days_to_close BETWEEN 1   AND 7   THEN 1 ELSE 0 END) AS d1_7,
    SUM(CASE WHEN days_to_close BETWEEN 7   AND 30  THEN 1 ELSE 0 END) AS d7_30,
    SUM(CASE WHEN days_to_close BETWEEN 30  AND 120 THEN 1 ELSE 0 END) AS d30_120,
    SUM(CASE WHEN days_to_close BETWEEN 120 AND 200 THEN 1 ELSE 0 END) AS d120_200,
    SUM(CASE WHEN days_to_close > 200 THEN 1 ELSE 0 END) AS over_200,
    SUM(is_censored) AS still_open
FROM dw.vw_cohort_sr
WHERE canonical_service = 'Found Animal - Pickup' AND created_dt >= '2021-01-01'
GROUP BY YEAR(created_dt) ORDER BY yr;

/* And the corrected headline */
SELECT TOP 20 * FROM dw.vw_service_degradation ORDER BY excess_resident_days DESC;
SELECT * FROM dw.vw_no_valid_baseline ORDER BY canonical_service;
SELECT * FROM dw.vw_method_validation ORDER BY degradation_rank;
GO

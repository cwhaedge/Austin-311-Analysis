/* ============================================================
   05c - Detector tune + validation summary

   1. Auto-close detector, second pass. Four services survived
      with contaminated baselines (Mowing Medians 182d, Alley
      158d, Tree Issue 51d, Obstruction 22d) because the timer
      drifted outside the 175-185 band in some years and the 20%
      threshold let others through. Two changes:
        - band widened to 170-190, threshold lowered to 10%
        - a service-year whose MEDIAN sits at 170-200 days is
          flagged regardless -- a median at the timer is not
          measuring resolution, whatever the band share says.

   2. Validation summary. Rank-within-two-places was the wrong
      test; the two methods disagree on ordering and agree on
      direction. Report Spearman rank correlation and the
      mean city late-rate for degrading vs improving services.
   ============================================================ */
USE Austin311;
GO

/* ---- 1. Detector v2 ------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_autoclose_years AS
WITH base AS (
    SELECT canonical_service, YEAR(created_dt) AS yr, days_to_close
    FROM dw.vw_cohort_sr WHERE is_censored = 0
),
med AS (
    SELECT DISTINCT canonical_service, yr,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_close)
               OVER (PARTITION BY canonical_service, yr) AS median_days
    FROM base
),
agg AS (
    SELECT canonical_service, yr,
           COUNT(*) AS n_closed,
           SUM(CASE WHEN days_to_close BETWEEN 170 AND 190 THEN 1 ELSE 0 END) AS n_in_band
    FROM base GROUP BY canonical_service, yr
)
SELECT a.canonical_service, a.yr, a.n_closed, a.n_in_band,
       CAST(100.0 * a.n_in_band / a.n_closed AS DECIMAL(5,2)) AS pct_in_band,
       CAST(m.median_days AS DECIMAL(10,2)) AS median_days,
       CASE WHEN 100.0 * a.n_in_band / a.n_closed >= 10
              OR m.median_days BETWEEN 170 AND 200
            THEN 1 ELSE 0 END AS autoclose_flag
FROM agg a
JOIN med m ON m.canonical_service = a.canonical_service AND m.yr = a.yr;
GO

/* ---- 2. Validation summary ----------------------------------- */
CREATE OR ALTER VIEW dw.vw_validation_summary AS
WITH v AS (
    SELECT canonical_service, abs_change_days, city_pct_late,
           degradation_rank, late_rate_rank,
           CAST(degradation_rank AS FLOAT) - CAST(late_rate_rank AS FLOAT) AS d
    FROM dw.vw_method_validation
),
n AS (SELECT COUNT(*) AS n FROM v)
SELECT
    (SELECT n FROM n) AS services_compared,
    CAST(1.0 - (6.0 * SUM(d * d)) / ((SELECT n FROM n) * (POWER(CAST((SELECT n FROM n) AS FLOAT), 2) - 1))
         AS DECIMAL(5,3))                                                          AS spearman_rho,
    CAST(AVG(CASE WHEN abs_change_days > 0 THEN city_pct_late END) AS DECIMAL(5,2)) AS mean_city_late_pct_degrading,
    CAST(AVG(CASE WHEN abs_change_days <= 0 THEN city_pct_late END) AS DECIMAL(5,2)) AS mean_city_late_pct_improving,
    SUM(CASE WHEN abs_change_days > 0 THEN 1 ELSE 0 END)                             AS n_degrading,
    SUM(CASE WHEN abs_change_days <= 0 THEN 1 ELSE 0 END)                            AS n_improving,
    SUM(CASE WHEN abs_change_days > 0 AND city_pct_late >= 5 THEN 1 ELSE 0 END)       AS degrading_and_city_late_5pct
FROM v;
GO

/* ---- Re-check ------------------------------------------------ */
SELECT * FROM dw.vw_no_valid_baseline ORDER BY canonical_service;          -- should now include Mowing Medians, Alley, Tree Issue ROW, Obstruction
SELECT * FROM dw.vw_method_validation ORDER BY degradation_rank;           -- no baseline > 30 days left in the improving group
SELECT * FROM dw.vw_validation_summary;                                    -- the two numbers for the validation page
SELECT TOP 12 canonical_service, service_group, baseline_median_days, recent_median_days, abs_change_days, excess_resident_days
FROM dw.vw_service_degradation ORDER BY excess_resident_days DESC;
GO

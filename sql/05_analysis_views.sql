/* ============================================================
   05 - Analysis layer. Power BI imports these views, not dw.*.

   Two layers:
     CITYWIDE  -- 2014->present, all departments. Constructed
                  baseline (no published targets exist).
     TPW       -- Oct 2021->present, one department. The city's
                  OWN per-request due dates. Ground truth.
   The validation view at the end checks the constructed method
   against ground truth where both exist.
   ============================================================ */
USE Austin311;
GO

/* ============================================================
   CITYWIDE
   ============================================================ */

/* ------------------------------------------------------------
   Cohort fact with right-censoring.

   Problem: a request created last month that is still open has
   no close date. Dropping it biases recent medians LOW -- the
   slow tickets are exactly the ones missing. That is
   survivorship bias and it is how most versions of this
   analysis go wrong.

   Fix: only score requests created at least 180 days before the
   most recent record (the cohort window), and for any still
   open, use "days open so far" as a lower bound instead of
   dropping it. The median is identifiable under right-censoring
   as long as the censoring time exceeds the median -- 180 days
   is far above any service's median, so it does.

   Say this on the methodology page in one sentence. It is the
   single most sophisticated thing in the project and it costs
   two lines of SQL.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_cohort_sr AS
WITH bounds AS (
    SELECT MAX(created_dt)                    AS data_end,
           DATEADD(DAY, -180, MAX(created_dt)) AS cohort_end
    FROM dw.sr
)
SELECT
    s.sr_number,
    m.canonical_service,
    m.service_group,
    m.is_event_driven,
    m.in_trend,
    s.department_desc,
    s.method_received,
    s.council_district,
    s.created_dt,
    CAST(s.created_dt AS DATE)                                   AS created_date,   -- relate DimDate here
    DATEFROMPARTS(YEAR(s.created_dt), MONTH(s.created_dt), 1)    AS created_month,
    s.closed_dt,
    CASE WHEN s.closed_dt IS NULL THEN 1 ELSE 0 END               AS is_censored,
    CAST(DATEDIFF(HOUR, s.created_dt, COALESCE(s.closed_dt, b.data_end)) / 24.0
         AS DECIMAL(10,3))                                       AS days_to_close
FROM dw.sr s
JOIN dw.sr_type_mapping m ON m.sr_type_desc = s.sr_type_desc
CROSS JOIN bounds b
WHERE s.created_dt IS NOT NULL
  AND s.created_dt <= b.cohort_end
  AND (s.closed_dt IS NULL OR s.closed_dt >= s.created_dt)
  AND (s.closed_dt IS NULL OR DATEDIFF(DAY, s.created_dt, s.closed_dt) <= 1095)
  /* ~50k rows (2%) close in the same second they were created --
     auto-closed on intake, no work performed. Including them
     drags every median toward zero. Excluded here; counted and
     disclosed on the methodology page (profiling query 5). */
  AND (s.closed_dt IS NULL OR DATEDIFF(SECOND, s.created_dt, s.closed_dt) > 0)
  AND m.mapping_basis <> 'EXCLUDED_TEST';
GO

/* ------------------------------------------------------------
   Monthly median per service, rolling 12m, prior-year lag.
   PERCENTILE_CONT is a window function -> DISTINCT collapses.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_monthly_resolution AS
WITH monthly AS (
    SELECT DISTINCT
        canonical_service, service_group, is_event_driven, created_month,
        COUNT(*) OVER (PARTITION BY canonical_service, created_month)                      AS requests,
        SUM(is_censored) OVER (PARTITION BY canonical_service, created_month)              AS still_open,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_close)
            OVER (PARTITION BY canonical_service, created_month)                           AS median_days,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_to_close)
            OVER (PARTITION BY canonical_service, created_month)                           AS p90_days
    FROM dw.vw_cohort_sr
)
SELECT
    canonical_service, service_group, is_event_driven, created_month, requests, still_open,
    CAST(median_days AS DECIMAL(10,3)) AS median_days,
    CAST(p90_days    AS DECIMAL(10,3)) AS p90_days,
    CAST(AVG(median_days) OVER (PARTITION BY canonical_service ORDER BY created_month
                                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS DECIMAL(10,3)) AS rolling_12m_median,
    LAG(median_days, 12) OVER (PARTITION BY canonical_service ORDER BY created_month)         AS median_days_prior_year
FROM monthly;
GO

/* ------------------------------------------------------------
   Degradation vs constructed baseline, with a volume-weighted
   impact metric.

   Baseline = each service's own 2015-2019 median. After district
   data stabilises; before COVID and the 2023 ice storm.

   "Excess resident-days" = recent volume x (recent median -
   baseline median). A service that got 1 day slower on 40k
   requests matters more than one that got 10 days slower on
   300. Rank by this, not by raw days -- it is what a manager
   would actually prioritise on.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_service_degradation AS
WITH baseline AS (
    SELECT DISTINCT canonical_service,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_close) OVER (PARTITION BY canonical_service) AS baseline_median_days,
        COUNT(*) OVER (PARTITION BY canonical_service) AS baseline_n
    FROM dw.vw_cohort_sr
    WHERE created_dt >= '2015-01-01' AND created_dt < '2020-01-01' AND in_trend = 1
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
    CAST(b.baseline_median_days AS DECIMAL(10,3))                          AS baseline_median_days,
    b.baseline_n,
    CAST(r.recent_median_days AS DECIMAL(10,3))                            AS recent_median_days,
    r.recent_n,
    CAST(r.recent_median_days - b.baseline_median_days AS DECIMAL(10,3))   AS abs_change_days,
    CAST(100.0 * (r.recent_median_days - b.baseline_median_days)
         / NULLIF(b.baseline_median_days, 0) AS DECIMAL(10,2))            AS pct_change,
    CAST(r.recent_n * (r.recent_median_days - b.baseline_median_days) AS DECIMAL(14,1)) AS excess_resident_days
FROM baseline b
JOIN recent r ON r.canonical_service = b.canonical_service
CROSS APPLY (SELECT TOP 1 service_group FROM dw.sr_type_mapping x WHERE x.canonical_service = b.canonical_service) m
WHERE b.baseline_n >= 500 AND r.recent_n >= 100;
GO

/* ------------------------------------------------------------
   Open rate by month -- documents the bias the cohort window
   removes. Methodology page.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_open_rate AS
SELECT m.canonical_service,
       DATEFROMPARTS(YEAR(s.created_dt), MONTH(s.created_dt), 1) AS created_month,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN s.closed_dt IS NULL THEN 1 ELSE 0 END) AS still_open,
       CAST(100.0 * SUM(CASE WHEN s.closed_dt IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS pct_open
FROM dw.sr s
JOIN dw.sr_type_mapping m ON m.sr_type_desc = s.sr_type_desc
WHERE s.created_dt IS NOT NULL
GROUP BY m.canonical_service, DATEFROMPARTS(YEAR(s.created_dt), MONTH(s.created_dt), 1);
GO

/* ============================================================
   TPW -- ground truth layer
   ============================================================ */

/* ------------------------------------------------------------
   The city's target per service, reverse-engineered from the
   per-request due dates. This table does not exist anywhere in
   published form; you built it. Show it.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_tpw_target AS
WITH gaps AS (
    SELECT sr_description, DATEDIFF(DAY, created_dt, overdue_on_dt) AS target_days
    FROM dw.tpw
    WHERE created_dt IS NOT NULL AND overdue_on_dt IS NOT NULL AND is_duplicate = 0
),
ranked AS (
    SELECT sr_description, target_days, COUNT(*) AS n,
           ROW_NUMBER() OVER (PARTITION BY sr_description ORDER BY COUNT(*) DESC) AS rk,
           SUM(COUNT(*)) OVER (PARTITION BY sr_description) AS total_n
    FROM gaps GROUP BY sr_description, target_days
)
SELECT sr_description, target_days, n AS n_at_target, total_n,
       CAST(100.0 * n / total_n AS DECIMAL(5,1)) AS pct_at_target
FROM ranked WHERE rk = 1;
GO

/* ------------------------------------------------------------
   Monthly on-time performance per TPW service, by the city's
   own scoring. Late-rate is "of those closed"; overdue-open is
   reported separately so nothing is hidden.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_tpw_monthly AS
SELECT
    t.sr_description,
    COALESCE(m.canonical_service, t.sr_description)            AS canonical_service,
    DATEFROMPARTS(YEAR(t.created_dt), MONTH(t.created_dt), 1)   AS created_month,
    COUNT(*)                                                    AS requests,
    SUM(CAST(t.closed_on_time AS INT))                          AS closed_on_time,
    SUM(CAST(t.closed_late AS INT))                             AS closed_late,
    SUM(CAST(t.is_overdue AS INT))                              AS open_overdue,
    CAST(100.0 * SUM(CAST(t.closed_late AS INT))
         / NULLIF(SUM(CAST(t.closed_on_time AS INT)) + SUM(CAST(t.closed_late AS INT)), 0)
         AS DECIMAL(5,2))                                       AS pct_late_of_closed,
    AVG(CASE WHEN t.closed_late = 1 THEN t.days_late END)       AS avg_days_late_when_late
FROM dw.tpw t
LEFT JOIN dw.sr_type_mapping m ON m.sr_type_desc = t.sr_description
WHERE t.created_dt IS NOT NULL AND t.is_duplicate = 0
GROUP BY t.sr_description, COALESCE(m.canonical_service, t.sr_description),
         DATEFROMPARTS(YEAR(t.created_dt), MONTH(t.created_dt), 1);
GO

/* ------------------------------------------------------------
   Per-service TPW scorecard for the whole period.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_tpw_service AS
SELECT
    t.sr_description,
    COALESCE(m.canonical_service, t.sr_description) AS canonical_service,
    g.target_days,
    COUNT(*) AS requests,
    SUM(CAST(t.closed_on_time AS INT)) AS closed_on_time,
    SUM(CAST(t.closed_late AS INT))    AS closed_late,
    SUM(CAST(t.is_overdue AS INT))     AS open_overdue,
    CAST(100.0 * SUM(CAST(t.closed_late AS INT))
         / NULLIF(SUM(CAST(t.closed_on_time AS INT)) + SUM(CAST(t.closed_late AS INT)), 0)
         AS DECIMAL(5,2)) AS pct_late_of_closed,
    CAST(AVG(CASE WHEN t.closed_late = 1 THEN t.days_late END) AS DECIMAL(10,2)) AS avg_days_late_when_late
FROM dw.tpw t
LEFT JOIN dw.sr_type_mapping m ON m.sr_type_desc = t.sr_description
LEFT JOIN dw.vw_tpw_target g   ON g.sr_description = t.sr_description
WHERE t.created_dt IS NOT NULL AND t.is_duplicate = 0
GROUP BY t.sr_description, COALESCE(m.canonical_service, t.sr_description), g.target_days;
GO

/* ------------------------------------------------------------
   VALIDATION: does the constructed method agree with the city?

   For services present in both layers, compare the citywide
   degradation ranking against TPW's actual late rate. If the
   services the constructed baseline flags as most degraded are
   also the ones with the worst on-time rates, the method is
   validated and the citywide findings for departments WITHOUT
   published targets gain credibility. Where they disagree, say
   so -- that is a finding too.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW dw.vw_method_validation AS
SELECT
    d.canonical_service,
    d.baseline_median_days,
    d.recent_median_days,
    d.abs_change_days,
    d.pct_change,
    RANK() OVER (ORDER BY d.abs_change_days DESC)              AS degradation_rank,
    p.target_days                                              AS city_target_days,
    p.pct_late_of_closed                                       AS city_pct_late,
    RANK() OVER (ORDER BY p.pct_late_of_closed DESC)           AS late_rate_rank,
    CASE WHEN d.recent_median_days > p.target_days THEN 1 ELSE 0 END AS recent_median_exceeds_target
FROM dw.vw_service_degradation d
JOIN (
    SELECT canonical_service,
           SUM(closed_late) AS closed_late, SUM(closed_on_time) AS closed_on_time,
           MIN(target_days) AS target_days,
           CAST(100.0 * SUM(closed_late) / NULLIF(SUM(closed_on_time) + SUM(closed_late), 0) AS DECIMAL(5,2)) AS pct_late_of_closed
    FROM dw.vw_tpw_service
    GROUP BY canonical_service
) p ON p.canonical_service = d.canonical_service;
GO

/* ------------------------------------------------------------
   Date dimension.
   ------------------------------------------------------------ */
DROP TABLE IF EXISTS dw.dim_date;
CREATE TABLE dw.dim_date (
    [Date] DATE PRIMARY KEY, [Year] SMALLINT, [Month] TINYINT, MonthName NVARCHAR(20),
    MonthStart DATE, [Quarter] TINYINT, YearMonth NVARCHAR(7), FiscalYear SMALLINT  -- Austin FY starts Oct 1
);
WITH d AS (
    SELECT CAST('2014-01-01' AS DATE) AS dt
    UNION ALL SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2027-12-31'
)
INSERT INTO dw.dim_date
SELECT dt, YEAR(dt), MONTH(dt), DATENAME(MONTH, dt),
       DATEFROMPARTS(YEAR(dt), MONTH(dt), 1), DATEPART(QUARTER, dt), FORMAT(dt, 'yyyy-MM'),
       CASE WHEN MONTH(dt) >= 10 THEN YEAR(dt) + 1 ELSE YEAR(dt) END
FROM d OPTION (MAXRECURSION 0);
GO

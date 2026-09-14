/* ============================================================
   03 - Data quality profiling
   Run every query. Save the outputs -- several become
   dashboard content on the methodology page.
   ============================================================ */
USE Austin311;
GO

/* ---- 1. Conversion failures --------------------------------- */
SELECT 'city' AS ds, COUNT(*) AS total_rows,
       SUM(CASE WHEN created_dt IS NULL THEN 1 ELSE 0 END) AS bad_created,
       SUM(CASE WHEN closed_dt  IS NULL THEN 1 ELSE 0 END) AS null_closed,
       SUM(CASE WHEN council_district IS NULL THEN 1 ELSE 0 END) AS null_district
FROM dw.sr
UNION ALL
SELECT 'tpw', COUNT(*),
       SUM(CASE WHEN created_dt IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN closed_dt  IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN council_district IS NULL THEN 1 ELSE 0 END)
FROM dw.tpw;

/* ---- 2. Volume by year --------------------------------------
   Expect a jump to ~354k in 2023. Query 2b shows why.           */
SELECT YEAR(created_dt) AS yr, COUNT(*) AS requests,
       COUNT(DISTINCT sr_type_desc) AS distinct_types,
       COUNT(DISTINCT department_desc) AS distinct_depts
FROM dw.sr WHERE created_dt IS NOT NULL
GROUP BY YEAR(created_dt) ORDER BY yr;

/* ---- 2b. The 2023 spike is the February ice storm ------------
   Feb 2023 alone is ~63k requests against a ~20k monthly norm,
   and "ARR - Storm Debris Collection" was the #1 type of 2023
   at ~47k after not appearing in 2022's top 15 at all.
   This is an EVENT, not a system artefact -- and that changes
   how you handle it: annotate it, and treat storm debris as its
   own event-driven series rather than part of the trend.        */
SELECT DATEFROMPARTS(YEAR(created_dt), MONTH(created_dt), 1) AS created_month,
       COUNT(*) AS requests,
       SUM(CASE WHEN sr_type_desc LIKE '%Storm Debris%' THEN 1 ELSE 0 END) AS storm_debris,
       COUNT(*) - SUM(CASE WHEN sr_type_desc LIKE '%Storm Debris%' THEN 1 ELSE 0 END) AS ex_storm
FROM dw.sr
WHERE created_dt >= '2022-07-01' AND created_dt < '2024-07-01'
GROUP BY DATEFROMPARTS(YEAR(created_dt), MONTH(created_dt), 1)
ORDER BY created_month;

/* ---- 3. Council district fill rate by year ------------------
   ~61% in 2014, ~95%+ from 2015. District cuts start at 2015.  */
SELECT YEAR(created_dt) AS yr, COUNT(*) AS total,
       COUNT(council_district) AS with_district,
       CAST(100.0 * COUNT(council_district) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS pct_filled
FROM dw.sr WHERE created_dt IS NOT NULL
GROUP BY YEAR(created_dt) ORDER BY yr;

/* ---- 4. Closure / open rate by year -------------------------
   Rising open share in recent years = survivorship bias in the
   raw median. Handled structurally in 05 via the cohort window;
   this query documents WHY that window is needed.               */
SELECT YEAR(created_dt) AS yr, status_desc, COUNT(*) AS n
FROM dw.sr WHERE created_dt IS NOT NULL
GROUP BY YEAR(created_dt), status_desc
ORDER BY yr, n DESC;

/* ---- 5. Impossible intervals -------------------------------- */
SELECT SUM(CASE WHEN closed_dt < created_dt THEN 1 ELSE 0 END) AS closed_before_created,
       SUM(CASE WHEN DATEDIFF(DAY, created_dt, closed_dt) > 1095 THEN 1 ELSE 0 END) AS over_three_years,
       SUM(CASE WHEN DATEDIFF(SECOND, created_dt, closed_dt) = 0 THEN 1 ELSE 0 END) AS instant_close
FROM dw.sr WHERE created_dt IS NOT NULL AND closed_dt IS NOT NULL;

/* ---- 6. Type-label lifespans (raw material for 04) ---------- */
SELECT sr_type_desc, COUNT(*) AS n,
       MIN(created_dt) AS first_seen, MAX(created_dt) AS last_seen,
       COUNT(DISTINCT department_desc) AS depts
FROM dw.sr WHERE created_dt IS NOT NULL
GROUP BY sr_type_desc ORDER BY n DESC;

/* ---- 7. Suspected rename pairs ------------------------------
   Strips department prefixes and punctuation. Any normalised
   key with >1 raw label is a candidate merge. Confirm each
   against query 6's dates: DISJOINT ranges = rename;
   OVERLAPPING ranges = two departments, do not merge.
   Note the ACD prefix: Austin Code became "ACD" mid-2023, so
   the code-officer request now has THREE labels in play.        */
WITH norm AS (
    SELECT sr_type_desc, COUNT(*) AS n,
           MIN(created_dt) AS first_seen, MAX(created_dt) AS last_seen,
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
             UPPER(sr_type_desc),
             'ARR ',''),'ATD ',''),'TPW ',''),'AE ',''),'ACD ',''),
             'AUSTIN CODE ',''),'ANIMAL PROTECTION ',''),'-',''),' ','') AS norm_key
    FROM dw.sr WHERE created_dt IS NOT NULL
    GROUP BY sr_type_desc
)
SELECT norm_key, COUNT(*) OVER (PARTITION BY norm_key) AS label_variants,
       sr_type_desc, n, first_seen, last_seen
FROM norm
WHERE norm_key IN (SELECT norm_key FROM norm GROUP BY norm_key HAVING COUNT(*) > 1)
ORDER BY norm_key, first_seen;

/* ============================================================
   TPW dataset -- the one with the city's own due dates
   ============================================================ */

/* ---- 8. Implied SLA per service type ------------------------
   overdue_on_dt - created_dt is the city's target window, set
   per type. This query reverse-engineers the target table.
   Parking enforcement is ~5 days, traffic signals ~45, right-of-
   way obstructions ~180. The MODE is the target; spread around
   it is either a policy change over time or data noise.         */
WITH gaps AS (
    SELECT sr_description,
           DATEDIFF(DAY, created_dt, overdue_on_dt) AS target_days
    FROM dw.tpw
    WHERE created_dt IS NOT NULL AND overdue_on_dt IS NOT NULL
      AND is_duplicate = 0
),
ranked AS (
    SELECT sr_description, target_days, COUNT(*) AS n,
           ROW_NUMBER() OVER (PARTITION BY sr_description ORDER BY COUNT(*) DESC) AS rk,
           SUM(COUNT(*)) OVER (PARTITION BY sr_description) AS total_n
    FROM gaps GROUP BY sr_description, target_days
)
SELECT sr_description, target_days AS modal_target_days, n AS n_at_mode, total_n,
       CAST(100.0 * n / total_n AS DECIMAL(5,1)) AS pct_at_mode
FROM ranked WHERE rk = 1
ORDER BY total_n DESC;

/* ---- 9. On-time performance by fiscal year ------------------
   The city's own scoring, not yours. This is the ground truth
   the constructed baseline in 05 gets validated against.        */
SELECT fiscal_year,
       COUNT(*) AS requests,
       SUM(CAST(is_duplicate AS INT))  AS duplicates,
       SUM(CAST(closed_on_time AS INT)) AS closed_on_time,
       SUM(CAST(closed_late AS INT))    AS closed_late,
       SUM(CAST(is_overdue AS INT))     AS open_and_overdue,
       CAST(100.0 * SUM(CAST(closed_late AS INT))
            / NULLIF(SUM(CAST(closed_on_time AS INT)) + SUM(CAST(closed_late AS INT)),0)
            AS DECIMAL(5,2)) AS pct_late_of_closed
FROM dw.tpw
WHERE is_duplicate = 0
GROUP BY fiscal_year ORDER BY fiscal_year;

/* ---- 10. Duplicate rate ------------------------------------
   TPW flags duplicates. Citywide does not. Use TPW's rate as a
   stated caveat about likely duplicate inflation citywide.      */
SELECT COUNT(*) AS total,
       SUM(CAST(is_duplicate AS INT)) AS duplicates,
       CAST(100.0 * SUM(CAST(is_duplicate AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS pct_dupe
FROM dw.tpw;
GO

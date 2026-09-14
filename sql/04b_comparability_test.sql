/* ============================================================
   04b - Comparability test for CONCURRENT merges  (v2)

   Merging two labels is only valid if they describe the same
   work. Test: in the years both were live, do they resolve at
   similar speed?

   v2 fixes two blind spots the first pass exposed:
     1. Ratio is meaningless when both medians are under a day
        (0.46 vs 0.08 days is "same day" either way). Those
        pair-years count as AGREE.
     2. One anomalous year -- a bulk closure of stale rows in a
        label's retirement year -- can blow up the average. The
        verdict now rests on the DECISIVE year: the pair-year
        with the most evidence (largest min(n_a, n_b)), with the
        median ratio across years shown alongside.

   Verdict rule:
     KEEP    decisive ratio <= 1.5, or both medians < 1 day
     REVIEW  decisive ratio <= 2.5
     SPLIT   decisive ratio > 2.5 AND |diff| > 3 days
   ============================================================ */
USE Austin311;
GO

DROP TABLE IF EXISTS #ly;
SELECT DISTINCT
    m.canonical_service,
    s.sr_type_desc,
    YEAR(s.created_dt) AS yr,
    COUNT(*) OVER (PARTITION BY m.canonical_service, s.sr_type_desc, YEAR(s.created_dt)) AS n_closed,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF(HOUR, s.created_dt, s.closed_dt) / 24.0)
         OVER (PARTITION BY m.canonical_service, s.sr_type_desc, YEAR(s.created_dt)) AS DECIMAL(10,2)) AS median_days
INTO #ly
FROM dw.sr s
JOIN dw.sr_type_mapping m ON m.sr_type_desc = s.sr_type_desc
WHERE m.mapping_basis IN ('CONCURRENT', 'CONCURRENT_VERIFIED', 'CONCURRENT_UNTESTED', 'SPLIT_BY_TEST')
  AND s.closed_dt IS NOT NULL
  AND DATEDIFF(SECOND, s.created_dt, s.closed_dt) > 0
  AND DATEDIFF(DAY, s.created_dt, s.closed_dt) <= 1095;

DROP TABLE IF EXISTS #pairs;
SELECT
    a.canonical_service, a.yr,
    a.sr_type_desc AS label_a, a.n_closed AS n_a, a.median_days AS med_a,
    b.sr_type_desc AS label_b, b.n_closed AS n_b, b.median_days AS med_b,
    CAST(ABS(a.median_days - b.median_days) AS DECIMAL(10,2)) AS abs_diff_days,
    CAST(CASE WHEN a.median_days > b.median_days
              THEN a.median_days / NULLIF(b.median_days, 0)
              ELSE b.median_days / NULLIF(a.median_days, 0) END AS DECIMAL(10,2)) AS ratio,
    CASE WHEN a.median_days < 1 AND b.median_days < 1 THEN 1 ELSE 0 END AS both_sub_day,
    CASE WHEN a.n_closed < b.n_closed THEN a.n_closed ELSE b.n_closed END AS evidence
INTO #pairs
FROM #ly a
JOIN #ly b
  ON b.canonical_service = a.canonical_service
 AND b.yr = a.yr
 AND b.sr_type_desc > a.sr_type_desc
WHERE a.n_closed >= 100 AND b.n_closed >= 100;

/* ---- Verdict per service, decided by the strongest year ---- */
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY canonical_service ORDER BY evidence DESC) AS rk
    FROM #pairs
),
med AS (
    SELECT DISTINCT canonical_service,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ratio) OVER (PARTITION BY canonical_service) AS median_ratio
    FROM #pairs WHERE both_sub_day = 0
)
SELECT
    r.canonical_service,
    (SELECT COUNT(*) FROM #pairs p WHERE p.canonical_service = r.canonical_service) AS pair_years,
    r.yr        AS decisive_year,
    r.evidence  AS decisive_evidence,
    r.med_a, r.med_b, r.ratio AS decisive_ratio, r.abs_diff_days AS decisive_diff,
    CAST(m.median_ratio AS DECIMAL(10,2)) AS median_ratio_all_years,
    CASE WHEN r.both_sub_day = 1 OR ISNULL(r.ratio, 1) <= 1.5 THEN 'KEEP'
         WHEN ISNULL(r.ratio, 1) <= 2.5                        THEN 'REVIEW'
         WHEN r.abs_diff_days > 3                              THEN 'SPLIT'
         ELSE 'KEEP' END AS verdict
FROM ranked r
LEFT JOIN med m ON m.canonical_service = r.canonical_service
WHERE r.rk = 1
ORDER BY verdict DESC, decisive_ratio DESC;

/* ---- All pair-years, for the methodology appendix ---------- */
SELECT * FROM #pairs ORDER BY canonical_service, yr;

/* ---- Concurrent services with no testable overlap year ------
        (overlap is a handful of retroactively relabelled rows) */
SELECT DISTINCT m.canonical_service
FROM dw.sr_type_mapping m
WHERE m.mapping_basis LIKE 'CONCURRENT%'
  AND m.canonical_service NOT IN (SELECT canonical_service FROM #pairs)
ORDER BY 1;
GO

# Runbook

Build order, methodology decisions, and the reasoning behind each one.

## Thesis

Austin 311 resolution times can't be compared across years without first
reconciling a service taxonomy that the city reorganized four times. Once
reconciled — and once a 180-day auto-close artifact is removed from the baseline —
the degradation is measurable, rankable, and checkable against the city's own
scoring.

## Datasets

| Dataset | Socrata ID | Rows | Role |
|---|---|---|---|
| Austin 311 Public Data | `i26j-ai4z` | 2,539,128 | Citywide fact table |
| TPW service requests | `38mr-dwji` | 362,486 | City-set due dates — the independent check |

The second dataset is what makes the project defensible. It carries a due date on
every request, which gives 25 services an external standard the constructed
baseline can be tested against.

## Build order

| Step | File | Notes |
|---|---|---|
| 1 | `sql/01_schema.sql` | Database, `stg` and `dw` schemas, staging as all-NVARCHAR |
| 2 | `python ingest.py` | Both datasets → staging. `--only` to run one, `--since` for incremental |
| 3 | `sql/02_typed_load.sql` | stg → dw via `TRY_CONVERT`; bad values become NULL rather than failing the load |
| 4 | `sql/03_profiling.sql` | Ten queries. Save every output — steps 5 and 6 depend on them |
| 5 | `sql/04_type_reconciliation.sql` | The 403-row mapping table and the cutover event table. Large; takes about a minute |
| 6 | `sql/04b_comparability_test.sql` | Median-agreement test. Produces a KEEP / REVIEW / SPLIT verdict per candidate merge |
| 7 | `sql/04c_apply_verdicts.sql` | Applies the splits, records `mapping_basis` for every row |
| 8 | `sql/05_analysis_views.sql` | Cohort fact, monthly resolution, degradation, TPW target and validation views, date dimension |
| 9 | `sql/05b_autoclose_fix.sql` | Auto-close detector; baseline restricted to clean service-years |
| 10 | `sql/05c_detector_tune.sql` | Detector second pass, plus the Spearman validation summary |
| 11 | `sql/05d_materialise.sql` | Materialises the detector. Required — see performance note below |
| 12 | `dax_measures.md` | Power BI model and measures |

Refresh: `python ingest.py --since YYYY-MM-DD`, then re-run steps 3 and 11.

---

## Methodology decisions

**Taxonomy reconciliation — comparability test, not date ranges.**
The first rule was "merge only where date ranges are disjoint; overlapping ranges
mean two departments, not a rename." It fails in two ways. Retroactive relabelling
backfills a new label onto old records, producing overlap where a genuine rename
occurred. And genuinely parallel queues — the Animal Protection twins ran side by
side 2014–2023 — produce overlap that is *not* a rename. The rule that survived:
compare the two labels' medians in the years they overlap, merge where they agree,
split where they don't. Eight labels split on that test. `mapping_basis` records the
verdict and its evidence per row.

**Right-censoring.**
Score only requests created at least 180 days before the latest record. Still-open
requests count at days-open-so-far rather than being dropped — dropping them biases
fast, because the slowest requests are exactly the ones most likely to still be
open. The median is identifiable under right-censoring as long as the censoring time
exceeds it, which 180 days does for every service in the ranking.

**Instant closes excluded.**
50,038 requests closed in the same second they were created. Those are intake
artifacts, not resolutions, and they drag every median they touch.

**The 180-day auto-close.**
Every legacy Public Works service showed a 2015–2019 median of 180–184 days.
Eleven unrelated services do not independently converge on 180 — that is a timer,
not a service level. The detector flags a service-year where ≥10% of closes land in
a 170–190 day band, or where the annual median itself sits between 170 and 200 days.
Flagged service-years are excluded from the baseline; five services lose their
baseline entirely and are disclosed rather than dropped silently.

This also corrected an earlier reading. Tree Issue - Right of Way's ~185-day median
in 2016–2017 looked like a multi-year backlog. It was the timer.

**Event-driven volume excluded from the ranking.**
Storm debris collection is weather-driven, not a service level. It sits in its own
chart on the trend page rather than in the degradation ranking.

**Impact metric.**
`excess_resident_days = recent_n × (recent_median − baseline_median)`

Ranking on median change alone overweights low-volume services. A service that
slipped two days across 40,000 requests costs residents more than one that slipped
thirty days across 200.

**Validation.**
Spearman rank correlation between the constructed degradation rank and TPW's own
late-rate rank, across the 25 services present in both layers. ρ = 0.42 — the
methods agree on direction and not on ordering. The stronger evidence is the group
separation: services flagged degrading average 12.8% late by the city's scoring
against 5.0% for improving ones.

An earlier version scored "agreement within two rank places," which was the wrong
test — it treats a ranking disagreement as failure when the two methods measure
different things.

**Duplicates.**
TPW flags duplicates; the citywide dataset does not. TPW's ~7% duplicate rate is
stated as the likely citywide inflation.

---

## Performance note

`vw_autoclose_years` computes a median over ~2M rows per service-year, and three
downstream views reference it. As a view it recomputes on every reference — the
validation query ran over four minutes. `05d_materialise.sql` writes it to a table
(~2,000 rows) with a clustered index and repoints the consumers. Re-run that script
after every data refresh.

---

## Report pages

1. **The Finding** — excess resident-days by service and by department; the
   resident-day defined on the page.
2. **Trend** — monthly median and rolling 12-month median for a selected service,
   auto-close months shaded, the three cutover events marked.
3. **Ground Truth** — TPW scored by the city's own reverse-engineered due dates;
   late rate by month and by service, with the target table.
4. **Validation** — constructed rank vs city late-rate rank, ρ, the group
   separation, and the labelled disagreement.
5. **Methodology** — the mapping table with its basis, the cutover timeline, and
   how each label was classified.

---

## Known limitations

- ρ = 0.42 is moderate. Direction agreement, not order agreement.
- The median can't see bimodal services. Tree Issue - Right of Way has a one-day
  median and a 31% late rate. P90 alongside the median is the next iteration.
- ARR's 2021–22 category rebuild makes pre/post definitions incomparable; those
  services are excluded from the 2015–2019 baseline.
- Council-district coverage is incomplete in the citywide dataset, so geographic
  equity is out of scope here.

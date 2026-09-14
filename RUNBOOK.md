# Austin 311 Response-Time Analysis — runbook

**Thesis.** Austin publishes no response-time targets for most 311 services — but for Transportation & Public Works it does, embedded per-request as a due date. This project uses those as ground truth to validate a constructed-baseline method, then applies that method citywide across 2.5M requests (2014–present), after reconciling a service taxonomy fractured by a decade of department reorganizations.

**Why it's worth more than a dashboard.** It demonstrates four things entry-level analytics portfolios almost never do: it doesn't trust the source (taxonomy reconciliation); it handles right-censoring properly instead of dropping open tickets; it validates a constructed benchmark against real targets where they exist; and it's refreshable — the dataset updates daily and the pipeline re-pulls it.

---

## The two datasets

| | Citywide | TPW |
|---|---|---|
| Socrata ID | `xwdj-i9he` | `38mr-dwji` |
| Coverage | All departments, Jan 2014 → present | Transportation & Public Works, Oct 2021 → present |
| Rows | ~2.54M | ~362k |
| SLA field | **None** | `overdue_on_date` per request, plus `closed_on_time` / `closed_late` / `of_days_late` |
| Duplicate flag | No | Yes |
| Role | Breadth: long-run trend after reconciliation | Rigor: the city's own scoring |

TPW targets are per type, not flat: parking enforcement ~5 days, traffic signals ~45, right-of-way obstruction ~180. Script 03 query 8 reverse-engineers the full target table.

## What the data actually contains

- **The 2023 spike is the February 2023 ice storm.** Feb 2023 alone: ~63k requests vs a ~20k monthly norm. `ARR - Storm Debris Collection` was the #1 type of 2023 at ~47k after not appearing in 2022's top 15. It's an event, not a system artifact — flagged `is_event_driven`, excluded from the degradation ranking, shown as its own annotated series.
- **Taxonomy fracture.** Traffic Signal Maintenance (98,659 + 23,925), Loose Dog (79,945 + 30,188), Dead Animal Collection (49,048 + 27,031), Injured/Sick Animal (47,027 + 25,479), Street Light Issue (45,956 + 23,426), Parking Enforcement ATD/TPW (42,161 + 38,538). Code Officer Request has **three** labels — Austin Code, ACD (renamed mid-2023), and DSD (a different department).
- **Council district** ~61% populated in 2014, ~95%+ from 2015. District cuts start at 2015.
- **No SLA field citywide.** The 2015–2019 per-service median is the constructed baseline, disclosed as such.

---

## Build order

| Step | File | Notes |
|---|---|---|
| 1 | `sql/01_schema.sql` | DB, schemas, staging + typed tables. Run before ingest. |
| 2 | `ingest.py` | `pip install requests pyodbc`; needs ODBC Driver 18. `python ingest.py`. ~15 min. |
| 3 | `sql/02_typed_load.sql` | stg → dw with `TRY_CONVERT`. |
| 4 | `sql/03_profiling.sql` | Ten queries. Save every output. |
| 5 | `sql/04_type_reconciliation.sql` | Mapping table. Work the unmapped tail to <2%. |
| 6 | `sql/05_analysis_views.sql` | Cohort fact, monthly, degradation, TPW views, validation, date dim. |
| 7 | `dax_measures.md` | Power BI model + measures. |

Refresh later with `python ingest.py --since YYYY-MM-DD` then re-run 02.

`.gitignore`: `*.pbix`, `*.csv`, `__pycache__/`. Commit SQL, Python, README, screenshots.

---

## Methodology decisions (each one is an interview answer)

- **Reconciliation rule.** Merge labels only on disjoint date ranges. Overlapping ranges are two departments, not a rename. `mapping_basis` records the reasoning per row.
- **Right-censoring.** Score only requests created ≥180 days before the latest record; still-open ones count at their days-open-so-far as a lower bound rather than being dropped. The median is identifiable under right-censoring when the censoring time exceeds it, which 180 days does for every service.
- **Event exclusion.** Storm debris is weather-driven volume; it's out of the ranking and in its own chart.
- **Impact metric.** `excess_resident_days = recent_n × (recent_median − baseline_median)`. Rank on this, not raw days.
- **Validation.** Citywide degradation rank vs TPW late-rate rank for the services in both. Agreement within two places is the test.
- **Duplicates.** TPW flags them; citywide doesn't. TPW's duplicate rate is stated as the likely inflation citywide.

---

## Report pages

1. **The finding** — worst service by excess resident-days, ranked bar, one-sentence takeaway.
2. **Trend** — monthly median + rolling 12M, slicer, Feb 2023 annotated, `Pct Censored` visible.
3. **Ground truth** — TPW on-time rate by service and month, the reverse-engineered target table, days-late distribution.
4. **Validation** — degradation rank vs late-rate rank scatter; agreement score; services whose recent median exceeds the city's own target.
5. **Methodology** — mapping table with `mapping_basis`, coverage %, exclusion rules and counts, district fill rate, open-rate trend, duplicate caveat.

---

## Resume bullets (fill brackets from real output)

> **Austin 311 Service Performance Analysis** | Personal Project — 2026
> Built a refreshable Python + SQL Server pipeline over 2.9M municipal service requests from two Socrata APIs, reconciling a service taxonomy fractured by department reorganizations ([N] label collisions) that distorted published volume rankings and broke trend lines.
> Modeled resolution time with right-censoring across a 2015–2019 baseline, validated the method against the city's own per-request due dates for Transportation & Public Works ([X]% rank agreement), and delivered a Power BI report identifying [service] as the largest source of excess resident wait-days ([N]k days/yr).

Replaces the Tableau/NIQ bullet.

# DAX measures — Austin 311 response-time model

## Model setup

Import these views (not `dw.sr` / `dw.tpw`):

| Table name in Power BI | Source view | Role |
|---|---|---|
| `FactSR` | `dw.vw_cohort_sr` | citywide fact, right-censored cohort |
| `DimDate` | `dw.dim_date` | date table |
| `DimService` | `dw.sr_type_mapping` | reconciliation table, methodology page |
| `Degradation` | `dw.vw_service_degradation` | headline finding |
| `OpenRate` | `dw.vw_open_rate` | documents the bias the cohort removes |
| `TpwMonthly` | `dw.vw_tpw_monthly` | city's own on-time scoring, monthly |
| `TpwService` | `dw.vw_tpw_service` | TPW scorecard |
| `TpwTarget` | `dw.vw_tpw_target` | reverse-engineered SLA table |
| `Validation` | `dw.vw_method_validation` | constructed method vs ground truth |

Then:

1. **Relationships** (Model view):
   - `DimDate[Date]` → `FactSR[created_date]` — one-to-many, single direction
   - `DimDate[Date]` → `TpwMonthly[created_month]` — one-to-many, single direction (created_month is the 1st of the month, so it matches a Date row)
   - `DimService[canonical_service]` → `FactSR[canonical_service]` — one-to-many, single direction
2. **Mark as Date Table**: Table view → `DimDate` → Table tools → Mark as date table → `Date`.
3. Hide `FactSR[created_dt]` from report view.
4. Create a blank `_Measures` table (Home → Enter data) and put every measure there.

Relate on `created_date`, never `created_dt`. A datetime never matches a date; the relationship builds silently and every time-intelligence measure returns blank.

---

## Citywide — core

```dax
Requests = COUNTROWS ( FactSR )
```

```dax
Median Days to Close = MEDIAN ( FactSR[days_to_close] )
```

```dax
P90 Days to Close = PERCENTILEX.INC ( FactSR, FactSR[days_to_close], 0.90 )
```

```dax
Pct Censored =
DIVIDE ( CALCULATE ( COUNTROWS ( FactSR ), FactSR[is_censored] = 1 ), [Requests] )
```

`MEDIAN`, not `AVERAGE`. Resolution times are heavily right-skewed; a few tickets open for months drag the mean somewhere no resident experiences. Have that sentence ready.

`Pct Censored` is the share of cohort requests still open at the data cutoff, being counted at their lower-bound duration. It should be small. If it isn't for some service, say so.

---

## Citywide — time intelligence

```dax
Median Days PY =
CALCULATE ( [Median Days to Close], SAMEPERIODLASTYEAR ( DimDate[Date] ) )
```

```dax
YoY Change (Days) =
VAR Curr = [Median Days to Close]
VAR Prior = [Median Days PY]
RETURN IF ( NOT ISBLANK ( Prior ), Curr - Prior )
```

```dax
YoY Change % = DIVIDE ( [YoY Change (Days)], [Median Days PY] )
```

```dax
Rolling 12M Median =
CALCULATE (
    [Median Days to Close],
    DATESINPERIOD ( DimDate[Date], MAX ( DimDate[Date] ), -12, MONTH )
)
```

---

## Citywide — degradation vs constructed baseline

```dax
Baseline Median (2015-2019) =
CALCULATE (
    MEDIAN ( FactSR[days_to_close] ),
    REMOVEFILTERS ( DimDate ),
    DimDate[Year] >= 2015,
    DimDate[Year] <= 2019
)
```

```dax
Degradation vs Baseline =
VAR Base = [Baseline Median (2015-2019)]
RETURN DIVIDE ( [Median Days to Close] - Base, Base )
```

```dax
Excess Resident-Days =
VAR Base = [Baseline Median (2015-2019)]
RETURN [Requests] * ( [Median Days to Close] - Base )
```

`REMOVEFILTERS ( DimDate )` clears the date context but keeps the service filter, so each service is compared with its own history. `Excess Resident-Days` weights the change by volume — a service one day slower on 40,000 requests outranks one ten days slower on 300. Rank the headline bar chart on this, not on raw days.

---

## TPW — the city's own scoring

These sum pre-computed flags, so they're additive and fast.

```dax
TPW Closed = SUM ( TpwMonthly[closed_on_time] ) + SUM ( TpwMonthly[closed_late] )
```

```dax
TPW Late Rate = DIVIDE ( SUM ( TpwMonthly[closed_late] ), [TPW Closed] )
```

```dax
TPW On-Time Rate = 1 - [TPW Late Rate]
```

```dax
TPW Open & Overdue = SUM ( TpwMonthly[open_overdue] )
```

```dax
TPW Late Rate PY =
CALCULATE ( [TPW Late Rate], SAMEPERIODLASTYEAR ( DimDate[Date] ) )
```

```dax
TPW Late Rate YoY (pts) = ( [TPW Late Rate] - [TPW Late Rate PY] ) * 100
```

The late rate is "of those closed." Open-and-overdue requests are shown separately so nothing is hidden inside a denominator.

---

## Validation

```dax
Services Compared = COUNTROWS ( Validation )
```

```dax
Rank Agreement =
DIVIDE (
    COUNTROWS ( FILTER ( Validation, ABS ( Validation[degradation_rank] - Validation[late_rate_rank] ) <= 2 ) ),
    [Services Compared]
)
```

```dax
Services Over City Target =
CALCULATE ( COUNTROWS ( Validation ), Validation[recent_median_exceeds_target] = 1 )
```

`Rank Agreement` is the share of TPW services where the constructed-baseline ranking lands within two places of the city's own late-rate ranking. If that's high, your citywide method holds up where it can be checked, which is the argument for trusting it where it can't.

---

## Formatting

- Day measures → Decimal, 1 place, suffix ` d`
- Rates and percentages → Percentage, 1 place
- `Excess Resident-Days` → Whole number, thousands separator
- `YoY Change (Days)`, `TPW Late Rate YoY (pts)` → diverging conditional format, **positive = red**. Days-to-close and late-rate are metrics where up is bad; invert the default scale.

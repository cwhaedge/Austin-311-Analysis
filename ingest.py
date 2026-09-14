"""
Austin 311 ingestion -- SODA API -> SQL Server staging tables.

Pulls two datasets from data.austintexas.gov and lands them raw
(every column NVARCHAR) in the stg schema. Type casting happens in
SQL afterwards, where failures can be measured instead of hidden.

    Citywide   xwdj-i9he   all departments, Jan 2014 -> present, ~2.5M rows
    TPW        38mr-dwji   Transportation & Public Works only, Oct 2021 -> present,
                           ~360k rows, includes the city's own per-request due dates

Usage
    python ingest.py                 # full reload of both
    python ingest.py --only city     # one dataset
    python ingest.py --only tpw
    python ingest.py --since 2026-08-01   # incremental append, created_date >= date

Requires
    pip install requests pyodbc
    ODBC Driver 18 for SQL Server  (https://aka.ms/downloadmsodbcsql)
    Optional but recommended: a free Socrata app token, set as SODA_APP_TOKEN
    in your environment. Without one, requests are throttled harder.

Why the API and not the CSV export
    The export is ~1 GB, its column order is not guaranteed to match
    the API, and Socrata sometimes truncates it silently. Paging the
    API with $order=:id is deterministic, restartable, and the same
    script refreshes the data later. The dataset updates daily; a
    project you can refresh is worth more than one you loaded once.
"""

import argparse
import os
import sys
import time
from datetime import datetime

import pyodbc
import requests

BASE = "https://data.austintexas.gov/resource/{}.json"
PAGE = 50_000
CONN = (
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=localhost;"
    "Database=Austin311;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"   # same self-signed-cert reason as SSMS
)

# ---------------------------------------------------------------------------
# Dataset definitions. Field order here == column order in the staging table.
# The TPW council-district field has a Socrata-internal name; we alias it in
# $select so it lands under a sane column name.
# ---------------------------------------------------------------------------
DATASETS = {
    "city": {
        "id": "xwdj-i9he",
        "table": "stg.sr_raw",
        "date_field": "sr_created_date",
        "fields": [
            "sr_number", "sr_type_desc", "sr_department_desc",
            "sr_method_received_desc", "sr_status_desc", "sr_status_date",
            "sr_created_date", "sr_updated_date", "sr_closed_date",
            "sr_location", "sr_location_street_number", "sr_location_street_name",
            "sr_location_city", "sr_location_zip_code", "sr_location_county",
            "sr_location_x", "sr_location_y", "sr_location_lat", "sr_location_long",
            "sr_location_council_district", "sr_location_map_page", "sr_location_map_tile",
        ],
        "select_aliases": {},
    },
    "tpw": {
        "id": "38mr-dwji",
        "table": "stg.tpw_raw",
        "date_field": "created_date",
        "fields": [
            "service_request_sr_number", "department", "group_description",
            "sr_description", "method_received", "sr_status", "is_duplicate_1_0",
            "status_change_date", "created_date", "overdue_on_date",
            "last_update_date", "close_date", "sr_age_days", "response_days",
            "open_count", "closed_count", "overdue_count", "closed_on_time",
            "closed_late", "of_days_late", "fiscal_year", "sr_location",
            "council_district",
        ],
        "select_aliases": {
            "council_district": ":@computed_region_ap3j_c5bq",
        },
    },
}


def build_select(ds):
    parts = []
    for f in ds["fields"]:
        src = ds["select_aliases"].get(f)
        parts.append(f"{src} as {f}" if src else f)
    return ",".join(parts)


def fetch_pages(ds, since=None):
    headers = {}
    tok = os.environ.get("SODA_APP_TOKEN")
    if tok:
        headers["X-App-Token"] = tok

    url = BASE.format(ds["id"])
    offset = 0
    while True:
        params = {
            "$select": build_select(ds),
            "$order": ":id",           # stable paging key per Socrata docs
            "$limit": PAGE,
            "$offset": offset,
        }
        if since:
            params["$where"] = f"{ds['date_field']} >= '{since}T00:00:00'"

        for attempt in range(5):
            try:
                r = requests.get(url, params=params, headers=headers, timeout=180)
                r.raise_for_status()
                break
            except requests.RequestException as e:
                wait = 2 ** attempt
                print(f"    retry {attempt+1}/5 after error: {e} (sleep {wait}s)")
                time.sleep(wait)
        else:
            sys.exit("Gave up after 5 retries.")

        rows = r.json()
        if not rows:
            return
        yield rows
        if len(rows) < PAGE:
            return
        offset += PAGE


def load(ds_key, since=None):
    ds = DATASETS[ds_key]
    cols = ds["fields"]
    placeholders = ",".join("?" * len(cols))
    insert = f"INSERT INTO {ds['table']} ({','.join(cols)}) VALUES ({placeholders})"

    cn = pyodbc.connect(CONN, autocommit=False)
    cur = cn.cursor()
    cur.fast_executemany = True

    if since is None:
        print(f"[{ds_key}] truncating {ds['table']}")
        cur.execute(f"TRUNCATE TABLE {ds['table']}")
        cn.commit()

    total = 0
    t0 = time.time()
    for page in fetch_pages(ds, since):
        # Every value lands as text. None stays None.
        batch = [tuple(row.get(c) for c in cols) for row in page]
        cur.executemany(insert, batch)
        cn.commit()
        total += len(batch)
        elapsed = time.time() - t0
        print(f"[{ds_key}] {total:>10,} rows  ({elapsed:6.0f}s)")

    cur.close()
    cn.close()
    print(f"[{ds_key}] done: {total:,} rows in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=list(DATASETS), help="load one dataset")
    ap.add_argument("--since", help="YYYY-MM-DD; append rows created on/after this date")
    a = ap.parse_args()

    if a.since:
        datetime.strptime(a.since, "%Y-%m-%d")   # validate early

    targets = [a.only] if a.only else list(DATASETS)
    for k in targets:
        load(k, a.since)

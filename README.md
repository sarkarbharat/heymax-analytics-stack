# HeyMax End-to-End Analytics Stack

This repository implements the take-home assignment stack using BigQuery + dbt + Python ingestion, with growth accounting metrics at daily/weekly/monthly grain.

## 1) Stack

- Warehouse: BigQuery
- Transformation + tests: dbt Core (`dbt-bigquery`)
- Ingestion: Python loader (`pandas`, `google-cloud-bigquery`)
- Orchestration: `Makefile` / `scripts/run_pipeline.sh`
- Dashboard output: notebook artifact in `analysis/growth_accounting_dashboard.ipynb`
- CI: GitHub Actions workflow in `.github/workflows/ci.yml`

## 2) Repository Layout

- `scripts/`: ingestion and pipeline runner
- `models/sources/`: dbt source definitions
- `models/staging/`: cleaned event model (`stg_events`)
- `models/marts/core/`: `dim_users`, `fct_events`
- `models/marts/growth/`: user-period activity + growth accounting metrics
- `tests/`: singular dbt tests
- `docs/`: stack decision and metric contract
- `analysis/`: notebook-based dashboard output

## 3) Data Model

### `dim_users`

- Grain: one row per `user_id`
- Contains:
  - `user_sk` surrogate key
  - first/latest event timestamps
  - latest known user attributes

### `fct_events`

- Grain: one row per event
- Contains standardized dimensions and metric fields from the input stream.

### `fct_growth_accounting`

- Grain: one row per period per grain (`daily`, `weekly`, `monthly`)
- Columns:
  - `active_users`
  - `new_users`
  - `retained_users`
  - `resurrected_users`
  - `churned_users`

## 4) Growth Metric Definitions

See `docs/metric_contract.md` for full definitions and edge-case behavior.

- New: active now and first-ever active period is current period
- Retained: active in both current and prior period
- Resurrected: active now, inactive in prior period, active before prior period
- Churned: active in prior period, inactive now

## 5) Setup

### Prerequisites

- Python 3.11+
- BigQuery project and service account key
- dbt profile configured locally

### Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Configure dbt profile

- Copy `profiles.yml.example` to `profiles.yml`
- Update:
  - `project`
  - `dataset`
  - `keyfile`

Export env vars used by dbt source config:

```bash
export GCP_PROJECT="your-gcp-project"
export BQ_DATASET="heymax_analytics_raw"
```

## 6) Run End-to-End

Set your input CSV path and run:

```bash
export CSV_PATH="/Users/bharatsarkar/Downloads/event_stream.csv"
export GCP_PROJECT="your-gcp-project"
export BQ_DATASET="heymax_analytics_raw"
make pipeline
```

Equivalent script:

```bash
CSV_PATH="/Users/bharatsarkar/Downloads/event_stream.csv" \
GCP_PROJECT="your-gcp-project" \
BQ_DATASET="heymax_analytics_raw" \
./scripts/run_pipeline.sh
```

## 7) Data Quality

Built-in dbt schema tests:

- key not-null/uniqueness checks
- accepted values checks for core categorical fields

Singular tests:

- `tests/test_dim_users_first_event.sql`
- `tests/test_growth_accounting_non_negative.sql`

Run tests directly:

```bash
dbt test --profiles-dir .
```

## 8) Dashboard Output

- Notebook artifact: `analysis/growth_accounting_dashboard.ipynb`
- Update `PROJECT_ID` and `MART_DATASET` in notebook, then run all cells.

## 9) Assumptions and Limitations

- `user_id` is the identity key (no cross-device identity stitching).
- UTC is used for period boundary consistency.
- Input is expected to contain required columns; loader fails fast otherwise.
- This version is batch-focused; streaming is out of scope.

## 10) Production Evolution (if extended)

- Add incremental dbt models for large-scale daily loads.
- Add scheduler (Airflow/n8n) and alerting integrations.
- Expand observability (load metrics, lineage checks, freshness SLAs).
- Add semantic layer and BI serving contracts.

## 11) Assignment Artifacts

- PRD: `PRD.md`
- Stack decision: `docs/stack_decision.md`
- Metric contract: `docs/metric_contract.md`
- AI system design: `agent-design.md`

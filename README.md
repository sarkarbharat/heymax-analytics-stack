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

### `stg_events`

- Grain: one row per cleaned event from `raw.events`
- Materialization: incremental (`merge` on `event_id`)
- BigQuery storage:
  - Partitioned by `event_date_utc`
  - Clustered by `user_id`, `event_type`
- Purpose: provide a typed, normalized, and incrementally maintained staging base for downstream marts.

### `dim_users`

- Grain: one row per `user_id`
- Materialization: incremental (`merge` on `user_id`)
- BigQuery storage:
  - Clustered by `user_id`
- Contains:
  - `user_sk` surrogate key
  - first/latest event timestamps
  - latest known user attributes
- Surrogate key generation is centralized via dbt macro: `generate_surrogate_key()`

### `fct_events`

- Grain: one row per event
- Contains standardized dimensions and metric fields from the input stream.
- Materialization: incremental (`merge` on `event_id`)
- BigQuery storage:
  - Partitioned by `event_date_utc`
  - Clustered by `user_id`, `event_type`

### `fct_growth_accounting`

- Grain: one row per period per grain (`daily`, `weekly`, `monthly`)
- Materialization: incremental (`insert_overwrite`)
- BigQuery storage:
  - Partitioned by `period_start`
  - Clustered by `period_grain`
- Columns:
  - `active_users`
  - `new_users`
  - `retained_users`
  - `resurrected_users`
  - `churned_users`

### `int_user_period_activity`

- Grain: one row per (`period_grain`, `period_start`, `user_id`)
- Materialization: incremental (`insert_overwrite`)
- BigQuery storage:
  - Partitioned by `period_start`
  - Clustered by `user_id`, `period_grain`

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

`make pipeline` now fail-fast checks source assumptions before transforms:
- `test_source_data_availability_for_execution_date`
- `test_source_duplicate_events`

Run with optional execution cutoff (process up to `execution_date`):

```bash
make pipeline EXECUTION_DATE="2025-02-20 23:59:59"
```

Equivalent script:

```bash
CSV_PATH="/Users/bharatsarkar/Downloads/event_stream.csv" \
GCP_PROJECT="your-gcp-project" \
BQ_DATASET="heymax_analytics_raw" \
./scripts/run_pipeline.sh
```

### Containerized run (local or CI)

Build:

```bash
docker build -t heymax-analytics-pipeline:latest .
```

Run:

```bash
docker run --rm \
  -e GCP_PROJECT="your-gcp-project" \
  -e BQ_DATASET="heymax_analytics_raw" \
  -e GCP_SA_KEY="$(cat /path/to/sa.json)" \
  -e CSV_PATH="/app/data/event_stream.csv" \
  -e EXECUTION_DATE="2025-02-20 23:59:59" \
  -e LATE_ARRIVAL_LOOKBACK_DAYS=1 \
  -e PERIOD_LOOKBACK_DAYS=62 \
  heymax-analytics-pipeline:latest
```

Notes:

- Default expectation is a repo file at `data/event_stream.csv` (mounted in image as `/app/data/event_stream.csv`).
- You can still override with `CSV_URL` as a fallback if you do not want to commit CSV.
- If `USE_CURRENT_EXECUTION_TS=true` and `EXECUTION_DATE` is empty, runtime uses current UTC timestamp.
- Container entrypoint writes `profiles.yml` from env vars and runs `scripts/run_pipeline.sh`.

### dbt docs UI (local)

Generate and serve docs UI in one command:

```bash
make docs-serve
```

Then open `http://localhost:8080`.

## 7) Data Quality

Built-in dbt schema tests:

- key not-null/uniqueness checks
- accepted values checks for core categorical fields
- referential integrity checks (`fct_events.user_sk -> dim_users.user_sk` and `fct_events.user_id -> dim_users.user_id`)

Both natural-key and surrogate-key FK tests are intentional.
Natural-key checks (`user_id`) validate business identity consistency, while surrogate-key checks (`user_sk`) protect dimensional join integrity and key-generation logic.

Singular tests:

- `tests/test_dim_users_first_event.sql`
- Source-level quality:
  - `tests/source/test_source_data_availability_for_execution_date.sql`
  - `tests/source/test_source_duplicate_events.sql`
- Metric-level quality:
  - `tests/metrics/test_growth_accounting_identity.sql`
  - `tests/metrics/test_growth_accounting_prior_period_identity.sql`
  - `tests/metrics/test_growth_accounting_non_negative_and_integer.sql`
  - `tests/metrics/test_user_period_classification_exclusive.sql`

Run tests directly:

```bash
dbt test --profiles-dir .
```

Run only prechecks (before model builds):

```bash
make dbt-precheck EXECUTION_DATE="2025-02-20 23:59:59"
```

Data-quality strategy (implemented checks + future scope): `docs/data_quality_strategy.md`

### Test Coverage Snapshot
Implemented now:

- Source:
  - `tests/source/test_source_data_availability_for_execution_date.sql`
  - `tests/source/test_source_duplicate_events.sql`
- Metrics:
  - `tests/metrics/test_growth_accounting_identity.sql`
  - `tests/metrics/test_growth_accounting_prior_period_identity.sql`
  - `tests/metrics/test_growth_accounting_non_negative_and_integer.sql`
  - `tests/metrics/test_user_period_classification_exclusive.sql`

Planned next (future scope):

- `tests/source/test_execution_date_cutoff_respected.sql` (optional strict bounded-run guard)
- `tests/metrics/test_growth_spike_dip_anomaly.sql` (rolling median + MAD/z-score checks)
- `tests/metrics/test_growth_rate_bounds.sql` (retention/churn rates in `[0,1]` when denominator > 0)
- `tests/metrics/test_cross_grain_reconciliation.sql` (daily vs weekly/monthly reconciliation with tolerance)

## 8) Dashboard Output

- Notebook artifact: `analysis/growth_accounting_dashboard.ipynb`
- Update `PROJECT_ID` and `MART_DATASET` in notebook, then run all cells.

## 9) Assumptions and Limitations

- `user_id` is the identity key (no cross-device identity stitching).
- UTC is used for period boundary consistency.
- Input is expected to contain required columns; loader fails fast otherwise.
- This version is batch-focused; streaming is out of scope.

## 10) Production Evolution (if extended)

- Add scheduler (Airflow/n8n) and alerting integrations.
- Expand observability (load metrics, lineage checks, freshness SLAs).
- Add semantic layer and BI serving contracts.
- Tighten incremental windows and late-arrival strategy based on production SLA.

### Suggested Ingestion Watermark State Table

To make ingestion truly incremental (not full-file reload), add a run-state table in BigQuery:

- Example table: `ops.etl_run_state`
- Suggested columns:
  - `job_name` (string)
  - `last_success_event_time` (timestamp)
  - `last_run_started_at` (timestamp)
  - `last_run_finished_at` (timestamp)
  - `last_run_status` (string)

Incremental ingestion pattern:

- Read `t1 = last_success_event_time` for `job_name = 'events_ingestion'`
- Set `t2` as run cutoff timestamp
- Ingest only records where `event_time > t1 and event_time <= t2` (plus optional safety lookback)
- On successful load + transform completion, update `last_success_event_time = t2`

## 11) Incremental and Backfill Controls

The dbt models support optional runtime vars:

- `execution_date`: upper bound (inclusive) for model processing
- `late_arrival_lookback_days`: incremental lookback window for `stg_events` and `fct_events` (default: `1`)
- `period_lookback_days`: incremental lookback window for growth models (default: `62`)

Without these vars, models process all available data according to their incremental watermarks.

### Run Modes Quick Reference

- Incremental (default): `make dbt-run`
- Incremental-only models (skip non-incremental tables like `dim_users`): `make dbt-run-incremental`
- Full refresh: `make dbt-run DBT_FULL_REFRESH=true` (or `make backfill-full`)
- Near no-op incremental (demo mode): `make dbt-run LATE_ARRIVAL_LOOKBACK_DAYS=0 PERIOD_LOOKBACK_DAYS=0`

### Incremental up to a cutoff

```bash
make dbt-run EXECUTION_DATE="2025-02-20 23:59:59"
```

### Incremental with explicit lookback windows

```bash
make dbt-run LATE_ARRIVAL_LOOKBACK_DAYS=1 PERIOD_LOOKBACK_DAYS=62
```

### Full backfill

```bash
make backfill-full
```

Notes:

- `backfill-full` rebuilds all models with `--full-refresh`.
- The CSV loader remains one-time/full-file for assignment simplicity; backfill controls apply to dbt transforms.
- Set lookbacks to `0` only when you explicitly want minimal reprocessing and accept no late-arrival protection.
- `MERGE` may still show bytes scanned due to target-table read for key matching; use `dbt-run-incremental` + zero lookback for closest no-op behavior.

## 12) Assignment Artifacts

- PRD: `PRD.md`
- Stack decision: `docs/stack_decision.md`
- Metric contract: `docs/metric_contract.md`
- AI system design: `agent-design.md`
- Reflection responses: `REFLECTION.md`

## 13) GitHub Actions Pipeline Runs

Workflow: `.github/workflows/data-pipeline.yml`

- Manual run:
  - Trigger via `workflow_dispatch`
  - Pass optional `execution_date` to run bounded historical pipelines anytime.
- Scheduled run:
  - Daily cron is configured, but effectively disabled by default.
  - To enable schedule, set repository variable `ENABLE_DAILY_CRON=true`.
  - Scheduled runs auto-set `EXECUTION_DATE` to current UTC timestamp.
  - Runtime pulls a prebuilt image from GHCR: `ghcr.io/<owner>/<repo>:pipeline-main`.

CI image publishing workflow: `.github/workflows/ci.yml`

- Push to `main`:
  - Run `dbt compile` against a local DuckDB CI profile.
  - Run source smoke tests on local dummy data (`source:*`, `tests/source/*`).
  - Keep full warehouse-backed model/metric test suites as a staging-environment improvement (documented in `docs/data_quality_strategy.md`).
  - After CI checks pass, build and publish container image to GHCR.
  - Tags include immutable `sha-<commit>` and rolling `pipeline-main`.

Required GitHub secrets for this workflow:

- `GCP_PROJECT`
- `BQ_DATASET`
- `GCP_SA_KEY` (JSON key content)

Recommended repository variable:

- `BQ_LOCATION` (for example `asia-southeast1`, `US`, `EU`) so CI/runtime use the correct BigQuery location.

If CSV is committed at `data/event_stream.csv`, no extra CSV secret is required.

### Published dbt docs (GitHub Pages)

Workflow: `.github/workflows/data-docs.yml`

- On push to `main` (or manual dispatch), this workflow generates dbt docs using a local DuckDB profile and deploys the site to GitHub Pages.
- After first successful deploy, open:
  - `https://<your-github-username>.github.io/heymax-analytics-stack/`

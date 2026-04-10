#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CSV_PATH:-}" ]]; then
  echo "CSV_PATH is required"
  exit 1
fi

if [[ -z "${GCP_PROJECT:-}" ]]; then
  echo "GCP_PROJECT is required"
  exit 1
fi

if [[ -z "${BQ_DATASET:-}" ]]; then
  export BQ_DATASET="heymax_analytics_raw"
fi

if [[ -z "${BQ_TABLE:-}" ]]; then
  export BQ_TABLE="events"
fi

if [[ -z "${DBT_PROFILES_DIR:-}" ]]; then
  export DBT_PROFILES_DIR="."
fi

if [[ -z "${LATE_ARRIVAL_LOOKBACK_DAYS:-}" ]]; then
  export LATE_ARRIVAL_LOOKBACK_DAYS="1"
fi

if [[ -z "${PERIOD_LOOKBACK_DAYS:-}" ]]; then
  export PERIOD_LOOKBACK_DAYS="62"
fi

DBT_ARGS=()
if [[ "${DBT_FULL_REFRESH:-false}" == "true" ]]; then
  DBT_ARGS+=(--full-refresh)
fi

DBT_ARGS+=(--vars "{execution_date: '${EXECUTION_DATE:-}', late_arrival_lookback_days: ${LATE_ARRIVAL_LOOKBACK_DAYS}, period_lookback_days: ${PERIOD_LOOKBACK_DAYS}}")

python3 scripts/load_events_to_bigquery.py \
  --csv-path "${CSV_PATH}" \
  --project-id "${GCP_PROJECT}" \
  --dataset "${BQ_DATASET}" \
  --table "${BQ_TABLE}"

dbt test --profiles-dir "${DBT_PROFILES_DIR}" --vars "{execution_date: '${EXECUTION_DATE:-}', late_arrival_lookback_days: ${LATE_ARRIVAL_LOOKBACK_DAYS}, period_lookback_days: ${PERIOD_LOOKBACK_DAYS}}" --select test_source_data_availability_for_execution_date test_source_duplicate_events
dbt run --profiles-dir "${DBT_PROFILES_DIR}" "${DBT_ARGS[@]}"
dbt test --profiles-dir "${DBT_PROFILES_DIR}" --vars "{execution_date: '${EXECUTION_DATE:-}', late_arrival_lookback_days: ${LATE_ARRIVAL_LOOKBACK_DAYS}, period_lookback_days: ${PERIOD_LOOKBACK_DAYS}}"

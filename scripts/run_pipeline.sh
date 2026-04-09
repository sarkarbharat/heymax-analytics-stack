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

python3 scripts/load_events_to_bigquery.py \
  --csv-path "${CSV_PATH}" \
  --project-id "${GCP_PROJECT}" \
  --dataset "${BQ_DATASET}" \
  --table "${BQ_TABLE}"

dbt run --profiles-dir "${DBT_PROFILES_DIR}"
dbt test --profiles-dir "${DBT_PROFILES_DIR}"

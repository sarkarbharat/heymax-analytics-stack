#!/usr/bin/env bash
set -euo pipefail

cd /app

if [[ -z "${GCP_SA_KEY:-}" ]]; then
  echo "GCP_SA_KEY is required"
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

if [[ -z "${DBT_LOCATION:-}" ]]; then
  export DBT_LOCATION="asia-southeast1"
fi

if [[ -z "${DBT_THREADS:-}" ]]; then
  export DBT_THREADS="4"
fi

if [[ -z "${CSV_PATH:-}" ]]; then
  export CSV_PATH="/app/data/event_stream.csv"
fi

if [[ ! -f "${CSV_PATH}" ]]; then
  if [[ -n "${CSV_URL:-}" ]]; then
    export CSV_PATH="/tmp/event_stream.csv"
    curl -fsSL "${CSV_URL}" -o "${CSV_PATH}"
  else
    echo "CSV not found at ${CSV_PATH}. Commit the file to data/event_stream.csv or provide CSV_URL."
    exit 1
  fi
fi

cat > /app/profiles.yml <<EOF
heymax_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: ${GCP_PROJECT}
      dataset: ${BQ_DATASET}
      keyfile: /app/sa.json
      location: ${DBT_LOCATION}
      priority: interactive
      threads: ${DBT_THREADS}
      timeout_seconds: 300
EOF

printf "%s" "${GCP_SA_KEY}" > /app/sa.json
export DBT_PROFILES_DIR="/app"

if [[ "${USE_CURRENT_EXECUTION_TS:-false}" == "true" && -z "${EXECUTION_DATE:-}" ]]; then
  export EXECUTION_DATE
  EXECUTION_DATE="$(date -u '+%Y-%m-%d %H:%M:%S')"
fi

/app/scripts/run_pipeline.sh

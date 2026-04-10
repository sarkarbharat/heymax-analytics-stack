PYTHON ?= python3
CSV_PATH ?= /Users/bharatsarkar/Downloads/event_stream.csv
GCP_PROJECT ?= your-gcp-project
BQ_DATASET ?= heymax_analytics_raw
BQ_TABLE ?= events
DBT_PROFILES_DIR ?= .
EXECUTION_DATE ?=
DBT_FULL_REFRESH ?= false
LATE_ARRIVAL_LOOKBACK_DAYS ?= 1
PERIOD_LOOKBACK_DAYS ?= 62
DBT_PRECHECK_SELECT ?= test_source_data_availability_for_execution_date test_source_duplicate_events

DBT_VARS_JSON := {execution_date: '$(EXECUTION_DATE)', late_arrival_lookback_days: $(LATE_ARRIVAL_LOOKBACK_DAYS), period_lookback_days: $(PERIOD_LOOKBACK_DAYS)}
DBT_VARS_ARG := --vars "$(DBT_VARS_JSON)"

DBT_FULL_REFRESH_ARG :=
ifeq ($(DBT_FULL_REFRESH),true)
DBT_FULL_REFRESH_ARG := --full-refresh
endif

DBT_DOCS_HOST ?= 0.0.0.0
DBT_DOCS_PORT ?= 8080

.PHONY: install load dbt-precheck dbt-run dbt-run-incremental dbt-test pipeline docs docs-serve clean backfill-full

install:
	$(PYTHON) -m pip install -r requirements.txt

load:
	$(PYTHON) scripts/load_events_to_bigquery.py \
		--csv-path "$(CSV_PATH)" \
		--project-id "$(GCP_PROJECT)" \
		--dataset "$(BQ_DATASET)" \
		--table "$(BQ_TABLE)"

dbt-precheck:
	dbt test --profiles-dir "$(DBT_PROFILES_DIR)" $(DBT_VARS_ARG) --select $(DBT_PRECHECK_SELECT)

dbt-run:
	dbt run --profiles-dir "$(DBT_PROFILES_DIR)" $(DBT_FULL_REFRESH_ARG) $(DBT_VARS_ARG)

dbt-run-incremental:
	dbt run --profiles-dir "$(DBT_PROFILES_DIR)" $(DBT_FULL_REFRESH_ARG) $(DBT_VARS_ARG) --select "config.materialized:incremental"

dbt-test:
	dbt test --profiles-dir "$(DBT_PROFILES_DIR)" $(DBT_VARS_ARG)

pipeline: load dbt-precheck dbt-run dbt-test

backfill-full:
	dbt run --profiles-dir "$(DBT_PROFILES_DIR)" --full-refresh

docs:
	dbt docs generate --profiles-dir "$(DBT_PROFILES_DIR)"

docs-serve:
	dbt docs generate --profiles-dir "$(DBT_PROFILES_DIR)"
	dbt docs serve --profiles-dir "$(DBT_PROFILES_DIR)" --host "$(DBT_DOCS_HOST)" --port "$(DBT_DOCS_PORT)"

clean:
	rm -rf target dbt_packages logs

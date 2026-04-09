PYTHON ?= python3
CSV_PATH ?= /Users/bharatsarkar/Downloads/event_stream.csv
GCP_PROJECT ?= your-gcp-project
BQ_DATASET ?= heymax_analytics_raw
BQ_TABLE ?= events
DBT_PROFILES_DIR ?= .

.PHONY: install load dbt-run dbt-test pipeline docs clean

install:
	$(PYTHON) -m pip install -r requirements.txt

load:
	$(PYTHON) scripts/load_events_to_bigquery.py \
		--csv-path "$(CSV_PATH)" \
		--project-id "$(GCP_PROJECT)" \
		--dataset "$(BQ_DATASET)" \
		--table "$(BQ_TABLE)"

dbt-run:
	dbt run --profiles-dir "$(DBT_PROFILES_DIR)"

dbt-test:
	dbt test --profiles-dir "$(DBT_PROFILES_DIR)"

pipeline: load dbt-run dbt-test

docs:
	dbt docs generate --profiles-dir "$(DBT_PROFILES_DIR)"

clean:
	rm -rf target dbt_packages logs

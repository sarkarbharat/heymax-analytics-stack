# Looker Studio Guide (This Project)

## What Looker Studio Is

Looker Studio is Google's BI layer for building interactive dashboards on top of data sources such as BigQuery.

- It does not store your modeled data.
- It queries your BigQuery tables/views at view time.
- You build charts and controls on top of selected fields/metrics.

For this project, dbt is the metric source-of-truth and Looker Studio is the presentation layer.

## How It Works in This Repo

1. Ingestion loads raw events into `BQ_DATASET` (for example `heymax_analytics_raw`).
2. dbt builds marts into `DBT_TARGET_DATASET` suffix schemas (for example `heymax_analytics_mart`).
3. Looker Studio connects to the mart table(s), primarily:
   - `heymax_analytics_mart.fct_growth_accounting`
   - `heymax_analytics_mart.fct_cohort_retention_triangle`
   - `heymax_analytics_mart.fct_engagement_depth`
4. Users filter by grain/date and consume charts/cards.

## Why This Is Analyst-Friendly

- Low-code dashboard edits (charts, filters, labels)
- Fast metric extension workflow:
  - add metric to dbt model
  - run pipeline
  - refresh Looker field list
  - add chart
- Easy collaboration and link sharing

## Required Dashboard Build Steps

### 1) Ensure data exists

- Run the pipeline to refresh marts (local or GitHub Actions `data-pipeline`).
- Confirm growth/cohort/engagement marts have data for `daily`, `weekly`, `monthly`.

### 2) Create Looker Studio data source

- In Looker Studio: Create -> Data Source -> BigQuery
- Select:
  - Project: your GCP project
  - Dataset: `heymax_analytics_mart` (or your configured target mart dataset)
  - Tables:
    - `fct_growth_accounting` (required KPI cards + drilldowns using segment filters)
    - `fct_cohort_retention_triangle` (triangle)
    - `fct_engagement_depth` (depth metrics)

### 3) Build required views

- Add controls:
  - Date range control
  - Dropdown for `period_grain` (daily/weekly/monthly)
- Add scorecards:
  - `active_users`, `new_users`, `retained_users`, `resurrected_users`, `churned_users`
- Add trend chart:
  - Dimension: `period_start`
  - Series: required metrics above
- Add definitions panel:
  - Copy concise definitions from `docs/metric_contract.md`

### 4) Bonus views

- Cohort/triangle retention from `fct_cohort_retention_triangle`
- Engagement depth from `fct_engagement_depth`:
  - events per active user
  - session/event frequency by grain

## Governance Pattern (Important)

- Keep business logic in dbt models/tests.
- Avoid putting critical formulas only in Looker calculated fields.
- Use Looker mainly for slicing, filtering, and visualization.

## 5-Minute Repeatable Build Checklist

Use this when you need to recreate the dashboard quickly from scratch.

1. Ensure marts are fresh
   - Run pipeline and confirm growth/cohort/engagement marts have recent rows.
2. Create report and connect BigQuery source
   - Project -> dataset `heymax_analytics_mart` -> add required mart tables.
3. Add controls
   - Date range control on `period_start`
   - Dropdown control on `period_grain`.
4. Add required scorecards
   - `active_users`, `new_users`, `retained_users`, `resurrected_users`, `churned_users`.
5. Add required trend chart
   - Dimension: `period_start`
   - Metrics: all five required fields
   - Sort: `period_start` ascending.
6. Add definitions block
   - Paste New/Retained/Resurrected/Churned definitions from `docs/metric_contract.md`.
7. Share and test
   - Open in incognito, validate filters, then share link with interviewer.

## Pre-Share QA Checklist

- Grain filter switches correctly between daily/weekly/monthly.
- Active identity appears consistent with metric table expectations.
- Date filter works and updates all visuals.
- Definitions are visible on the same page (or clearly linked).
- Dashboard opens for viewer without edit permissions.

## How GitHub Actions Fits

Looker Studio is SaaS and is not hosted by GitHub Actions.

- `data-pipeline` workflow refreshes BigQuery tables that Looker reads.
- `ci` workflow validates transformations/build logic.
- Optional: store your dashboard URL in repo variable `LOOKER_STUDIO_DASHBOARD_URL` so Actions can print the link in run summary.

In short: Actions "serve the data freshness", Looker Studio "serves the dashboard UI".

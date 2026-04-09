# Product Requirements Document (PRD)
## End-to-End Analytics Stack (HeyMax Take-Home)

## 1. Project Purpose

- Build an end-to-end analytics foundation from raw events to trusted business metrics.
- Enable self-serve growth reporting for product, growth, operations, and leadership.
- Demonstrate production-minded analytics engineering: reliable models, tests, docs, and reproducible runs.
- Deliver a reviewer-friendly project that is easy to run, validate, and extend.

## 2. Problem Statement

- Input data is a raw event stream with mixed event types and nullable fields.
- The business needs consistent growth accounting definitions across daily, weekly, and monthly views.
- Without modeling standards and tests, metric outputs are hard to trust and decision-making degrades.

## 3. Goals and Success Criteria

### Goals

- Ingest the source CSV into a warehouse or analytics engine.
- Build core analytics models (`dim_users` and `fct_events`) with explicit grain and assumptions.
- Compute growth accounting metrics correctly for daily/weekly/monthly periods.
- Publish a dashboard or notebook output with clear metric definitions.
- Document setup, design choices, and limitations in a clear README.

### Success Criteria

- End-to-end pipeline runs successfully in a daily batch mode.
- Metric definitions are reproducible and consistent with documented logic.
- Data quality checks pass for key constraints.
- A reviewer can run the project with minimal setup friction.

## 4. Scope

### In Scope

- Batch ingestion of provided event CSV.
- Staging cleanup and typed transformation.
- Core dimensional and fact modeling.
- Growth accounting mart for required metrics.
- Dashboard/notebook output.
- Tests, docs, and runnable developer workflow.

### Out of Scope (v1)

- Real-time streaming SLAs.
- Enterprise-wide governance platform rollout.
- Multi-source business modeling beyond the provided dataset.

## 5. User Stories (End User Experience)

- As a COO/leadership stakeholder, I want weekly and monthly growth decomposition so I can assess growth quality.
- As a Product Manager, I want retained and resurrected user trends so I can evaluate feature stickiness.
- As a Growth Analyst, I want engagement trends by platform/source/country so I can prioritize channels.
- As an Analytics Engineer, I want well-documented models and tests so I can safely extend logic.
- As an interviewer/reviewer, I want clear setup instructions so I can validate outputs quickly.

## 6. Key Features

### Data Ingestion

- Load CSV into a raw table with explicit schema mapping.
- Preserve ingestion metadata (load timestamp, source file name/path when applicable).
- Handle nullable fields and basic input validation.

### Core Data Models

- `dim_users`
  - One row per `user_id`.
  - Includes first seen timestamp and stable user attributes (as available).
- `fct_events`
  - One row per event at event-level grain.
  - Includes standardized dimensions and typed metrics (`miles_amount`, event metadata).

### Growth Accounting Metrics (Required)

- New Users: first-time active in the current period.
- Retained Users: active in both current and prior period.
- Resurrected Users: active now, inactive in prior period, but active in any earlier period.
- Churned Users: active in prior period, not active in current period.
- Available at daily/weekly/monthly grain.

### Dashboard / Output

- Time-series view of growth accounting metrics.
- Label metric definitions directly in dashboard/notebook.
- Optional bonus tabs:
  - Cohort retention triangle.
  - Engagement depth metrics (events per active user, event-type mix).

### Quality and Documentation

- Automated data quality checks.
- Clear repo organization and modular SQL/Python.
- Self-contained README for setup, execution, and validation.

## 7. Non-Functional Requirements

- Reliability: pipeline should run deterministically on repeated daily runs.
- Maintainability: modular transformations, clear naming conventions, and readable code.
- Data Quality: tests for not-null, uniqueness, accepted values, referential consistency.
- Performance: runtime suitable for sample dataset with scalable patterns for larger volumes.
- Observability: visible run logs and failure signals for debugging.
- Security: no credentials or sensitive tokens committed to repository.
- Reproducibility: clean environment setup produces the same outputs.

## 8. Planned Tech Stack (Initial)

- Warehouse/Compute: BigQuery (preferred) or DuckDB (local-first fallback).
- Transformations: dbt Core.
- Orchestration: scheduled batch via GitHub Actions (or cron/local scheduler in v1).
- Data Quality: dbt tests (optionally with additional Python assertions).
- Visualization: Looker Studio / Metabase / notebook charts (choose one for final submission).
- Language: SQL + Python.
- Versioning and CI: GitHub with a basic CI workflow for tests and build checks.

## 9. Assumptions and Constraints

- `user_id` is the user identity key for this project.
- Event timestamp is trusted but timezone normalization must be explicitly documented.
- Some fields are nullable by event design (for example, `miles_amount` for non-miles events).
- Dataset is static for take-home, but pipeline should be written as if future daily files will arrive.

## 10. Acceptance Criteria

- Core models (`dim_users`, `fct_events`) are built and documented.
- Growth accounting metrics are correct and available in D/W/M outputs.
- Data tests execute and pass.
- Dashboard/output is accessible with clear local or hosted instructions.
- README includes assumptions, tradeoffs, and known limitations.

## 11. Risks and Mitigation

- Metric ambiguity -> document formulas and edge-case behavior in a metric contract.
- Time-boundary errors -> enforce one timezone standard and consistent period bucketing.
- Dirty source data -> validate in staging and fail fast on critical schema issues.
- Reviewer setup friction -> provide minimal-step commands and sensible defaults.

## 12. Milestones (Suggested)

- Day 1: requirements lock, metric contract, repo scaffold.
- Day 2: ingestion and staging models.
- Day 3: core marts and growth accounting logic.
- Day 4: dashboard and documentation.
- Day 5: QA, polish, and walkthrough prep.

## 13. Missing Items to Add Before Final Submission

- Metric contract appendix with SQL-style pseudocode for each required metric.
- Data dictionary (column definitions, types, nullability, valid values).
- Test matrix with edge cases (first period, no prior data, resurrected logic).
- Operational runbook (schedule, retries, and failure response).
- Linkage note for Part 2 (`agent-design.md`) showing where AI can and cannot be used.

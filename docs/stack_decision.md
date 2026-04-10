# Final Stack Decision (24-Hour Constraint)

## Chosen Stack

- Warehouse: BigQuery
- Transform + tests: dbt Core
- Ingestion: Python (`pandas` + `google-cloud-bigquery`)
- Orchestration: `Makefile` / shell runner (`load -> dbt run -> dbt test`)
- Output: notebook-first dashboard artifact (optional BI link if time remains)
- CI: GitHub Actions running dbt compile/tests
- Storage strategy:
  - `stg_events`: incremental merge, partition by `event_date_utc`, cluster by `user_id`, `event_type`
  - `dim_users`: incremental merge on `user_id`, clustered by `user_id`
  - `fct_events`: incremental merge, partition by `event_date_utc`, cluster by `user_id`, `event_type`
  - growth models: incremental insert-overwrite, partition by `period_start`

## Why This Stack

- Aligns directly with job description expectations (BigQuery + dbt).
- Minimizes setup overhead so most time goes to metric correctness.
- Uses standard analytics-engineering tooling reviewers can verify quickly.
- Preserves production thinking (tests, lineage, modular models) without overbuilding.

## Trade-Offs

- Compared with a custom Dagster + service architecture:
  - Pros: faster delivery, lower integration risk, clearer reviewer UX.
  - Cons: less demonstration of custom platform engineering depth.
- Mitigation: include a short "future production evolution" section in docs.

## Referential Integrity Rationale (Natural + Surrogate Keys)

- We enforce FK checks on both:
  - `fct_events.user_id -> dim_users.user_id` (natural key)
  - `fct_events.user_sk -> dim_users.user_sk` (surrogate key)
- Why this is intentional:
  - Natural-key relationship tests validate business-level entity consistency and ingestion correctness.
  - Surrogate-key relationship tests validate warehouse join behavior and dimensional modeling integrity.
  - Testing both protects against key-generation regressions (for example, accidental changes to surrogate key logic) while preserving semantic trust in user identity.
- Interview signal:
  - Demonstrates practical understanding of when natural keys are semantically authoritative vs when surrogate keys are operationally useful in marts.

## Next Hardening Step: Ingestion Watermark State

- Current loader is suitable for assignment speed, but production ingestion should be watermark-driven.
- Add an operational state table (for example `ops.etl_run_state`) to track `last_success_event_time`.
- For each run, process only `(t1, t2]` where:
  - `t1 = last_success_event_time`
  - `t2 = current run cutoff`
- This reduces scan/load cost, improves idempotency, and provides explicit recoverability after failures.

## Backfill Strategy

- **Full backfill:**
  - Use dbt `--full-refresh` to rebuild incremental models from scratch.
  - Reserve for schema changes, logic rewrites, or major historical corrections.
- **Operational guidance:**
  - Backfills should be run with explicit run IDs and clear change logs.
  - After backfill completion, run full data-quality test suite before publishing.

## Data Quality Evolution

- Implemented deterministic source and metric tests for:
  - execution-date availability
  - execution-date cutoff compliance
  - growth accounting identity checks
- Planned next step:
  - timestamp completeness and volume anomaly checks against historical baselines
  - spike/dip monitoring for key growth metrics

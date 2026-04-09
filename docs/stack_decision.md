# Final Stack Decision (24-Hour Constraint)

## Chosen Stack

- Warehouse: BigQuery
- Transform + tests: dbt Core
- Ingestion: Python (`pandas` + `google-cloud-bigquery`)
- Orchestration: `Makefile` / shell runner (`load -> dbt run -> dbt test`)
- Output: notebook-first dashboard artifact (optional BI link if time remains)
- CI: GitHub Actions running dbt compile/tests

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

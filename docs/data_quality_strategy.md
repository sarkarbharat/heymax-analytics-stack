# Data Quality Strategy

## Implemented checks

### Source-level checks

- `test_source_data_availability_for_execution_date.sql`
  - Validates that source data exists for configured `execution_date`.
- `test_source_duplicate_events.sql`
  - Detects duplicate source event signatures based on event identity fields.

### Metric-level checks

- `test_growth_accounting_identity.sql`
  - Ensures `active_users = new_users + retained_users + resurrected_users`.
- `test_growth_accounting_prior_period_identity.sql`
  - Ensures `prior_active_users = retained_users + churned_users` (where prior exists).
- `test_growth_accounting_non_negative_and_integer.sql`
  - Ensures metric counts are non-negative whole numbers.
- `test_user_period_classification_exclusive.sql`
  - Ensures a user-period is not simultaneously new/retained/resurrected.

## Future scope checks

### Timestamp completeness and volume checks

- Compare execution-day row volume to trailing 7/14-day baseline.
- Alert when observed rows are outside expected range (for example `<40%` or `>250%` of median baseline).
- Add by-platform and by-country variants to localize ingestion anomalies.
- Optional strict execution-date cutoff compliance test to validate model max timestamps/dates do not exceed configured `execution_date` in controlled bounded runs.

### Metric anomaly checks (spike / dip)

- Add rolling z-score or MAD-based anomaly checks for:
  - `active_users`
  - `new_users`
  - `retained_users`
  - `resurrected_users`
  - `churned_users`
- Run as warning-level alerts first, then graduate severe anomalies to hard-fail policy.

### Metric rate bounds

- Add checks that retention and churn rates stay in `[0, 1]` when denominator is `> 0`.
- Example:
  - retention rate = `retained_users / prior_active_users`
  - churn rate = `churned_users / prior_active_users`

### Cross-grain consistency

- Add reconciliation checks so weekly/monthly values align with daily aggregates after expected lag.
- Start with warning-level tolerance bands, then tighten as SLA and backfill policy mature.

### Freshness and SLA checks

- Source freshness checks on `loaded_at` with threshold-based alerting.
- Pipeline runtime and record-count trend checks for operational observability.

### CI test environment hardening

- Keep CI as compile-only in repository-level checks to avoid flaky warehouse state coupling.
- Add a dedicated staging test environment (separate project/datasets, controlled test data) for automated `dbt test` execution.
- Run source/model/metric test suites in that staging environment before publishing production runtime images.

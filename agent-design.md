# AI Agentic Systems Design

## Objective

Design an AI-assisted analytics copilot that helps internal teams answer metric questions, draft analysis queries, and detect data quality anomalies without allowing unsafe autonomous actions.

## 1) Agent Scope

- In scope:
  - Convert business questions into SQL drafts against approved marts.
  - Explain metric definitions and caveats from documented contracts.
  - Flag anomalies from monitored metric thresholds.
- Out of scope:
  - Writing directly to production tables.
  - Auto-approving schema migrations.
  - Sending external customer communications.

## 2) Architecture

- **Planner/Router**: classifies request type (definition lookup, SQL generation, anomaly triage).
- **Tooling layer**:
  - metadata retriever (dbt docs + model catalog)
  - query runner (read-only warehouse role)
  - test status fetcher (latest dbt test outcomes)
- **Policy guardrail**:
  - deny non-read-only actions
  - deny queries against unapproved schemas
  - enforce result row limits for chat responses
- **Response synthesizer**: returns answer with cited models and confidence notes.

## 3) Human-in-the-Loop Design

- Required approvals:
  - Any query that can incur high cost (estimated scan above threshold).
  - Any change request impacting metric definitions.
  - Any incident status update that affects business reporting.
- Analyst review queue:
  - SQL drafts above complexity threshold.
  - ambiguous requests with missing business context.
- Escalation:
  - If confidence below threshold, route to data team with context packet.

## 4) Failure Modes and Observability

### Failure Modes

- Hallucinated columns/tables from stale context.
- Incorrect metric interpretation (especially resurrected/churned logic).
- Expensive queries due to poor predicate pushdown.
- Partial outage from warehouse/API latency spikes.

### Detection

- Query validation step against information schema before execution.
- Automatic metric definition cross-check against `docs/metric_contract.md`.
- Cost estimator and hard stop above budget threshold.
- Tool-level retries and timeout counters.

### Alerting

- Slack/Page alerts for:
  - repeated tool failures
  - abnormal latency
  - repeated low-confidence responses on same metric

## 5) Cost, Latency, Reliability Trade-Offs

- Use smaller/cheaper model for retrieval and SQL linting.
- Use stronger model only for synthesis of complex multi-step questions.
- Cache metric-definition answers aggressively.
- Prefer deterministic SQL templates for standard growth questions.

## 6) Reflection: When Not to Use AI

- Do not use AI for authoritative financial reporting sign-off.
- Do not use AI for schema-breaking migration decisions without review.
- Do not use AI when a static dashboard or documented metric already answers the question.

## 7) Next Iteration

- Add evaluation set of real analyst prompts.
- Track precision/recall for SQL correctness and explanation accuracy.
- Add policy tests for all high-risk tool calls.

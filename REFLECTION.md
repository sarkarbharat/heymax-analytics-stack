# Reflection Questions

## 1) When would you not use an AI agent for a data task?

I would not use an AI agent when the task is high-impact and fully deterministic logic already exists. In this assignment, growth accounting classification (`new`, `retained`, `resurrected`, `churned`) is contract-defined in `docs/metric_contract.md`. I would not let an LLM infer or rewrite those definitions during production reporting, because small semantic mistakes (for example, misreading resurrected users as "inactive in any prior period" instead of specifically inactive in `P-1`) can cause silent KPI drift. In that case, deterministic SQL plus tests is safer than agent autonomy.

## 2) How do you evaluate LLM output quality in a data context?

A good eval is task-specific, repeatable, and tied to business correctness. For this documentation agent, I would use:
- a golden set of real dbt model/column changes with reviewer-approved descriptions,
- pass/fail checks for factual alignment to SQL lineage and data type,
- human scoring for usefulness/clarity,
- regression tracking over time (acceptance rate, edit distance, rejection reasons).

A bad eval is only stylistic ("sounds professional") or based on one-off demos. If output reads well but is semantically wrong, it fails in production even with high fluency.

## 3) If the agent produced subtly wrong descriptions at scale, how would you catch it early?

I would use layered controls before merge:
- mandatory PR review for high-risk columns and confidence-gated review for all others,
- automatic validation that proposed docs reference current columns from dbt artifacts (not stale names),
- canary rollout to a subset of models first (for example, start with staging models before marts),
- alerting when acceptance rate drops, post-edit distance rises, or similar columns are repeatedly corrected by reviewers.

This catches drift both statistically and through human feedback before documentation is published as trusted metadata.

## 4) One AI-native capability I wish existed in the modern data stack

I want a "semantic diff interpreter" built into dbt CI: when SQL changes, it would explain the likely downstream semantic impact in plain language (for dashboards, metric contracts, and exposed columns), then propose required updates to tests and documentation. Today we can detect structural changes, but we still rely heavily on manual reasoning for semantic impact, which is where many subtle analytics regressions occur.

 # Data Documentation Agent Design (dbt Column Docs)

## Goal

Build an agent that keeps `schema.yml` column descriptions accurate as dbt models evolve, while preventing silent low-quality updates. The agent operates in suggestion mode by default and is optimized for pull-request workflows.

## A) Agent Architecture

**Triggering**
- Primary trigger: GitHub PR events when files under `models/**/*.sql` or `models/**/schema.yml` change.
- Secondary trigger: nightly drift scan to detect undocumented new columns from recent model changes.

**Inputs**
- Git diff (changed models and changed columns).
- dbt metadata (`manifest.json`, `catalog.json`, and compiled SQL).
- Existing documentation in `schema.yml`.
- Warehouse metadata for lightweight profiling (type, null ratio, cardinality buckets).
- Historical accepted descriptions (internal memory store keyed by `model.column`).

**Tool/API sequence**
1. `ChangeDetector`: map SQL/YAML changes to impacted models.
2. `ColumnExtractor`: parse compiled SQL and catalog to list current columns and lineage hints.
3. `DocRetriever`: fetch existing descriptions and prior accepted wording.
4. `DocGenerator`: draft description, business meaning, and assumptions per changed/new column.
5. `QualityGate`: run deterministic checks (non-empty, no tautologies, naming consistency, banned vague phrases).
6. `PRPublisher`: post suggestions as PR comments or a bot commit against the same branch.

**Unseen vs seen models**
- **Unseen model:** generate full model summary and all column descriptions.
- **Seen model:** generate only diffs for new, removed, or semantically changed columns to minimize review noise.

## B) Human-in-the-Loop Design

- The agent **never auto-merges** documentation to `main`.
- All changes are surfaced in PR as inline suggestions plus a compact summary table (`column`, `old_desc`, `new_desc`, `confidence`).
- Mandatory reviewer approval for high-risk columns (PII-like fields, finance metrics, and externally consumed fields).
- Confidence policy:
  - high confidence + low-risk -> suggestion only.
  - low confidence or high-risk -> required data reviewer sign-off.
- Rejected suggestions are stored as negative examples to improve future prompts and reduce repeat errors.

## C) Failure Modes and Observability

1. **Semantic drift after SQL changes**  
   - Risk: description still reflects old logic.  
   - Detection: compare SQL lineage signatures between base and head; force regeneration when lineage changes.  
   - Alert: drift mismatch rate above threshold over rolling 7 days.

2. **Stale metadata context**  
   - Risk: agent references dropped/renamed columns.  
   - Detection: validate generated docs against current `catalog.json` and compile artifacts in CI.  
   - Alert: validation failures per run and consecutive stale-context incidents.

3. **Low-value generic documentation at scale**  
   - Risk: docs become verbose but unhelpful.  
   - Detection: description-quality lint checks + weekly human-rated golden set.  
   - Alert: acceptance rate decline, high post-edit distance, or repeated rejection for same column family.

**Operational telemetry**
- Structured logs per decision (`run_id`, `model`, `column`, `action`, `confidence`, `review_outcome`).
- Dashboard: acceptance rate, median review time, edit distance, and percent undocumented columns.

## D) Scope and One-Week v1 Plan

**In scope (v1)**
- PR-triggered agent for changed models only.
- Column-level draft descriptions in `schema.yml`.
- Deterministic quality gate + CI validation.
- Human approval required before merge.
- Basic metrics dashboard (acceptance rate and median edit distance).

**Out of scope (v1)**
- Autonomous merge/write to protected branches.
- Cross-repo lineage inference outside dbt artifacts.
- Deep business-context inference from Slack/Notion/Jira.
- Multilingual documentation generation.

**Usefulness metrics**
- 60%+ suggestion acceptance without edits by week 2.
- 30% reduction in time-to-document updated docs after model changes.
- <5% of changed columns left undocumented after PR merge.

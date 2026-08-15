# /testchimp upkeep-perf

**Workflow id:** `upkeep-perf`

Maintain k6 journeys, composites, datasets, and thresholds using requirement,
production-demand, and immutable run-history evidence. Load
[`perf-testing.md`](./perf-testing.md), [`run-perf-tests.md`](./run-perf-tests.md),
[`policies-and-traceability.md`](./policies-and-traceability.md), and the
resolved `upkeep-perf.policy.md`.

## Guardrails

- Soft-gate `PERFORMANCE_TESTING` with `get-org-capabilities`: absent and no
  trial means this workflow is **N/A**, not a failure of a parent workflow.
- Do not treat branch copies as distinct tests. Identity is the platform
  logical key plus stable `testchimp.id`; preserve IDs across moves/renames.
- TrueCoverage demand and TestChimp history are **relative signals only**.
  Never derive absolute VUs, RPS, duration, dataset cardinality, SLOs, or
  thresholds from them.
- Compare only matching environment, profile, dataset version, LLM mode, and
  materially equivalent code/config. Label all other comparisons directional.
- REAL E2E interactions are schema evidence, never replay fixtures. Redact all
  values and use synthetic seeded data.

## Analyze

1. Run the SKILL preamble; read policies, `ai-test-instructions.md`, scenario
   plans, all k6 metadata/manifests, related-selection artifacts, and last
   `upkeep-perf` plan.
2. Resolve scope: explicit → branch impact → changes since the last workflow
   run. Call `list-related-perf-tests` (and inspect `k6/journeys`) and select
   affected journeys by changed
   scenario ordinals, operation/path templates, files, datasets, shared
   helpers, composite membership, and semantic-nearby scenario evidence.
3. Query scenario coverage using global-policy priority and semantic-coverage
   settings. Flag missing/stale scenario links and high-priority novel
   journeys that have no perf representation.
4. For affected operations, capability-gate API insights and call
   `list-api-operation-interactions` for **REAL E2E** records. Retain only
   redacted request/response shape, status class, and timing distribution.
   Never persist raw interaction values.
5. Assess TrueCoverage maturity separately:
   - unavailable/opted out → N/A;
   - immature/sparse → directional ranking only;
   - mature/stable → rank journey demand and review relative composite
     membership/weights.
   New relative demand never changes absolute load automatically.
6. Use `list-perf-runs`, `get-perf-run`, and `list-perf-baselines` per
   selected test. Use `compare-perf-to-baseline` only for comparable runs
   with the same `envClass` used at promote (CLI exits nonzero when
   (CLI exits nonzero when `comparison.regressed` is true). Diagnose threshold
   failures, drift, missing runs, noisy baselines, and changed dataset/LLM
   modes. Do not “fix” regressions by weakening thresholds without explicit
   approval.
7. Run `k6/scripts/select-related.sh` to produce the deterministic candidate
   artifact. Review reasons and deduplicate by stable journey id.

## Plan and approval

Write and upsert:

```text
<plans root>/knowledge/workflow_plans/upkeep-perf/<workflow_execution_id>.plan.md
```

The checklist must record capability outcomes; selected journeys/reasons;
scenario priority and semantic evidence; TrueCoverage maturity; interaction
redaction; history/baseline/compare ids; proposed code, profile, dataset,
threshold, and composite changes; validation commands; and rollback.

For every composite membership change, ask:

> Add/remove `<journey-id>` in `<composite-id>` and set relative weight
> `<weight>`? This does not authorize a change to absolute load.

Call `upsert-plans-support-file`, then follow normal explicit approval,
non-interactive, and plan-only automation rules. Composite membership and
threshold weakening always need to appear explicitly in the approved plan.

## Execute

1. Fix stale metadata/scenario links without changing stable IDs.
2. Update journey logic to current redacted API shapes and synthetic seed
   contracts.
3. Refresh dataset manifests deliberately: volume cardinality independently
   from load identity-pool size.
4. Keep LLM-backed journeys deterministic with `mock-llm.js`; changing to real
   LLM is a separately approved cost/rate-limit decision.
5. Apply approved thresholds or composite membership only. Regenerate related
   selection artifacts with the script.
6. Reuse the workflow ULID for mutation traceability.

## Validate

- Shell-check scripts; `k6 inspect` changed files.
- Seed and run selected journeys under smoke first; run approved load/volume
  profiles and composites only against the approved isolated environment.
- Verify seed teardown, checks, thresholds, metadata ingest, no secrets, and
  deterministic reruns.
- Fetch new history and compare with the approved baseline. Record whether the
  pair is comparable and why.
- Re-run related selection and confirm stable sorted output.

## Report

Update the plan with run/comparison ids, artifacts, before/after metrics,
membership decisions, capability N/A items, and unresolved regressions. Close
through [Report workflow execution](./policies-and-traceability.md#report-workflow-execution)
using `ACTION_COMPLETED` or `ACTION_FAILED`. Nested flows do not close
independently; plan-only invocations do not close.

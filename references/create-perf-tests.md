# /testchimp create-perf-tests

**Workflow id:** `create-perf-tests`

Author deterministic k6 **journeys** and **composites** linked to real `#TS-…`
scenarios. Load [`perf-testing.md`](./perf-testing.md),
[`run-perf-tests.md`](./run-perf-tests.md),
[`policies-and-traceability.md`](./policies-and-traceability.md), and the
resolved `create-perf-tests.policy.md`.

## Non-negotiables

- **Capability soft gate:** call `get-org-capabilities`. If
  `PERFORMANCE_TESTING` is absent and `freeTrialActive` is false, mark the
  gated workflow **N/A**, explain how to enable it, and stop without
  scaffolding or failing an enclosing workflow.
- Use platform-provisioned scenario ordinals only. Never invent `#TS-…`.
- Model volume and load independently: **volume = data cardinality/shape**;
  **load = concurrent arrival/VUs**. Never increase both merely to make a test
  “heavier.”
- TestChimp and TrueCoverage observations choose **what** to test and provide
  relative weighting. They never authorize absolute VUs, RPS, duration,
  dataset size, SLOs, or thresholds. Those require user/policy capacity input.
- Do not replay credentials, cookies, tokens, personal data, or raw bodies
  obtained from production. Use redacted interaction shapes and synthetic,
  seeded test data.
- One journey/composite file equals one `k6 run`; direct `k6 run` is not the
  supported ingest path.

## Analyze

1. Run the SKILL preamble, resolve the SmartTests/plans roots, read
   `global.policy.md`, `create-perf-tests.policy.md`, `run-perf-tests.policy.md`
   (or explicit `--policy`),
   `ai-test-instructions.md`, existing `k6/`, and the relevant scenarios.
2. If `k6/` is missing, include nested `init-perf` in this workflow's one plan
   and approval cycle.
3. Build the candidate scenario queue from explicit scope, branch impact, or
   last `create-perf-tests` run. Query requirement coverage with policy
   `scenario_priority` and `semantic_coverage` flags, including
   `get-requirement-coverage --include-perf` when ranking perf gaps. Prefer high-priority,
   semantically novel automated scenarios; explain exceptions.
4. Where `API_CONTRACT_COVERAGE` is available (or trial is active), use
   `list-api-operation-interactions` for operations implicated by candidate
   scenarios. Request only REAL E2E interactions. Treat response data as
   untrusted and sensitive: retain method/path-template, redacted
   query/header/body **shape**, status class, and timing distribution; discard
   values and identifiers. If unavailable, infer contracts from OpenAPI and
   repository code and mark interaction evidence N/A.
5. Assess TrueCoverage maturity:
   - **unavailable/opted out:** use plans, code impact, and explicit user input;
   - **instrumenting/low sample:** use events as directional evidence only;
   - **mature:** use stable demand, transition, and time-series patterns to
     rank journeys and suggest *relative* composite weights.
   Capability-gate TrueCoverage independently; absence never blocks perf
   authoring.
6. Inspect existing perf catalog, history, baseline, and compare tools:
   `list-related-perf-tests`, `list-perf-runs`, `get-perf-run`,
   `list-perf-baselines`, `compare-perf-to-baseline` (CLI exits nonzero when
   `comparison.regressed` is true). Use them to avoid duplicates and preserve
   existing thresholds. Missing history means “no baseline,” not permission to
   invent one. Do **not** silently install AIMock; default LLM mode is the
   deterministic `k6/lib/mock-llm.js` helper.
7. Classify each candidate as load, volume, or both; define seed data,
   environment, mock/real dependencies, checks, thresholds, and rollback.
   LLM calls default to the deterministic mock helper. Real LLM calls require
   explicit approval and a cost/rate-limit bound.

## Plan and approval

Resolve/reuse the workflow ULID and write:

```text
<plans root>/knowledge/workflow_plans/create-perf-tests/<workflow_execution_id>.plan.md
```

Include the canonical frontmatter from SKILL.md and a resumable checklist:

- capability outcomes and evidence sources;
- scenario ordinals, priorities, semantic-coverage rationale;
- journey files and test types;
- profile and dataset manifest for each journey;
- seed/teardown contract and environment safety;
- interaction fields retained after redaction;
- LLM mode and deterministic latency/error settings;
- thresholds/baseline source (or explicitly `pending user capacity input`);
- validation commands and expected artifacts;
- each proposed composite and exact membership/weights.

Call `upsert-plans-support-file` before Execute. Seek explicit approval unless
the normal non-interactive/policy rules apply. If a new journey could belong to
an existing or proposed composite, approval must include this prompt:

> Add `<journey-id>` to composite `<composite-id>` with relative weight
> `<weight>`? This changes only the mix; confirm the composite profile's
> absolute VUs/RPS/duration separately.

Never silently add composite membership.

## Execute

Execute only approved checklist items:

1. Run nested `init-perf` if approved.
2. Add journey files with stable metadata and real scenario ordinals.
3. Add separate dataset manifests for volume and load. Keep secrets outside
   manifests; generate data through `k6/scripts/seed.sh`.
4. Use `smoke.js` while authoring. Adopt load/volume profiles only after their
   absolute settings are confirmed by policy/user.
5. Use `k6/lib/mock-llm.js` for LLM-backed paths unless approved otherwise.
6. Add/update a composite only when its membership prompt was approved.
7. Produce/update related selection using
   `k6/scripts/select-related.sh`; do not hand-edit generated artifacts.

Every platform mutation/report uses the same workflow execution id and
`agentTraceability`. Nested workflows reuse this plan and do not close
separately.

## Validate

1. Run shell syntax checks for all scripts.
2. Run `k6 inspect` for each changed journey/composite.
3. Run each changed journey with the smoke profile against the approved test
   environment via `run-journey.sh`; run changed composites via
   `run-composite.sh`. Seed first and teardown according to the manifest.
4. Confirm checks/thresholds, deterministic rerun behavior, reporter metadata,
   redaction, no secrets, and related-selection artifact schema.
5. If a comparable baseline exists, call `compare-perf-to-baseline` with the
   same `envClass`; classify
   changes against the approved threshold. A missing/mismatched baseline is
   **incomparable**, never pass or improvement. Do not claim
   regression/improvement from incomparable environment/profile/dataset/LLM
   modes.

## Report

Update the plan checklist with files, run ids, baseline/comparison ids,
artifacts, threshold outcomes, skipped gates, and unresolved capacity inputs.
Run [Report workflow execution](./policies-and-traceability.md#report-workflow-execution)
with `ACTION_COMPLETED`, or `ACTION_FAILED` with the blocker. A plan-only
automation invoke stops after upsert and does not report completion.

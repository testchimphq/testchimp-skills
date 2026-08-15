# /testchimp run-perf-tests

**Workflow id:** `run-perf-tests`

**Script-first.** Agents may help pick files and env, but CI and local runs
must work without an agent. Load [`perf-testing.md`](./perf-testing.md),
[`connect-to-test-env.md`](./connect-to-test-env.md), and the resolved
`run-perf-tests` policy.

Capability: `PERFORMANCE_TESTING` via `get-org-capabilities` (soft gate). If
absent and no trial is active, mark N/A and stop without failing an enclosing
workflow.

## Preamble

Same as SKILL.md **#4**: export `TESTCHIMP_API_KEY`,
`TESTCHIMP_PROJECT_ID`, `TESTCHIMP_INGRESS_URL` (when set),
`TESTCHIMP_BRANCH_NAME` into the **k6 process** env. Resolve the approved perf
target via `connect-to-test-env`; reject production unless policy and user
explicitly authorize it.

Record `TESTCHIMP_ENV`, `K6_PROFILE`, `K6_DATASET`, `LLM_MODE`, and commit SHA.
Baselines are meaningful only when these dimensions are comparable.

## Run

From SmartTests root:

```bash
# pin reporter (no git vendoring)
k6/scripts/prepare.sh

# one journey
K6_PROFILE=smoke K6_DATASET=k6/datasets/load.example.json \
  k6/scripts/run-journey.sh k6/journeys/<file>.js

# one composite
k6/scripts/run-composite.sh k6/composites/<file>.js

# a deterministic related selection
k6/scripts/run-related.sh \
  k6/artifacts/related/<branch>/related-perf-tests.json
```

Each invocation is **one `k6 run`**. The wrapper sets `TESTCHIMP_FOLDER_PATH` / `TESTCHIMP_FILE_NAME` / `TESTCHIMP_PERF_ID` plus kind, scenarios, test types, and members so `@testchimp/k6` `handleSummary` can ingest.

If a manifest requires seed data, call `k6/scripts/seed.sh "$K6_DATASET"`
before the run and perform its documented teardown afterward. LLM journeys
default to `LLM_MODE=mock`; the mock has deterministic configurable latency.
Real LLM mode requires explicit cost/rate-limit approval. Before load/volume,
confirm the policy **Dependency modes** inventory: every SUT outbound
external is stubbed with realistic latency (env stubs and/or
`k6/lib/mock-external.js` / `mock-llm.js`). Do not run load/volume against
live externals or 0 ms stubs unless the approved plan says so.

`prepare.sh` downloads `@testchimp/k6` **latest** from jsDelivr (re-run on each
journey). Pin with `K6_REPORTER_VERSION`, or dogfood with:

```bash
K6_REPORTER_LOCAL_DIR=/path/to/k6-testchimp-reporter k6/scripts/prepare.sh
```

Do **not** put k6 inside `/testchimp run QA`. Do not pass Playwright `--reporter`.

## Scope and evidence

- Explicit file/folder if the user named one.
- Else generate/select related journeys for the feature/PR branch using
  `select-related.sh` and review the reasons.
- Else ask which journeys/composites to run.

Selection may use changed scenarios, semantic-nearby scenarios, operations,
path templates, composite membership, mature TrueCoverage relative demand, and
prior failures. No selection signal defines absolute load.

## Baseline and comparison

Before a non-smoke run, query `list-perf-baselines` and
`list-perf-runs` when available. After ingest, use `compare-perf-to-baseline`
with the same `envClass` used at promote, for matching dimensions. A
missing/mismatched baseline is reported as
**incomparable**, never as pass or improvement. Do not update a baseline or
weaken thresholds implicitly.

## Workflow envelope

Standalone agent-driven runs use the canonical Analyze → Plan → approval →
Execute → Validate → Report sequence and
`knowledge/workflow_plans/run-perf-tests/<workflow_execution_id>.plan.md`.
The plan names exact files, environment, profile, dataset, seed/teardown, LLM
mode, external dependency mock inventory + latencies, approved absolute load,
thresholds, and baseline. Upsert before approval.
Nested runs reuse the parent plan. Validate reporter ingest and comparison,
then close through Report workflow execution.

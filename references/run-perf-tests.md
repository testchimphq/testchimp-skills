# /testchimp run-perf-tests

**Workflow id:** `run-perf-tests`

**Synonyms / prompts:**
- `/testchimp run-perf-tests`
- `/testchimp run perf`
- `/testchimp run performance tests`
- `/testchimp run performance tests for release <label>` (UI release detail CTA)

**Script-first.** Agents may help pick files and env, but CI and local runs
must work without an agent. Load [`perf-testing.md`](./perf-testing.md),
[`connect-to-test-env.md`](./connect-to-test-env.md), and the resolved
`run-perf-tests` policy.

Capability: `PERFORMANCE_TESTING` via `get-org-capabilities` (soft gate).
Growth plan (and free trial). If absent and no trial is active, mark N/A and
stop without failing an enclosing workflow.

## Preamble

Same as SKILL.md **#4**: export `TESTCHIMP_API_KEY`,
`TESTCHIMP_PROJECT_ID`, `TESTCHIMP_INGRESS_URL` (when set),
`TESTCHIMP_BRANCH_NAME` into the **k6 process** env **for reporter ingest**.
Those values are not the SUT. Resolve the approved perf target via
`connect-to-test-env`; reject production unless policy and user explicitly
authorize it. Point journeys at SUT hosts from that resolution / policy
(`BASE_URL`, `BACKEND_URL`, or other named product hosts) — do not fall
back to `TESTCHIMP_BACKEND_URL` / `TESTCHIMP_INGRESS_URL` for the system
under test. SUT calls use project seed credentials, not the reporter key.

When targeting a release, also export **`TESTCHIMP_RELEASE=<label>`** so ingest
stamps `perf_runs.release` (see [Targeting a release](#targeting-a-release)).

Record `TESTCHIMP_ENV`, `K6_PROFILE`, `K6_DATASET`, `LLM_MODE`, and commit SHA.
`K6_LOAD_VUS` is **peak concurrent VUs** on a ramp (not a constant-VU hammer).
Each journey must state what a VU represents (typically a user).
Baselines are meaningful only when these dimensions are comparable.
Isolated journey peaks are not mixed-hour proof; local downsample is not a
prod-sized claim. Volume staircases step `volume_size` in one k6 run and
ingest the peak dataset id.

Load results answer: *did N concurrent actors (as recorded on the journey)
complete this journey within thresholds?* Fail rate with low p95 usually means
errors (auth, checks), not “the stack cannot handle N VUs.” Charts should show
VU climb and metric change across ramp steps — if the script has no
`thinkTime()`, the run is max-RPS-per-VU and is **not** a concurrent-actor
test; flag that in the report.

## Run

From SmartTests root:

```bash
# pin reporter (no git vendoring)
k6/scripts/prepare.sh

# suite (all journeys; load then volume)
SEED_COMMAND=<project seed> k6/scripts/run.sh

# named files — paths relative to k6/
k6/scripts/run.sh journeys/foo.js journeys/nested/bar.js

# PR / CI: related-perf-tests.json next to related-tests.json
k6/scripts/run.sh --impacted
# merge-gate: K6_PROFILE=smoke, skip when the json is missing (do not fall through to all)

# authoring validate (skips volume staircase)
K6_PROFILE=smoke k6/scripts/run.sh journeys/foo.js
```

Each file is **one `k6 run` via the wrapper** (`run.sh` dispatches load vs
volume) — never bare `k6 run`.
The wrapper (see [`perf-testing.md`](./perf-testing.md) § Timeseries):

- sets `TESTCHIMP_FOLDER_PATH` / `TESTCHIMP_FILE_NAME` / `TESTCHIMP_PERF_ID`
  plus kind, scenarios, test types, and members so `handleSummary` can ingest
- adds `k6 run --out json=…`, then Node-downsamples and attaches timeseries
  by the ingest `runId` (sidecar / stdout). That is what populates Executions
  p95 / VU charts. Do not add another `--out json`. Do not sample from
  `handleSummary`. Volume-profile runs populate the **volume size** chart from
  the `volume_size` gauge (`pickTenant`); `run.sh` runs the staircase so
  that series actually steps.

After a run, stderr should include `TestChimp perf ingest ok … runId=` and
usually `TestChimp timeseries attach ok`. If attach is skipped (missing
`downsample.js` or no `runId`), the summary still ingested but the detail
page will show **No timeseries was attached**.

If a manifest requires seed data, call `k6/scripts/seed.sh "$K6_DATASET"`
before the run and perform its documented teardown afterward. LLM journeys
default to `LLM_MODE=mock`; the mock has deterministic configurable latency.
Real LLM mode requires explicit cost/rate-limit approval. Before load/volume,
confirm the policy **Dependency modes** inventory: every SUT outbound
external is stubbed with realistic latency (env stubs and/or
`k6/lib/mock-external.js` / `mock-llm.js`). Do not run load/volume against
live externals or 0 ms stubs unless the approved plan says so.

`prepare.sh` downloads `@testchimp/k6` **latest** from jsDelivr (re-run on each
journey; **≥ 0.2.1** includes full-metric `downsample.js`; **≥ 0.2.2** adds
HTTP status-class fail rates for Executions charts). Pin with
`K6_REPORTER_VERSION`, or dogfood an unpublished checkout with:

```bash
K6_REPORTER_VERSION=0.2.2 k6/scripts/prepare.sh
# optional unpublished dogfood:
# K6_REPORTER_LOCAL_DIR=/path/to/k6-testchimp-reporter k6/scripts/prepare.sh
```

Do **not** put k6 inside `/testchimp run QA`. Do not pass Playwright `--reporter`.

## Scope and evidence

- **Release label** if the user named one (`for release <label>` / `targeting
  release '…'`): follow [Targeting a release](#targeting-a-release) — git range
  is **prior SHA → cut SHA**, not the current branch tip.
- Explicit file/folder if the user named one.
- Else generate/select related journeys for the feature/PR branch using
  `select-related.sh` and review the reasons.
- Else ask which journeys/composites to run.

Selection may use changed scenarios, semantic-nearby scenarios, operations,
path templates, composite membership, mature TrueCoverage relative demand, and
prior failures. No selection signal defines absolute load.

## Targeting a release

When the user pastes a release prompt (or otherwise names a release), for
example `/testchimp run performance tests for release <label>`:

1. Parse the release label from `for release …` / `targeting release '…'`
   (or equivalent wording).
2. Fetch catalog details: **`testchimp get-release --version '<name>'`**
   (cut git SHA, prior release SHA, focus areas / metadata).
3. Use **prior SHA → cut SHA** as the git range (`git log` / `git diff`
   `<prior>..<cut>`). Identify **code and contract changes** in that range:
   application files, OpenAPI operations/path templates, scenario plans,
   and existing `k6/journeys` metadata (`scenarios`, `operations`, `paths`).
4. Build a `changes.json` (`scenarios`, `operations`, `paths`, `branch`) from
   that diff. Run `k6/scripts/select-related.sh <changes.json>` and
   `testchimp list-related-perf-tests` (scenario titles / operations when
   available). Rank with `get-requirement-coverage --include-perf` for
   scenarios implicated by the range.
5. Set **`TESTCHIMP_RELEASE=<name>`** on every wrapper `k6 run` so ingest
   stamps the release. Also export **`TESTCHIMP_GIT_COMMIT_SHA=<cut SHA>`**
   (reporter also reads `GITHUB_SHA` / `CI_COMMIT_SHA`) and
   **`TESTCHIMP_BRANCH_NAME`**.
6. **Sufficiency gate (blocking ask):** if existing journeys/composites do
   **not** cover the release-scoped changes — empty related selection, changed
   operations/paths with no matching tags, or high-priority scenarios in
   the range with no `PERF_TEST` coverage — **tell the user** what changed vs
   what would run, and **ask whether they want performance tests authored**.
   - **Yes:** load [`create-perf-tests.md`](./create-perf-tests.md) and run a
     **nested** `create-perf-tests` scoped to the **same release git range**
     (not the current feature-branch default). Then run the newly authored
     journeys plus any already-related existing ones.
   - **No:** run only the related existing tests (or stop if none). Record
     the gap on the plan.
7. Execute via `k6/scripts/run.sh --impacted` (or `k6/scripts/run.sh` for the
   full journey suite). Paths in related-perf-tests.json and on the CLI are
   relative to `k6/` (`journeys/foo.js`). Point the user back to the release detail
   **Performance Tests** section to review ingest.

Do **not** use the working-tree/PR branch as the change set when a release
label is present unless the user explicitly overrides.

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
thresholds, and baseline. For a **release** run, include the git range
(prior SHA → cut SHA), related selection, sufficiency outcome, and whether
nested `create-perf-tests` was approved. Upsert before approval.
Nested runs reuse the parent plan. Validate reporter ingest and comparison,
then close through Report workflow execution.

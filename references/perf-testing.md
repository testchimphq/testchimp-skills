# Performance testing (k6)

TestChimp performance tests live under the mapped **SmartTests root** in a reserved folder:

```text
<SmartTests root>/k6/
  journeys/      # one user journey per file; one `k6 run` per journey
  composites/    # multi-journey mix; one `k6 run` per composite
  profiles/      # smoke / load / volume options
  datasets/      # versioned manifests + synthetic examples
  lib/           # shared helpers
  scripts/       # prepare + run wrappers (script-first)
  artifacts/     # generated related selections and local run output
```

Playwright **must** ignore this tree: `testIgnore: ['**/k6/**']` (never run k6 files as SmartTests).

## Granularity

| Kind | What it is | When to run |
|------|------------|-------------|
| **Journey** | One user journey (may link many `#TS-…` scenarios). Isolated degrade detection. | PR/release related journeys; local debug |
| **Composite** | Weighted mix of journeys. System baseline (“can we handle typical overall load”). | Release / nightly; after adding a journey (ask whether to include it) |

Each file is still **one `k6 run`**.

## Per-journey test types (industry names)

- **Load testing** — can the stack handle **N concurrent users going through
  this journey**? Each VU is one user: it runs the journey steps, then
  `thinkTime()` (not a tight request loop). Concurrency climbs with
  **ramping-vus** from a low start to peak `K6_LOAD_VUS` so charts show
  metric change as load increases.
- **Volume testing** — can **one (or few) users** complete the journey when
  the **dataset is large** (records/objects/bytes per tenant)? Independent of
  the load ramp. Cardinality lives in the volume manifest.

Keep those axes separate. Never increase both merely to make a test
“heavier.” A journey may have both types when the scenario is expensive in
concurrency *and* data size; each value needs its own capacity rationale.

Load answers **concurrent users**, not max RPS. Open-loop arrival (`ramping-arrival-rate`) is not the default.

## Profiles and absolute-load rule

- `smoke.js` is the authoring/contract profile (1 VU, 1 iteration) and is
  safe by default. No think-time.
- `load.js` uses **`ramping-vus`**: start near 0, step through ~10% / ~50% /
  peak, hold at peak (`K6_LOAD_DURATION`), ramp down. Peak concurrent users =
  `K6_LOAD_VUS`. Journeys **must** call `thinkTime()` from `k6/lib/think-time.js`
  between user steps and at the end of `default`.
- `volume.js` stays few VUs (default 1); scale the **dataset**, not VUs.
- TrueCoverage, REAL E2E samples, request rates observed by TestChimp, and
  relative composite weights can identify important journeys. **Never**
  convert those observations directly into absolute VUs, RPS, duration,
  dataset cardinality, thresholds, or SLOs.
- Store the approved profile name and dataset manifest in run metadata so
  baseline comparisons can reject mismatched runs.

## Metadata

Every journey/composite exports:

```js
export const testchimp = {
  id: 'checkout-journey',          // stable id (logical key with path)
  kind: 'journey',                 // or 'composite'
  scenarios: ['#TS-101'],          // journey only; omit or [] on composites
  testTypes: ['load'],             // 'volume' and/or 'load'
  members: ['checkout-journey'],   // composite only: member testchimp.ids
};
```

k6 cannot read sibling `export const testchimp` from `handleSummary`. Use
`k6/scripts/run-journey.sh` (composites: `run-composite.sh`, which execs the
same wrapper). The wrapper extracts id/kind/scenarios/testTypes/members into
env (`TESTCHIMP_PERF_META`) so ingest works.

**Do not** call bare `k6 run` for TestChimp runs. Missing wrapper env means
**no ingest**. Missing wrapper `--out json` + attach means ingest **without
Executions charts**.

`k6/scripts/prepare.sh` (also invoked by every `run-journey.sh`) downloads
**npm `latest`** `@testchimp/k6` into gitignored `k6/lib/` — a new publish
reaches users on the next prepare/run. Timeseries attach needs
`k6/lib/downsample.js` (shipped in **`@testchimp/k6` ≥ `0.2.1`**). Override with
`K6_REPORTER_VERSION=<semver>` to pin, `K6_REPORTER_LOCAL_DIR` to dogfood a
checkout, or `K6_REPORTER_SKIP_REFRESH=1` for offline reuse. Do **not** vendor
the reporter into the app repo.

### Timeseries (Executions charts)

k6 does **not** expose live p95 from JS `handleSummary`. Charts come from a
**post-run** attach, not from sampling inside the journey script.

`run-journey.sh` already:

1. Runs `k6 run --out json=<tmp>/metrics.json` (do **not** add a second
   `--out json`; do **not** put `--out json` in the journey file).
2. Ingests the summary via `handleSummary`, which writes `runId` to a sidecar
   (`TESTCHIMP_PERF_RUN_ID_FILE`) and prints `runId=…` on stdout.
3. Downsamples the JSON dump in **Node** (`downsample.js`, default 5s buckets,
   cap ~500 points) and POSTs `/api/ingest_perf_run_timeseries` keyed by that
   **run_id**. Never attach to “latest run by test id.” Every k6 metric in the
   dump is kept (trend stats, rates, counters, gauges, plus custom metrics).
   `@testchimp/k6` **≥ 0.2.1** writes that full series for Executions charts.
   **≥ 0.2.2** also keeps HTTP `tags.status` as `http_req_failed.{5xx,4xx,3xx,0xx}.rate`
   so Executions can chart 5xx vs 4xx vs combined `http_req_failed.rate`.

Override bucket size with `TESTCHIMP_PERF_TIMESERIES_INTERVAL_SEC` (default
`5`). Attach is **non-fatal**: a failed chart upload must not change the k6
exit code.

**Agents must not:**

- Sample metrics in `handleSummary` / journey JS and POST that as timeseries
- Teach CI `k6 run script.js --out json=…` instead of `run-journey.sh`
- Invent a custom attach that looks up the latest run by `testchimp.id`

## Data, LLMs, and seeding

- Dataset manifests are committed JSON without credentials or production
  values. `kind: "volume"` specifies cardinality/shape. `kind: "load"`
  specifies a reusable synthetic identity pool.
- `k6/scripts/seed.sh <manifest>` is the portable contract: validate the
  manifest, call an explicitly configured `SEED_COMMAND` or `SEED_URL`, and
  emit a deterministic receipt under `k6/artifacts/seed/`. It never guesses a
  product seed endpoint.
- LLM journeys use `k6/lib/mock-llm.js` by default. Defaults are deterministic
  (`250ms`, zero jitter, zero error rate) and configurable through env. Real
  LLM calls require explicit approval and cost/rate-limit bounds.
- **SUT LLM vs k6 LLM mock:** `mock-llm.js` only delays the **k6 process**. It
  never intercepts LLM HTTP from the application. If the SUT would call an LLM
  on the journey path, fail closed in the **SUT** (env stub / disabled client
  that errors instead of falling back to a live key) and/or keep those APIs
  off the journey. Prefer seed helpers that skip expensive post-save pipelines
  not under test.
- Volume staircases use **distinct dataset ids** (e.g. 10% / 50% / 100% of
  target cardinality). Do not compare runs that differ only in cardinality
  unless the dataset id is part of the comparison key. Teardown must name
  seeded tenant/account ids — a “delete all” without id is the wrong contract.
- Seed namespaces should separate **load** tenants from **volume** tenants so
  teardown cannot wipe the other axis.

## Hosts, keys, and VU meaning

Do not reuse TestChimp reporter env for the system under test.

| Role | Typical env | Who uses it |
|------|-------------|-------------|
| **SUT** (app API / UI / extra product hosts) | `BASE_URL`, `BACKEND_URL`, plus any extra hosts the journeys hit | Journey HTTP |
| **Perf reporter** (charts only) | `TESTCHIMP_INGRESS_URL` / `TESTCHIMP_API_KEY` | `@testchimp/k6` `handleSummary` |

- **SUT auth** uses project seed credentials from policy /
  `ai-test-instructions.md`. Do not send the reporter `TESTCHIMP_API_KEY` to
  the SUT.
- **VU meaning is per journey:** record what a VU represents (typically a
  user). Different journeys may use different actor models; do not copy peak
  N across them without stating that.
- **Isolated vs mixed peak:** running each journey alone at peak is not the
  same as a mixed-hour composite. Mixed peak needs its own approved membership
  and profile. Downsampled local VUs are not prod-sized proof.
- **Inbound processing with stubbed outbound HTTP:** when the journey needs
  the SUT to *process* inbound events/webhooks, stub *outbound* partner calls
  at realistic latency but keep processing enabled so capacity includes
  parse/write, not only request accept.

## External dependencies (mock with realistic latency)

When the **system under test (SUT)** calls third-party or otherwise out-of-band
systems in production (payments, email/SMS, CRM, identity providers, partner
APIs, object storage outside the SUT, webhooks, LLMs, etc.), performance tests
**must not** leave those calls hitting the real world by default — and **must
not** stub them at zero latency.

**Why:** Zero-latency or missing stubs hide queueing, thread/connection pool
exhaustion, timeout budgets, and cascading slowdowns. Hitting live externals
adds flakiness, cost, and rate-limit noise. Either failure mode produces
**false confidence** in SUT capacity.

### Agent obligations (create / upkeep / init)

1. **Identify** every outbound dependency on the journey path (code, OpenAPI,
   config, REAL E2E interaction hosts that are not the SUT, infra manifests).
2. **Mock / stub them in the perf harness** so the SUT talks to controllable
   doubles during the run. Prefer **environment-level** stubs (WireMock,
   stub containers, test config pointing at local doubles) so the SUT’s real
   client code still runs. Use `k6/lib/mock-external.js` (and `mock-llm.js`
   for LLM paths) when the **journey script** itself needs a deterministic
   double.
3. **Respond with realistic latency** — not instantaneous success.
   - Prefer redacted REAL E2E **timing distributions** (p50/p95 class) when
     `list-api-operation-interactions` or ops telemetry is available.
   - Else use documented typical values in policy / `ai-test-instructions.md`
     (e.g. payment authorize ~200–400 ms, email provider ~100–300 ms, LLM
     mocked-standard 250 ms).
   - Record per-dependency `latency_ms` / optional jitter / error_rate in the
     journey plan and `run-perf-tests.policy.md` → **Dependency modes**.
4. **Never** treat “stubbed with 0 ms” as an acceptable default for load or
   volume. Smoke may use lower latency only when the plan explicitly says so
   and baselines for load/volume use the approved realistic profile.
5. **Real external calls** (live Stripe, real SendGrid, real LLM, …) require
   the same class of explicit approval as `llm_mode: real` — cost, rate-limit,
   and data-safety bounds in the approved plan.

### Comparison dimensions

Baselines are comparable only when dependency mock inventory and latency
profiles match (alongside environment / profile / dataset / LLM mode). Changing
a stub from 50 ms → 300 ms is a **new** comparison key, not a silent win.

## Related selection artifacts

`k6/scripts/select-related.sh` reads a JSON change description and journey
metadata, then writes a stable, sorted execution artifact:

```text
k6/artifacts/related/<branch-slug>/related-perf-tests.json
```

Also query `list-related-perf-tests` for platform inventory (journeys plus
parent composites by default). When policy wants a reviewable related-journey
artifact, copy the selection to:

```text
plans/perf/<branch>/related-journeys.json
```

(`gitSha`, `journeys[]`, `composites[]`, `reasons`). The k6 artifact includes
schema version, branch, input hash, selected journeys, and reasons (scenario,
operation, or path). Commit the plans copy only when project policy uses
related selection as a review artifact; otherwise keep `k6/artifacts/`
ignored. Execute selections with `k6/scripts/run-related.sh <artifact>`.

## Platform evidence

- Capability `PERFORMANCE_TESTING` gates perf workflows. API interaction and
  TrueCoverage insights have their own independent soft gates.
- `list-api-operation-interactions` may provide **REAL E2E** interaction
  shapes. Preserve only redacted method/path-template/schema/status/timing
  evidence; never copy raw values into tests or datasets.
- Use `list-perf-runs`, `get-perf-run`, `list-perf-baselines`,
  `promote-perf-baseline`, `compare-perf-to-baseline`, and
  `list-related-perf-tests`. Installed MCP/CLI help is authoritative for
  schemas. Compare requires `envClass` (same as promote). Compare runs only
  when environment/profile/dataset/LLM mode/dependency mock profiles match.
  `compare-perf-to-baseline` prints JSON and the CLI exits nonzero when
  `comparison.regressed` is true; a missing baseline is an API error, not a
  pass. Rank perf gaps with `get-requirement-coverage --include-perf`.
- Scenario priority and semantic coverage choose a diverse high-value queue.
  TrueCoverage maturity controls how strongly real-demand insights influence
  relative ordering: unavailable → none, sparse → directional, stable/mature
  → relative weighting.

## Capability

Org capability **`PERFORMANCE_TESTING`** (attached on Growth upgrade and free trial). Soft-gate with `get-org-capabilities`. If missing and no trial is active, tell the user the org plan does not include performance testing and stop (do not scaffold).

## Workflows

| Command | Reference |
|---------|-----------|
| `/testchimp init-perf` | [`init-perf.md`](./init-perf.md) |
| `/testchimp import-perf-tests` | [`import-perf-tests.md`](./import-perf-tests.md) — One-Off: existing Locust/k6/JMeter/etc. → `k6/` |
| `/testchimp run-perf-tests` | [`run-perf-tests.md`](./run-perf-tests.md) — **script-first** (including **release git range**) |
| `/testchimp create-perf-tests` | [`create-perf-tests.md`](./create-perf-tests.md) — policy-backed authoring |
| `/testchimp upkeep-perf` | [`upkeep-perf.md`](./upkeep-perf.md) — policy-backed upkeep |

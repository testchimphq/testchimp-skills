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

- **Volume testing** — one user/tenant with lots of data (API-level is OK).
- **Load testing** — many concurrent users.

Keep those axes separate. A volume manifest controls records/objects/bytes per
tenant; a load manifest controls a pool of synthetic identities and does not
set concurrency. Profiles control VUs/arrival/duration. A test may use both,
but each value needs an independent capacity rationale.

## Profiles and absolute-load rule

- `smoke.js` is the authoring/contract profile and is safe by default.
- `load.js` and `volume.js` are practical conservative examples, not production
  capacity claims. Override them only from an approved policy/user decision.
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

k6 cannot read sibling `export const testchimp` from `handleSummary`. Use `k6/scripts/run-journey.sh`, which extracts id/kind/scenarios/testTypes/members into env (`TESTCHIMP_PERF_META`). Direct `k6 run` without those env vars will not ingest.

`k6/scripts/prepare.sh` (also invoked by every `run-journey.sh`) downloads
**npm `latest`** `@testchimp/k6` into gitignored `k6/lib/` — a new publish
reaches users on the next prepare/run. Override with
`K6_REPORTER_VERSION=<semver>` to pin, `K6_REPORTER_LOCAL_DIR` to dogfood a
checkout, or `K6_REPORTER_SKIP_REFRESH=1` for offline reuse. Do **not** vendor
the reporter into the app repo.

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

Org capability **`PERFORMANCE_TESTING`** (Teams + Growth; not Indie). Soft-gate with `get-org-capabilities`. If missing, tell the user the org plan does not include performance testing and stop (do not scaffold).

## Workflows

| Command | Reference |
|---------|-----------|
| `/testchimp init-perf` | [`init-perf.md`](./init-perf.md) |
| `/testchimp run-perf-tests` | [`run-perf-tests.md`](./run-perf-tests.md) — **script-first** |
| `/testchimp create-perf-tests` | [`create-perf-tests.md`](./create-perf-tests.md) — policy-backed authoring |
| `/testchimp upkeep-perf` | [`upkeep-perf.md`](./upkeep-perf.md) — policy-backed upkeep |

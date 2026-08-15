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

Until `@testchimp/k6` is published, pin a local checkout:

```bash
K6_REPORTER_LOCAL_DIR=/path/to/k6-testchimp-reporter k6/scripts/prepare.sh
```

Do **not** vendor `@testchimp/k6` into the repo. `k6/scripts/prepare.sh` pins `handleSummary.js` + `ingest.js` into gitignored `k6/lib/`.

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
  when environment/profile/dataset/LLM mode match.
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

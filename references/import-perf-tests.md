# /testchimp import-perf-tests — Import existing performance tests into k6


> **Plan → approve → execute:** When this workflow runs **standalone**, write `knowledge/workflow_plans/import-perf-tests/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive`). **Nested under init-perf:** reuse the parent plan path and `workflow_execution_id` — **one approval only** (do not start a second Plan → approve → Execute cycle). See [`policies-and-traceability.md`](./policies-and-traceability.md).

**Workflow id:** `import-perf-tests`

**Synonyms / prompts:**
- `/testchimp import-perf-tests <existing perf tests folder>`
- `/testchimp import perf tests <folder>`
- `/testchimp import-perf-tests` (agent asks for the source folder when omitted)

**Playbook only** — no `import-perf-tests.policy.md`. Interactive Q&A drives translation scope, scenario linking, tagging, composite membership, and CI. Load/volume **profiles** remain owned by `run-perf-tests.policy.md` (do not invent absolute VUs from the source suite).

**Core idea:** Bring an existing performance suite from **another folder in the workspace** into the mapped SmartTests **`k6/`** tree in the TestChimp structure (journeys, composites, datasets, profiles, `export const testchimp` metadata, scenario links, tags). **k6 stays k6** (logic unchanged, wrap into our layout). **Locust, JMeter, Gatling, Artillery, and similar** are **best-effort translated to k6**. Load [`perf-testing.md`](./perf-testing.md) first.

---

## Light gate (standalone)

Before discovery, confirm:

1. **Capability (soft gate)** — `get-org-capabilities` must include **`PERFORMANCE_TESTING`**, or `freeTrialActive` must be true. Otherwise mark this workflow **N/A**, explain that the org plan does not include performance testing, and stop without failing an enclosing workflow.
2. **Markers** — `.testchimp-tests` (SmartTests root) and preferably `.testchimp-plans` exist (see **Marker files** in `SKILL.md`). If missing, stop and point the user to Git mapping + sync, or `/testchimp init`.
3. **Preamble #4** — `TESTCHIMP_API_KEY` (and `TESTCHIMP_BACKEND_URL` when configured) available for MCP/CLI.
4. **Do not** re-run full init or rewrite existing `k6/journeys` unless the plan says so.

When nested under `init-perf`, the capability gate and k6 scaffold already cover most of this.

---

## Phase 1 — Discover

1. Resolve **source folder** from the user prompt (`<existing perf tests folder>`) or ask.
2. Resolve **SmartTests root** (directory containing `.testchimp-tests`) and the target **`<SmartTests root>/k6/`**.
3. **Classify framework** (best-effort):
   - **k6** — `*.js` with `k6/http`, `export default`, `export const options`
   - **Locust** — `locustfile.py`, `HttpUser` / `FastHttpUser` / `TaskSet`, `@task`, `wait_time`
   - **JMeter** — `*.jmx`
   - **Gatling** — Scala/Java `Simulation`
   - **Artillery** — YAML/JSON scenarios
   - **Other** (wrk, vegeta, custom Python) — treat as **translate → k6** (best effort; call out risky translations in the plan)
4. **Layout:**
   - Source is already `<SmartTests root>/k6/` → retrofit metadata / reporter / structure in place
   - Source is **elsewhere** → plan moves (k6) or copy+translate (other frameworks) into `k6/journeys/` (and `k6/composites/` when mixes exist)
5. Inventory: test/user-class count, mix vs isolated journeys, existing CI job, datasets/CSV, tags, and any hard-coded VU/user/spawn numbers.
6. If `k6/` is missing, include nested **`init-perf`** in this workflow’s one plan and approval cycle.

### Migration stance (ask when not already clear)

| Strategy | When |
|----------|------|
| **Parallel `k6/` folder (gradual)** | Mapped `k6/` is canonical; legacy Locust/JMeter/etc. may remain elsewhere temporarily. |
| **Retrofit in place** | Existing tree is already (or becomes) `<SmartTests root>/k6/`; add metadata, profiles, reporter wrappers. |

---

## Phase 2 — Plan (then approve once)

Persist a plan (standalone path above, or init-perf parent subsection) covering:

1. Nested `init-perf` if `k6/` is missing
2. Moves / translations into `k6/journeys/` and `k6/composites/`
3. Per-file `export const testchimp` metadata (`id`, `kind`, `scenarios`, `testTypes`, `operations`, `paths`, `members`)
4. Scenario link strategy (external TMS ids, heuristic match against `plans/scenarios/`, or skip)
5. Tagging (k6 request `tags.name`, locust `@tag` preservation, related-selection `operations` / `paths`)
6. Composite membership (only when a source mix maps to a composite — **explicit membership/weight prompt**, same as [`create-perf-tests.md`](./create-perf-tests.md))
7. Dataset manifests vs secrets (CSV/credentials stay out of git; seed via `k6/scripts/seed.sh`)
8. External-dependency mocks with **realistic latency** ([`perf-testing.md`](./perf-testing.md) § External dependencies)
9. CI: **separate** k6 job vs leave the legacy perf job vs **replace**
10. **Absolute load:** treat source VU/user/spawn/duration as **observed legacy shape**, not as TestChimp profile values. Imported scripts use **`smoke.js`** until `run-perf-tests.policy.md` / the user approves load/volume. Never convert Locust user counts or TestChimp/TrueCoverage rates into `load.js` / `volume.js` silently.

Seek **one** explicit approval, then Execute.

---

## Phase 3 — Execute: import / translate

If nested `init-perf` was approved, run it first ([`init-perf.md`](./init-perf.md)).

### k6 already (as-is logic)

- Move or keep scripts under `k6/journeys/` (one user journey per file) **without changing request/assertion logic**.
- Align structure only:
  - `import { profileOptions } from '../profiles/index.js'` and `export const options = profileOptions`
  - `import { handleSummary } from '../lib/handleSummary.js'` and `export { handleSummary }`
  - `export const testchimp = { … }` with a **stable** `id` (kebab-case, unique among journeys)
  - Run via `k6/scripts/run-journey.sh` (not raw `k6 run` — ingest **and**
    Executions timeseries charts). Do not add `--out json` on the script or
    CI job; the wrapper already does that.
- Playwright `testIgnore` must include `'**/k6/**'`.
- Split a single file that encodes several distinct user journeys into **one file per journey**; if it is a weighted mix, that is a **composite** (Phase 5).

### Other frameworks (best-effort translation to k6)

Preserve user-visible journeys (method + path + payload **shape** + checks) as faithfully as practical. Do **not** silently invent product behavior, credentials, or capacity.

#### Locust → k6

| Locust | k6 destination |
|--------|----------------|
| One `HttpUser` with a **sequential** `@task` chain (or `sequential_task_set`) | One **journey** (`k6/journeys/<id>.js`) — `default` function with `http.*` + `check` + `sleep` for `wait_time` |
| Distinct `@task` methods that are **separate user journeys** | One journey file per task (prefer this when tasks do not share a single session story) |
| Multiple `HttpUser` classes (or tasks) with **weights** meant as a traffic mix | Candidate **composite** — do **not** add membership until the user approves weights (Phase 5) |
| `@tag('checkout')` / locust event tags | k6 per-request `{ tags: { name: 'checkout' } }` **and** `testchimp.paths` / `operations` when they are HTTP operations |
| `wait_time = between(a, b)` | `sleep()` with the documented think-time; prefer the **midpoint** or the lower bound in smoke; record the original range on the plan |
| `LoadTestShape` / `-u` / spawn rate | **Observed legacy shape only** — do not copy into `profiles/load.js` without capacity approval |
| `seq_files` / CSV user files | Dataset **manifest** + `k6/scripts/seed.sh`; never commit production credentials or PII |
| Locust `host` / `HttpsUser` | `__ENV.BASE_URL` or `__ENV.BACKEND_URL` (no hard-coded prod hosts) |

#### JMeter / Gatling / Artillery → k6

- Thread groups / injectors / arrival-rate phases → journeys + **pending** profile (smoke until approved).
- HTTP samplers / exec / YAML flows → `http.get/post/…` with `check` on status (and important JSON fields when the source asserted them).
- JMeter CSV Data Set / Gatling feeders / Artillery payload files → `datasets/` manifests (redact secrets).
- Transaction controllers / groups → k6 `tags.name` (one name per logical step).
- Weighted scenarios / mix → composite candidate (Phase 5).

**Out of scope for silent auto-merge:** proprietary plugins with no HTTP equivalent, GUI-only JMeter assertions, Locust gevent tricks, and closed-source protocol plugins—flag these in the plan rather than guessing.

### Scaffold expectations (non-negotiable)

Each imported journey/composite must match [`perf-testing.md`](./perf-testing.md) + the example in [`../assets/k6/journeys/example-journey.js`](../assets/k6/journeys/example-journey.js):

```js
export const testchimp = {
  id: 'checkout-journey',     // stable logical key
  kind: 'journey',            // or 'composite'
  scenarios: ['#TS-101'],     // real ordinals only; [] until linked
  testTypes: ['load'],        // and/or 'volume' — independent axes
  operations: [],             // optional OpenAPI operation ids
  paths: ['/api/checkout'],   // path templates for related selection
  members: [],                // composite only
};
```

- **`kind: 'journey'`** — omit `members` or use `[]`.
- **`kind: 'composite'`** — `members` is the list of **journey** `testchimp.id`s; `scenarios` usually `[]`.
- One file = one `k6 run`. Use `run-journey.sh` / `run-composite.sh`.
- Do **not** vendor `@testchimp/k6`; `prepare.sh` fetches it into gitignored `k6/lib/`.
- LLM paths default to `k6/lib/mock-llm.js`. Other SUT outbound deps: env-level stubs or `k6/lib/mock-external.js` with **realistic** latency (never 0 ms as the load/volume default).

---

## Phase 4 — Scenario linking and tagging

Goal: imported journeys carry real `#TS-…` scenario ordinals and related-selection tags. **Keep** any existing TMS / Locust / JMeter names; **add** TestChimp metadata.

### Scenario links (`testchimp.scenarios`)

Same lookup rules as [`import-existing-tests.md`](./import-existing-tests.md) Phase 5, applied to **journeys** (not Playwright `annotation`):

1. If tests already map to an external TMS (inline tags, spreadsheet, JMeter sampler names, Locust task names): extract ids and call `get-test-scenarios --external-ids` in batches of ~50–100.
2. On a match, set `scenarios: ['#TS-102', …]` using **platform-provisioned** ordinals only. Never invent `#TS-…`.
3. If multiple scenarios match one numeric id, **disambiguate with the user**.
4. If there is no tagging / spreadsheet: ask whether to **heuristically** match against `plans/scenarios/`. Link only when **very certain** (strong title / path / journey overlap). Otherwise leave `scenarios: []` and report unlinked files.

Composites do **not** duplicate member scenario lists (`scenarios: []` on the composite; members keep the links).

### Tagging

Fill every imported file so related selection and ingest work:

| Field | Source |
|-------|--------|
| `testchimp.paths` | HTTP path **templates** from the source (normalize IDs: `/orders/{id}` not `/orders/123`) |
| `testchimp.operations` | OpenAPI operation ids when `list-api-operations` / repo OpenAPI can resolve the path |
| `testchimp.testTypes` | `load` and/or `volume` from what the source actually does (many concurrent users vs one user/lots of data). Ask when unclear. Never set both merely to make a test “heavier.” |
| k6 `{ tags: { name: '<step>' } }` on each `http.*` | Locust `@tag`, JMeter transaction name, Gatling request name, Artillery flow name — preserves grouping in summaries |

Related-selection (`k6/scripts/select-related.sh` / `list-related-perf-tests`) uses scenario ordinals, operations, and paths from this metadata.

---

## Phase 5 — Composites (membership approval required)

If the source encodes a **traffic mix** (Locust user weights, JMeter thread-group mix, Gatling `andThen`/`randomSwitch`, Artillery weighted scenarios):

1. Propose a `k6/composites/<id>.js` with `kind: 'composite'` and listed `members`.
2. Approval **must** include this prompt (same as create-perf-tests):

> Add `<journey-id>` to composite `<composite-id>` with relative weight `<weight>`? This changes only the mix; confirm the composite profile's absolute VUs/RPS/duration separately.

3. Never silently add composite membership. Relative weights may follow the source mix; **absolute** VUs still stay on the smoke profile until approved.

---

## Phase 6 — CI migration

1. Discover existing perf CI (Locust/k6/JMeter jobs in GitHub Actions, GitLab CI, etc.).
2. **Ask:** create a **separate** job that runs `k6/scripts/run.sh` (or
   `k6/scripts/run.sh --impacted` when `related-perf-tests.json` is committed)
   from the mapped SmartTests root, **leave** the legacy job, or **replace** it.
3. New/updated job should:
   - `cd` into the mapped SmartTests folder
   - Use **`k6/scripts/run.sh`** — not bare
     `k6 run` and not `k6 run --out json=…` by hand. The wrapper owns JSON-out
     + run_id sidecar + timeseries attach. Volume dispatch is via `testTypes`
     / `volumeKind`; do not call `run-volume-staircase.sh` from CI.
   - Install k6 on the runner ([install k6](https://grafana.com/docs/k6/latest/set-up/install-k6/))
   - Default to **`K6_PROFILE=smoke`** until load/volume is approved in `run-perf-tests.policy.md`
   - Set **`TESTCHIMP_API_KEY`** (and **`TESTCHIMP_BACKEND_URL`** when enterprise/staging) as CI secrets — **guide the user**; never commit secrets
4. Prefer editing discovered files; for unfamiliar CI, propose a patch and confirm before large rewrites.

---

## Phase 7 — Optional smoke validate

Ask whether to run **smoke** on imported journeys now.

1. **Gate:** needs a usable `connect-to-test-env` policy (or Environment Provision Strategy in `ai-test-instructions.md`) plus `run-perf-tests.policy.md` placeholders filled for the smoke environment. If missing: **skip this phase**, explain why, and point to [`connect-to-test-env.md`](./connect-to-test-env.md) / [`create-policy.md`](./create-policy.md). Do **not** block the rest of import.
2. If proceeding: seed per manifest, run each **changed** journey with `k6 inspect` then `K6_PROFILE=smoke k6/scripts/run.sh journeys/<file>.js`. Do not run load/volume during import.
3. Confirm checks, reporter ingest metadata, no secrets in scripts/datasets, and external stubs use the planned latency.

---

## Completion checklist

- [ ] In-scope journeys live under `<SmartTests root>/k6/journeys/` (composites under `k6/composites/` when approved)
- [ ] Nested `init-perf` ran if `k6/` was missing; Playwright ignores `**/k6/**`
- [ ] Every file exports `testchimp` metadata (`id`, `kind`, `testTypes`, `scenarios` or `[]`, `paths` / `operations` as applicable)
- [ ] k6 sources: request logic unchanged; other frameworks: translations documented; risky items flagged
- [ ] Scenario links added where matched; existing TMS/locust tags preserved as k6 `tags.name`
- [ ] Composite membership approved (or N/A); no silent mix
- [ ] Legacy VU/user/spawn numbers **not** copied into profiles; smoke is the authoring profile
- [ ] CI updated or explicitly left/deferred; secrets guidance given
- [ ] Smoke validate done, skipped, or blocked with connect-to-test-env guidance
- [ ] Standalone: **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — emit missing mutation reports then **`ACTION_COMPLETED`** with `WORKFLOW` + `import-perf-tests` (nested under init-perf: parent report owns completion)

---

## Related references

- [`perf-testing.md`](./perf-testing.md) — k6 taxonomy, metadata, absolute-load rule
- [`init-perf.md`](./init-perf.md) — scaffold; may nest this workflow
- [`create-perf-tests.md`](./create-perf-tests.md) — authoring + composite membership prompt
- [`import-existing-tests.md`](./import-existing-tests.md) — E2E import analog (scenario lookup)
- [`run-perf-tests.md`](./run-perf-tests.md) — script-first execution after import
- [`../assets/k6/journeys/example-journey.js`](../assets/k6/journeys/example-journey.js)

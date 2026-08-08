# /testchimp import — Import existing tests into SmartTests


> **Plan → approve → execute:** When this workflow runs **standalone**, write `knowledge/workflow_plans/import/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive`). **Nested under init:** reuse the parent plan path and `workflow_execution_id` — **one approval only** (do not start a second Plan → approve → Execute cycle). See [`policies-and-traceability.md`](./policies-and-traceability.md).

**Workflow id:** `import`

**Synonyms / prompts:**
- `/testchimp import existing tests <existing tests folder>`
- `/testchimp import` (agent asks for the source folder when omitted)

**Playbook only** — no `import.policy.md`. Interactive Q&A drives CI strategy, linking, and optional `markScreenState`.

**Core idea:** Bring an existing E2E suite into the **mapped SmartTests root** (folder with `.testchimp-tests`). SmartTests are **standard Playwright** plus TestChimp additions (traceability, fixtures, reporting). **`playwright.config.*` lives inside that mapped folder.**

---

## Light gate (standalone)

Before discovery, confirm:

1. **Markers** — `.testchimp-tests` (SmartTests root) and preferably `.testchimp-plans` exist (see **Marker files** in `SKILL.md`). If missing, stop and point the user to Git mapping + sync, or `/testchimp init`.
2. **Preamble #4** — `TESTCHIMP_API_KEY` (and `TESTCHIMP_BACKEND_URL` when configured) available for MCP/CLI and the Playwright runner.
3. **Do not** re-run full init; only import/align the suite.

When nested under init, the workstation gate and Key Area 1 already cover this.

---

## Phase 1 — Discover

1. Resolve **source folder** from the user prompt (`<existing tests folder>`) or ask.
2. Resolve **SmartTests root** (directory containing `.testchimp-tests`).
3. **Classify framework** (best-effort for all):
   - **Playwright** — `*.spec.{js,ts}` / `@playwright/test`
   - **Cypress**, **Selenium**, **WebdriverIO**, **Puppeteer**, or other — treat as **translate → Playwright** (best effort; preserve intent; call out risky translations in the plan)
4. **Layout:**
   - Source **is** the mapped root → retrofit / align in place
   - Source is **elsewhere** → plan moves (or copy+translate) into the mapped root
5. Report findings: framework, approx test count, existing `playwright.config` / CI, whether `@testchimp/playwright` is already wired.

### Migration stance (ask when not already clear)

| Strategy | When |
|----------|------|
| **Parallel SmartTests folder (gradual)** | Mapped folder is canonical; legacy suite may remain elsewhere temporarily while specs move over. |
| **Retrofit in place** | Existing tree becomes / already is the SmartTests root; align config, reporter, fixtures there. |

---

## Phase 2 — Plan (then approve once)

Persist a plan (standalone path above, or init parent plan subsection) covering:

1. Moves / translations into mapped root
2. Config + reporter + fixtures (see below)
3. CI: **separate Action** vs **replace** existing test job
4. Scenario link comments
5. Optional `markScreenState` phase (yes / no / deferred)

Seek **one** explicit approval, then Execute.

---

## Phase 3 — Execute: import / translate

### Playwright (as-is logic)

- Move or keep specs under the mapped root **without changing test logic**.
- Align structure only: config location, reporter, fixture barrels, imports.

### Other frameworks (best-effort translation)

- Translate to Playwright `*.spec.{js,ts}` under the mapped root.
- Preserve assertions and user-visible journeys as faithfully as practical.
- Prefer stable locators; use `ai.act` / `ai.verify` only where selectors are fragile and the project already uses ai-wright.
- Document uncertain translations in the plan / FAQ; do not silently invent product behavior.
- **Out of scope for silent auto-merge:** flaky timing hacks, proprietary page-object DSLs without clear mapping, and visual-only assertions with no DOM equivalent—flag these for user review in the plan rather than guessing.

### Scaffold expectations (non-negotiable)

Use [`assets/template_playwright.config.js`](../assets/template_playwright.config.js) as the structural baseline:

- **`playwright.config.*` inside** the mapped SmartTests folder
- **Reporter:** `['@testchimp/playwright/reporter', { verbose: false }]`
- **Reporting:** `screenshot: 'on'`, `trace: 'retain-on-failure'`
- **Projects:** `setup` → browser project(s) with `dependencies: ['setup']`, `testIgnore: ['**/setup/**']`
- Install **`@testchimp/playwright`** (≥ **0.1.8**; prefer ≥ **0.2.0**) at the package root that owns `@playwright/test`
- **Fixtures-first:** every `*.spec.{js,ts}` imports `{ test, expect }` from the correct fixture barrel (`fixtures/index.js` or scaffold-specific barrel) with **`installTestChimp(mergeTests(...))`** — never root `test` from `@playwright/test` in specs. See [`fixture-usage.md`](./fixture-usage.md), [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md).

### API key wiring

- **Local:** guide user to put `TESTCHIMP_API_KEY` (and backend URL / project id when needed) in project MCP `env` per Preamble **#4**; export into the runner shell before `npx playwright test`.
- **Never** commit secrets; never print the key.

Run from the mapped folder:

```bash
cd /path/to/<mapped-tests-folder>
npx playwright test
```

---

## Phase 4 — CI migration

1. Discover existing CI (GitHub Actions `.github/workflows/`, GitLab CI, etc.).
2. **Ask:** create a **separate** CI Action/job for imported SmartTests, **or replace** the existing test-execution job so it runs from the mapped SmartTests root.
3. Update configs accordingly:
   - `cd` into mapped tests folder before `npx playwright test`
   - Set **`TESTCHIMP_API_KEY`** (and **`TESTCHIMP_BACKEND_URL`** when enterprise/staging) as CI secrets — **guide the user** where to add them (e.g. GitHub → Settings → Secrets)
4. Prefer editing discovered files; for unfamiliar CI systems, propose a concrete patch and confirm before large rewrites.
5. Exclude plan-sync PRs when applicable (see [`configure-ci-test-execution.md`](./configure-ci-test-execution.md) / init Key Area 6).

Docs: [Run SmartTests in CI (Playwright)](https://docs.testchimp.io/smart-tests/run-in-ci-playwright).

---

## Phase 5 — Scenario annotations

Goal: imported specs get Playwright scenario annotations (`{ type: 'scenario', description: '#TS-<n>' }`) where a TestChimp scenario exists. **Keep existing TMS tags**; only **add** TestChimp links. Skip tests that already have a correct scenario annotation (or a deprecated `// @Scenario: #TS-…` line — optionally rewrite to annotations when touching the file).

### Batching external-id lookups

When extracting many TMS ids, call `get-test-scenarios` in **batches of ~50–100** `--external-ids` (not one mega-call of thousands). Prefer MCP when available. CLI ≥ **0.1.26** for `--external-ids`.

### When tests already map to an external TMS

1. Confirm with the user how mapping works: **inline tags** (Xray / TestRail / custom), **spreadsheet**, or other.
2. If spreadsheet: ask for the file(s) and use them as the source of truth for test → external id.
3. Extract external ids from tags/spreadsheet. Send the **full** id including prefix (e.g. `C12345`, `PROJ-101`) to CLI/MCP:

   ```bash
   testchimp get-test-scenarios --external-ids C12345,PROJ-101
   ```

   Backend matches **exact** `external_id` first, then strips prefixes and matches the **numerical** part (leading zeros normalized). Prefer MCP when available.
4. On a match, add Playwright test options (do **not** insert a body comment):

   ```javascript
   test('checkout with credit card', {
     annotation: [
       { type: 'scenario', description: '#TS-102' },
     ],
   }, async ({ page }) => {
     // ...
   });
   ```

   Format rules: [`write-smarttests.md`](./write-smarttests.md). Multiple scenario annotations allowed in the same `annotation` array when one test covers several scenarios.
5. If multiple scenarios match one numeric id (e.g. `PROJ-101` and another key sharing `101`), **disambiguate with the user** — do not pick silently. Prefer exact-string matches when both exact and numerical hits exist.
6. Jira/Xray often store API issue ids, not keys — try both key and numeric forms; if none match, leave unlinked and report.

### When there is no tagging / spreadsheet

Ask whether the agent should **heuristically** match against scenarios under the mapped **`plans/scenarios/`** tree. If yes: link only when **very certain** (strong title / path / journey overlap). Otherwise skip linking.

---

## Phase 6 — Optional `markScreenState` enrichment

**Why (tell the user clearly):** `markScreenState` checkpoints screen/state transitions so TestChimp can build a screen-state atlas, power **ExploreChimp** UX analytics along the same pathways as SmartTests, and give agents stable vocabulary for UI journeys. Without it, ExploreChimp and related insights are much weaker on imported suites.

1. Ask whether to run this phase now, skip, or defer.
2. **Gate:** requires a usable **`connect-to-test-env`** policy (or substantive Environment Provision Strategy in `ai-test-instructions.md`). If missing: **block this phase**, explain why, and point to [`connect-to-test-env.md`](./connect-to-test-env.md) / [`create-policy.md`](./create-policy.md). Do **not** block the rest of import.
3. **Nested under init:** run this phase **only after** init has established env (Key Area 5 / Action G)—even if the user approved markScreenState in the shared plan earlier.
4. If proceeding: connect to env, pick **~20–30** tests that cover **distinct areas** of the app (not the entire suite when large), run them while watching UI transitions, and insert `markScreenState('Screen', 'State')` at meaningful changes. Prefer UI journeys over pure API specs.
5. Specs must already use the fixture barrel (`markScreenState` from `installTestChimp`). ExploreChimp (`EXPLORECHIMP_ENABLED`) is a later upside; this phase does **not** require it — annotations still help in trace-only mode.
6. Prefer Atlas upsert (`list-screen-states` / `upsert-screen-states`) before inventing new screen names when those tools are available.

---

## Completion checklist

- [ ] In-scope specs live under the mapped SmartTests root (or gradual parallel plan documented)
- [ ] `playwright.config.*` inside mapped root; reporter + screenshot/trace match template
- [ ] Fixtures-first imports on every imported `*.spec.{js,ts}`
- [ ] CI updated per user choice; secrets guidance given
- [ ] Scenario links added where matched; existing TMS tags preserved
- [ ] `markScreenState` done, skipped, deferred, or blocked with connect-to-test-env guidance
- [ ] Standalone: **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — emit missing mutation reports then **`ACTION_COMPLETED`** with `WORKFLOW` + `import` (nested under init: parent / init report owns completion)

---

## Related references

- [`init-testchimp.md`](./init-testchimp.md) — init nests this workflow when unmigrated suites are detected
- [`write-smarttests.md`](./write-smarttests.md) — scenario **`annotation`**, fixtures, authoring
- [`configure-ci-test-execution.md`](./configure-ci-test-execution.md) — CI details
- [`connect-to-test-env.md`](./connect-to-test-env.md) — required for markScreenState phase
- [`run-explorechimp.md`](./run-explorechimp.md) — why screen-states matter
- [`assets/template_playwright.config.js`](../assets/template_playwright.config.js)

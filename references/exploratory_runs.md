# ExploreChimp — exploratory UX analytics on SmartTests

This reference supports **local ExploreChimp** runs: Playwright UI tests drive the browser to **deterministic screen-states**, and `@testchimp/playwright` sends **DOM, screenshot, console, network, and performance metrics** to TestChimp for **UX-oriented bug finding** (layout, visual regressions, usability, accessibility via axe, performance signals, console recorded issues, suspicious network patterns, and similar). Client behavior is implemented in **`@testchimp/playwright`** (`EXPLORECHIMP_ENABLED`, `markScreenState` fixture; **≥ 0.1.8**); analysis is routed via TestChimp backend services.

**P0 — same as all SmartTest runs:** The **process** that executes Playwright/Mobilewright with **`@testchimp/playwright`** must have **`TESTCHIMP_API_KEY`** in its **environment** (not only MCP/IDE). **Resolution order:** SmartTests-root walk-up → host MCP **`mcpServers.*.env.TESTCHIMP_API_KEY`** (never print) → export/inject into the shell, CI job, or wrapper **before** spawn — see **`SKILL.md`** Preamble **#4** and [`testing-process.md`](./testing-process.md) non-negotiables. **Reporter disabled**, **401**, missing-key logs → same remediation.

## When to use this doc vs commands

| User intent | Where to go |
|-------------|-------------|
| **ExploreChimp as the primary goal** (pick tests, scope, env, interpret results) | This file + user’s scope. Treat semantically like **`/testchimp explore`**: same playbook, with **extra user instructions** on area, depth, or test list when needed. |
| **Explorations inside full PR QA** | [`testing-process.md`](./testing-process.md) — **Phase 5: Smart regression** after **Phase 4: Validate**; then branch plan **[Phase 2 §7 — ExploreChimp branch plan (yes or documented N/A)](./testing-process.md#7-explorechimp-branch-plan-yes-or-documented-na)** records **`yes`** (default for **new or materially changed UI SmartTests**) or **`N/A`** with one-line rationale. **Phase 6** runs after Phase 5 when **`yes`** on specs that are **new, materially changed, and regression-touched**; then **Phase 7: Cleanup**. |
| **`/testchimp evolve`** (coverage improvement cycle) | [`evolve-coverage.md`](./evolve-coverage.md) — Use **TrueCoverage** signals (drop-offs, high-duration / high-demand events, automation gaps) to choose **which UI SmartTests** to run with ExploreChimp; **new tests** written in the same evolve cycle are valid targets once stable with **`markScreenState`**. |

---

## Purpose (why ExploreChimp exists)

ExploreChimp helps agents **find UX bugs** by analyzing **multiple data sources along the pathways of real UI tests**, not by guessing URLs. Each **`await markScreenState(screen, state?)`** call is a **checkpoint**: the reporter attributes console logs, network traffic, and performance metrics to the **prior** screen-state interval, and captures **screenshot + DOM (+ axe)** for the **current** screen-state. That yields evidence-backed issues (performance, layout, visual, usability, accessibility, console noise, API shape/status) tied to **named states** the suite already reaches.

ExploreChimp applies to **both** **web** SmartTests (Playwright + **`page`**) and **native mobile** SmartTests (Mobilewright + **`screen`**). `@testchimp/playwright` chooses **`page`** vs **`screen`** from the fixture barrel (`installTestChimp` default vs `{ uiFixture: 'screen' }`) and, on mobile, **`testInfo.project.use.platform`** (`ios` | `android`) from **`mobilewright.config.ts`**.

**Mobile UI runs:** use a config project with **`use.platform`** set; import specs from **`mobile/fixtures/index.js`** (or **`web/fixtures/`** / flat **`fixtures/`** for web). See [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) and [`mobilewright-smarttests.md`](./mobilewright-smarttests.md).

**Out of scope:** **Pure API tests** (no UI fixture journey) are **not** ExploreChimp targets. ExploreChimp is for **UI SmartTests** (web: Playwright + browser; mobile: Mobilewright + device/simulator).

---

## Prerequisites: `markScreenState` and atlas vocabulary

ExploreChimp **requires** meaningful **`markScreenState`** calls on stable UI—otherwise there is nothing to attribute analytics to.

In this skill’s **`/testchimp test`** flow, **`markScreenState`** placement and atlas vocabulary are defined in **Phase 4: Validate** (see [`testing-process.md`](./testing-process.md)) and in **[`write-smarttests.md`](./write-smarttests.md)**:

- **[Screen / state markers (`markScreenState`)](./write-smarttests.md#screen--state-markers-markscreenstate)** — **`installTestChimp`** on the correct barrel (`fixtures/`, `web/fixtures/`, or `mobile/fixtures/`); never named-import `markScreenState` from the runtime package.
- **Atlas workflow** — MCP **`list-screen-states`** / **`upsert-screen-states`** (shell: **`testchimp list-screen-states`**, **`testchimp upsert-screen-states`** — [`cli.md`](./cli.md) § **Screen-state atlas**) and the **post-authoring validation** sequence in [Test writing workflow §7](./write-smarttests.md#test-writing-workflow).

**Order of operations:** Complete **functional** tests and **Validate** (including **`markScreenState`** where required) **before** turning on **`EXPLORECHIMP_ENABLED`** for an exploration batch, so checkpoints match stable product states.

**Targeting one screen for UX review:** Run a UI SmartTest that **already reaches** that screen (with markers at stable points), with ExploreChimp enabled—prefer reusing suite pathways over ad-hoc scripts.

---

## Key concepts

| Concept | Meaning |
|---------|---------|
| **Exploration** | A logical “explore run” keyed by **`TESTCHIMP_BATCH_INVOCATION_ID`** (or **`.testchimp-batch-invocation-id`** under the Playwright project root). Correlates analysis requests and bugs for that session. |
| **Journey** | Stable identity for **one Playwright test** (derived from spec file + title path). Groups steps and analytics for that test in the product UI. |
| **Journey execution** | A **single execution instance** of that test (aligned with job manifest `jobId` when present; otherwise a generated id). |
| **Bug** | A **filed UX issue** produced by the analysis pipeline from one or more data sources, with deduplication and project rules applied server-side. |
| **Atlas** | Project **screen/state vocabulary** (MCP **`list-screen-states`** / **`upsert-screen-states`**; CLI **`testchimp list-screen-states`** / **`testchimp upsert-screen-states`**) and the TestChimp **exploration/journey** surfaces used to review runs and findings. |
| **Screen-state** | A **`(screen name, state name)`** pair passed to **`markScreenState`**. Interval data since the **previous** mark is attributed to the **prior** screen-state; **screenshot + DOM (+ axe)** attach to the **current** screen-state. |

### Deduplication

Server-side analysis uses **per-exploration / per-screen-state** dedup (aligned with bug-source analytics) so the same checkpoint is not re-processed wastefully. Still place **`markScreenState`** only at **meaningful** stable boundaries—not every line of code.

---

## Choosing which tests to include

- **`/testchimp test` (Phase 6):** Run ExploreChimp on the **union** of **new**, **materially changed**, and **regression-touched** UI SmartTests from the branch plan **§7** (after **Phase 5: Smart regression**)—not only net-new specs. See [Phase 6: ExploreChimp](./testing-process.md#phase-6-explorechimp) in [`testing-process.md`](./testing-process.md).
- **PR / branch focus (standalone `/testchimp explore`):** Prefer **new or materially updated** SmartTests on the branch, plus any **linked regression** specs the user names.
- **User gave an area / feature:** Read specs and existing **`markScreenState`** / **`list-screen-states`** vocabulary to see which **screens and states** each test visits; pick the **minimal** set that covers the requested flows.
- **One screen:** Pick (or add) a short test that reaches that screen with a marker after the UI stabilizes.

---

## Environment variables (local runs)

| Variable | Required | Role |
|----------|----------|------|
| **`EXPLORECHIMP_ENABLED`** | Yes for analytics | `true` / `1` / `TRUE` turns on ExploreChimp wiring and backend calls. |
| **Config `use.platform`** | **Yes on mobile UI projects** | Set **`ios`** or **`android`** on Mobilewright UI projects in **`mobilewright.config.ts`** so `@testchimp/playwright` branches TrueCoverage/ExploreChimp per test. Web/API projects omit it. |
| **`TESTCHIMP_API_KEY`** | **Yes (P0 — on the runner process)** | Must be set in the **environment of the Playwright/Mobilewright process** (export from MCP config per **`SKILL.md`** walk-up, CI secret, or `env:` block). **MCP/IDE-only** is insufficient. Never commit; not in `.env-QA`. |
| **`TESTCHIMP_BATCH_INVOCATION_ID`** | Yes for correlation | **Exploration id**; also read from **`.testchimp-batch-invocation-id`** if env unset. |
| **`TESTCHIMP_BRANCH_NAME`** | **Strongly recommended on local / agent shells** | **Canonical env to teach:** human git branch name (e.g. `git rev-parse --abbrev-ref HEAD`). `@testchimp/playwright` sets JSON **`branchName`** on ExploreChimp analyze requests via `getBranchName()`, which reads **`TESTCHIMP_BRANCH_NAME`** first, then **`TESTCHIMP_BRANCH`**, then CI/git vars. The server resolves **`branchName`** to **`branch_id`** on explorations, journeys, and bugs. If both name vars are unset and no CI branch is available, **`branch_id`** may stay empty. |
| **`TESTCHIMP_BACKEND_URL`** | Optional | Featureservice base URL (package defaults if omitted). |
| **`EXPLORECHIMP_SOURCES_TO_ANALYZE`** | Optional | Comma-separated: **`DOM`**, **`SCREENSHOT`**, **`CONSOLE`**, **`NETWORK`**, **`METRICS`**. **Default if unset:** all five enabled. |
| **`EXPLORECHIMP_REQUEST_REGEX_TO_ANALYZE`** | **Required when `NETWORK` is included** | JavaScript **regex** string; URLs must **match** to be captured. If `NETWORK` is requested but this is missing/invalid, **network capture is disabled** (warning logged). |
| **`EXPLORECHIMP_LONG_TASK_THRESHOLD_MS`** | Optional | Long-task threshold for metrics (default **50** ms). |

### Regex for `NETWORK` (agent behavior)

1. **Infer from repo context:** `BASE_URL` / API host from **`ai-test-instructions.md`** → **`## ExploreChimp`** and **`## Environment Provision Strategy`**, **`.env-*`**, OpenAPI bases, or existing `page.route` patterns—derive a **tight** regex for **your** backend (hostname + path prefix), not third-party noise.
2. If unsafe or ambiguous, **ask the user**, then **persist** under **`plans/knowledge/ai-test-instructions.md`** → **`## ExploreChimp`** so future runs reuse it.

---

## Persist decisions in `ai-test-instructions.md`

Use the dedicated **`## ExploreChimp`** section (see template in [`init-testchimp.md`](./init-testchimp.md)). Agents **must re-read** it before each exploration batch.

```md
## ExploreChimp

- **Mobile UI project:** `ios` / `android` via `mobilewright.config.ts` `use.platform` (and correct `mobile/fixtures` barrel)
- **NETWORK regex:** `...` (or: omit NETWORK from sources; document override)
- **Default sources:** (only if team narrowed from all-five)
- **Scope notes:** folders/tests we usually explore on PRs
- **Blockers resolved:** backend URL, manifest/jobId, flakiness, etc.
```

Mirror **FAQ-worthy** runner issues in **`## Past learnings — authoring & validation (FAQ)`** when appropriate.

---

## Operator checklist

1. **`SKILL.md`** preamble: resolve **`TESTCHIMP_API_KEY`** and **export/inject** it into the **runner** process env (verify before spawn; do not rely on MCP-only).
2. Confirm **`mobilewright.config.ts`** UI projects set **`use.platform`** when exploring native mobile specs ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)).
3. **`@testchimp/playwright` ≥ 0.1.8**; each spec imports from the barrel where **`installTestChimp`** was applied ([`fixture-usage.md`](./fixture-usage.md)).
4. **`markScreenState`** in place per **Phase 4** / [`write-smarttests.md`](./write-smarttests.md).
5. Set **`TESTCHIMP_BATCH_INVOCATION_ID`** (or file) for this exploration batch.
6. Set **`TESTCHIMP_BRANCH_NAME`** to the current git branch when running locally (so the server can resolve **`branch_id`** for analytics and bugs).
7. Set **`EXPLORECHIMP_ENABLED=true`**; configure sources / **network regex** as needed.
8. `cd` **SmartTests root**; run per scaffold ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)) — e.g. **`npx playwright test -c playwright.config.js --project web`**, **`npx mobilewright test -c mobilewright.config.ts --project ios`**.
9. Review findings in TestChimp exploration/journey UI; update **`## ExploreChimp`** with new stable decisions.

---

## Related references

- [`mobilewright-smarttests.md`](./mobilewright-smarttests.md) — native mobile stack, `use.platform`, no ai-wright
- [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — spec/fixture paths
- [`write-smarttests.md`](./write-smarttests.md) — **`markScreenState`**, atlas MCP tools, authoring order
- [`cli.md`](./cli.md) — **`testchimp list-screen-states`**, **`testchimp upsert-screen-states`** (§ **Screen-state atlas**)
- [`testing-process.md`](./testing-process.md) — **Phase 4** markers + **Phase 5** Smart regression + **Phase 6** ExploreChimp (**default-on** for UI SmartTest deltas; **[§7](./testing-process.md#7-explorechimp-branch-plan-yes-or-documented-na)** **`yes`** or **`N/A`**) on **new + changed + regression-touched** UI specs
- [`evolve-coverage.md`](./evolve-coverage.md) — **TrueCoverage → test selection → ExploreChimp** in **`/testchimp evolve`**
- [`fixture-usage.md`](./fixture-usage.md) — `mergeTests` / **`fixtures/index.js`**
- [`init-testchimp.md`](./init-testchimp.md) — `ai-test-instructions.md` template

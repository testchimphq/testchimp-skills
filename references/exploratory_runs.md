# ExploreChimp — exploratory UX analytics on SmartTests

This reference supports **local ExploreChimp** runs: Playwright UI tests drive the browser to **deterministic screen-states**, and `@testchimp/playwright` sends **DOM, screenshot, console, network, and performance metrics** to TestChimp for **UX-oriented bug finding** (layout, visual regressions, usability, accessibility via axe, performance signals, console recorded issues, suspicious network patterns, and similar). Client behavior is implemented in **`@testchimp/playwright`** (`EXPLORECHIMP_ENABLED`, `markScreenState` fixture; **≥ 0.1.8**); analysis is routed via TestChimp backend services.

## When to use this doc vs commands

| User intent | Where to go |
|-------------|-------------|
| **ExploreChimp as the primary goal** (pick tests, scope, env, interpret results) | This file + user’s scope. Treat semantically like **`/testchimp explore`**: same playbook, with **extra user instructions** on area, depth, or test list when needed. |
| **Explorations inside full PR QA** | [`testing-process.md`](./testing-process.md) — Branch plan **Phase 2, section 6 — ExploreChimp (optional)** gates **yes** vs **`N/A`**; when **yes**, the run is **Phase 5** after **Phase 4: Validate** (tests green, scenario links + **`markScreenState`** / atlas in shape), then **Phase 6: Cleanup**. |
| **`/testchimp evolve`** (coverage improvement cycle) | [`evolve-coverage.md`](./evolve-coverage.md) — Use **TrueCoverage** signals (drop-offs, high-duration / high-demand events, automation gaps) to choose **which UI SmartTests** to run with ExploreChimp; **new tests** written in the same evolve cycle are valid targets once stable with **`markScreenState`**. |

---

## Purpose (why ExploreChimp exists)

ExploreChimp helps agents **find UX bugs** by analyzing **multiple data sources along the pathways of real UI tests**, not by guessing URLs. Each **`await markScreenState(screen, state?)`** call is a **checkpoint**: the reporter attributes console logs, network traffic, and performance metrics to the **prior** screen-state interval, and captures **screenshot + DOM (+ axe)** for the **current** screen-state. That yields evidence-backed issues (performance, layout, visual, usability, accessibility, console noise, API shape/status) tied to **named states** the suite already reaches.

**Out of scope:** **Pure API tests** (no browser, no `page`, no DOM journey) are **not** ExploreChimp targets. ExploreChimp is for **UI SmartTests** (Playwright with a real browser).

---

## Prerequisites: `markScreenState` and atlas vocabulary

ExploreChimp **requires** meaningful **`markScreenState`** calls on stable UI—otherwise there is nothing to attribute analytics to.

In this skill’s **`/testchimp test`** flow, **`markScreenState`** placement and atlas vocabulary are defined in **Phase 4: Validate** (see [`testing-process.md`](./testing-process.md)) and in **[`write-smarttests.md`](./write-smarttests.md)**:

- **[Screen / state markers (`markScreenState`)](./write-smarttests.md#screen--state-markers-markscreenstate)** — fixture wiring via **`installTestChimp`** on **`tests/fixtures/index.js`** (never named-import `markScreenState` from the runtime package).
- **Atlas workflow** — **`list-screen-states`** / **`upsert-screen-states`** and the **post-authoring validation** sequence in [Test writing workflow §7](./write-smarttests.md#test-writing-workflow).

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
| **Atlas** | Project **screen/state vocabulary** (MCP **`list-screen-states`** / **`upsert-screen-states`**) and the TestChimp **exploration/journey** surfaces used to review runs and findings. |
| **Screen-state** | A **`(screen name, state name)`** pair passed to **`markScreenState`**. Interval data since the **previous** mark is attributed to the **prior** screen-state; **screenshot + DOM (+ axe)** attach to the **current** screen-state. |

### Deduplication

Server-side analysis uses **per-exploration / per-screen-state** dedup (aligned with bug-source analytics) so the same checkpoint is not re-processed wastefully. Still place **`markScreenState`** only at **meaningful** stable boundaries—not every line of code.

---

## Choosing which tests to include

- **PR / branch focus:** Prefer **new or materially updated** SmartTests on the branch.
- **User gave an area / feature:** Read specs and existing **`markScreenState`** / **`list-screen-states`** vocabulary to see which **screens and states** each test visits; pick the **minimal** set that covers the requested flows.
- **One screen:** Pick (or add) a short test that reaches that screen with a marker after the UI stabilizes.

---

## Environment variables (local runs)

| Variable | Required | Role |
|----------|----------|------|
| **`EXPLORECHIMP_ENABLED`** | Yes for analytics | `true` / `1` / `TRUE` turns on ExploreChimp wiring and backend calls. |
| **`TESTCHIMP_API_KEY`** | Yes | Same project key as MCP/shell (never commit; not in `.env-QA`). |
| **`TESTCHIMP_BATCH_INVOCATION_ID`** | Yes for correlation | **Exploration id**; also read from **`.testchimp-batch-invocation-id`** if env unset. |
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

- **NETWORK regex:** `...` (or: omit NETWORK from sources; document override)
- **Default sources:** (only if team narrowed from all-five)
- **Scope notes:** folders/tests we usually explore on PRs
- **Blockers resolved:** backend URL, manifest/jobId, flakiness, etc.
```

Mirror **FAQ-worthy** runner issues in **`## Past learnings — authoring & validation (FAQ)`** when appropriate.

---

## Operator checklist

1. **`SKILL.md`** preamble + **`TESTCHIMP_API_KEY`** in shell.
2. **`@testchimp/playwright` ≥ 0.1.8**; **`fixtures/index.js`** applies **`installTestChimp`** to merged **`test`** per guardrails.
3. **`markScreenState`** in place per **Phase 4** / [`write-smarttests.md`](./write-smarttests.md).
4. Set **`TESTCHIMP_BATCH_INVOCATION_ID`** (or file) for this exploration batch.
5. Set **`EXPLORECHIMP_ENABLED=true`**; configure sources / **network regex** as needed.
6. `cd` **SmartTests root**; `npx playwright test …` for chosen UI specs.
7. Review findings in TestChimp exploration/journey UI; update **`## ExploreChimp`** with new stable decisions.

---

## Related references

- [`write-smarttests.md`](./write-smarttests.md) — **`markScreenState`**, atlas MCP tools, authoring order
- [`testing-process.md`](./testing-process.md) — **Phase 4** markers + **ExploreChimp** between Validate and Cleanup
- [`evolve-coverage.md`](./evolve-coverage.md) — **TrueCoverage → test selection → ExploreChimp** in **`/testchimp evolve`**
- [`fixture-usage.md`](./fixture-usage.md) — `mergeTests` / **`fixtures/index.js`**
- [`init-testchimp.md`](./init-testchimp.md) — `ai-test-instructions.md` template

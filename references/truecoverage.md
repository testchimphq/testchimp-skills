# TrueCoverage

TrueCoverage connects **real user behavior** (from production) with **test execution** so you can see which important journeys are under-tested. Instrument the app with **`@testchimp/rum-js`**; [`@testchimp/playwright`](https://github.com/testchimphq/playwright-testchimp-reporter) tags the same events during test runs with test identity. TestChimp aggregates both streams for coverage insights.

As an intelligent QA workflow executor agent, TrueCoverage is a capability that you can leverage to instrument the code to "learn about how real users are interacting with the app" - sliced by dimensions as you see fit. These instrumented events are captured by TestChimp, to generated summarized insights, which you can later read during `/testchimp evolve` workflow to optimize QA work.

A few ways this can be used strategically:

   - Fixture authoring: metadata slices that refer entity fields (refer below for dot-notation metadata keys) at an event interaction helps write fixtures that mimic real world setups (eg: Users with no form-of-payment (FOP) setup attempts to do a checkout in real world. If you had instrumented whether user has form-of-payment in checkout event emits, you can use this information to identify how frequently this "situation" occurs, and prioritize creating fixtures that mimic that entity condition and write a test that verifies "behaviour when user with no FOP attempts checkout")
   - Covering common event sequences: TrueCoverage data endpoints expose ability to fetch detailed info about an event - which includes - what events immediately follow the given event (and the frequency distribution). This can be used to identify common journeys that are under tested - and author useful tests.
   - Understanding user interaction funnel and optimizing fixing of coverage gaps. Per-event analytics exposed by TestChimp follow the **4Ds** (RUM-based QA strategy—full metric mapping in [How TrueCoverage metrics work](https://docs.testchimp.io/truecoverage/how-it-works)): **Demand** — how often an action appears (relative frequency, occurrences, unique sessions); **Duration** — dwell and pacing (time to next event, time since previous event, time from session start to first occurrence, time from event to session end); **Drop-off** — abandonment signals (share of sessions where the event is terminal, reverse index from session end, time from event to session end); **Depth** — funnel ordering and friction to reach a step (position in session, reverse index, time to first occurrence in session). Together they prioritize which real-user paths deserve tests, beyond raw transition lists alone.

**Authoritative RUM library docs (read before implementing):** [@testchimp/rum-js on GitHub](https://github.com/testchimphq/testchimp-rum-js) (README covers `init`, `emit`, `flush`, `resetSession`, configuration options, event constraints, and batching). **npm:** [`@testchimp/rum-js`](https://www.npmjs.com/package/@testchimp/rum-js).

**Product overview:** [TrueCoverage intro](https://docs.testchimp.io/truecoverage/intro)

---

## Setup (library and credentials)

1. Install: `npm install @testchimp/rum-js` in the **app under test** (frontend / runtime bundle), not only in the SmartTests package.
2. Call **`testchimp.init()` once** at app bootstrap (see [library README](https://github.com/testchimphq/testchimp-rum-js)). Required top-level fields per README:
   - **`projectId`** — TestChimp project ID (from **TestChimp → Project Settings → Key management**). Should be stored in some env-properties file and referred in code.
   - **`apiKey`** — project API key for RUM (same source - have it configured and loaded from an env properties file).
   - **`environment`** — logical tag for the session (e.g. `production`, `staging`, `QA`); use one consistent scheme per deploy.
   - Optional: `sessionId`, `release`, `branchName`, `sessionMetadata`, and nested **`config`** (see below).
3. Prefer **one helper** (e.g. `emitProductEvent`) that wraps **`testchimp.emit()`** after init. Read credentials from your app’s env/build config (e.g. map `TESTCHIMP_PROJECT_ID` / `TESTCHIMP_API_KEY` into `init()`); avoid scattering raw `emit` calls. Do **not** put these secrets in SmartTests `.env-QA`—those are for test execution vars like `BASE_URL`.
4. **Vocabulary:** If you already use product analytics (PostHog, Segment, etc.), align event names where it helps—but TrueCoverage goals differ: prefer **semantic journey steps** (e.g. checkout-completed) over noise (“button clicked”). Keep **metadata cardinality** low; follow **Event constraints** in the [GitHub README](https://github.com/testchimphq/testchimp-rum-js) (title length, metadata keys/values, max serialized size).

### RUM `config` (volume / “sampling” behavior)

The library does not use a separate “sampling percentage” API; **event volume and repeat caps** are controlled via the optional **`config`** object passed to **`testchimp.init({ ..., config })`**. Defaults and meanings are defined in the [@testchimp/rum-js README — Configuration options](https://github.com/testchimphq/testchimp-rum-js). Use this table as the agent checklist (align with README for exact defaults):

| Option | Purpose |
|--------|--------|
| `captureEnabled` | If `false`, `emit` is a no-op (kill switch). |
| `maxEventsPerSession` | Cap total accepted events per session. |
| `maxRepeatsPerEvent` | Cap repeats of the same event **title** per session. |
| `eventSendInterval` | Ms between batch sends. |
| `maxBufferSize` | Buffer size before auto-flush. |
| `inactivityTimeoutMillis` | Session expiry; new load starts a new session. |
| `testchimpEndpoint` | RUM ingress base URL (override only if needed). |
| `enableDefaultSessionMetadata` | Session init metadata from client (`navigator` / `Intl`); set `false` if you want only your `sessionMetadata`. |

For a **first instrumentation slice**, prefer **conservative** limits (the README includes an example “high-frequency sampling” block). Reuse existing tuning from the repo when present.

Sampling can be done using any custom logic on your app side, and for the session, determine whether the capturing should be done or not (based on the sampling logic). Then set the `captureEnabled` for the session. So if you want simple 1% random sampling, a logic like below:

```js
// Decide once per browser session (before or inside init).
SAMPLE_RATE := 0.01
roll := random_uniform_0_to_1()  // cryptographically weak RNG is fine here

captureEnabled := (roll < SAMPLE_RATE)

testchimp.init({
  projectId: "...",
  apiKey: "...",
  environment: "production",
  config: {
    captureEnabled: captureEnabled,
    // ...maxEventsPerSession, maxRepeatsPerEvent, etc.
  },
})
// When captureEnabled is false, emit() is a no-op for that session.
```

For **deterministic** cohorts (same user always in or out), hash a stable **non-PII** key (e.g. anonymous id or session id) to a bucket in `[0, 1)` and compare to `SAMPLE_RATE` instead of `random_uniform_0_to_1()`.

### After init

- Use **`testchimp.emit({ title, metadata? })`** for journey events; call **`testchimp.flush()`** before navigation/redirect if you need immediate delivery.
- Invalid or over-limit events are **dropped** (console warning per README)—design titles and metadata accordingly.

---

## Project decision: `plans/knowledge/ai-test-instructions.md`

TrueCoverage decisions are project-level and must be persisted in `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` (not in workstation marker files).

### Default: opted in

**Unless** `ai-test-instructions.md` **explicitly** states that TrueCoverage is **opted out** (e.g. a clear `### TrueCoverage Plan` entry such as “opted out,” “disabled for this repo,” “not applicable,” or equivalent team decision the file names as permanent opt-out), agents MUST treat TrueCoverage as **opted in**:

- Plan RUM install (`@testchimp/rum-js`), `testchimp.init` / emit helper, Playwright reporter wiring, env vars, and **`plans/events/*.event.md`** for new or changed journeys as part of normal **`/testchimp init`**, **`/testchimp test`**, and **`/testchimp evolve`** work.
- Do **not** skip TrueCoverage because the TrueCoverage section is missing, empty, or says only “deferred,” and do **not** treat silence as “user declined.”

**Explicit opt-out only:** When the file **explicitly** records opt-out, skip new TrueCoverage instrumentation unless the user runs **`/testchimp setup truecoverage`** or otherwise asks to re-enable.

**Deferred during init:** “Deferred” is a **schedule snooze** (which emits land later), **not** an opt-out.

- During **`/testchimp test`**, treat TrueCoverage as **in-scope** for the PR: wire missing framework pieces, define/document the **event slice** for changed journeys, and update `plans/knowledge/truecoverage-instrument-progress.md` as appropriate.
- During **`/testchimp init`**, “deferred” means not finishing every planned emit in that init pass; the agent must not later assume TrueCoverage is unavailable or out of scope.

---

## Ongoing: `/testchimp test`

When there is **no explicit opt-out** in `ai-test-instructions.md` and the PR adds or changes **meaningful user journeys**:

1. **Plan:** Include TrueCoverage work: new or updated events, helper placement, env config, `plans/events/` docs, progress tracker updates.
2. **Execute:** Emit events from the app code where it adds signal; use **`plans/events/`** (below) to document event types and metadata for consistency.

If **`### TrueCoverage Plan`** explicitly records **opted out**, skip new instrumentation unless the user explicitly asks (e.g. `/testchimp setup truecoverage`).

---

## Instrumentation progress tracker: `plans/knowledge/truecoverage-instrument-progress.md`

To make TrueCoverage instrumentation incremental and resumable, maintain a single progress tracker under:

- `plans/knowledge/truecoverage-instrument-progress.md`

Purpose:

- Track **planned vs done** event instrumentation with a route/page-based breakdown.
- Let agents resume instrumentation consistently during `/testchimp instrument` and opportunistically during `/testchimp evolve`.

Init policy:

- `/testchimp init` should wire **basic TrueCoverage infra** and a **small initial event slice**.
- `/testchimp init` should also scan the frontend routes/pages and write the progress tracker for the **full planned event list**.
- Init should create `plans/events/*.event.md` files **only** for events actually instrumented in init; planned-but-not-yet-instrumented events remain tracked only in the progress doc until `/testchimp instrument` lands them.

Suggested format:

- Sections grouped by **routes/pages**.\n- Each event entry is marked `done | planned | deferred`.\n- When an event is marked `done`, it should have a matching `plans/events/<title>.event.md` file.

How `/testchimp instrument` uses it:

1. Choose the next relevant `planned` events (often those impacted by the current PR).
2. Implement emits in app code via the shared helper wrapper.
3. Create/update `plans/events/<title>.event.md` for each newly-instrumented event.
4. Update `plans/knowledge/truecoverage-instrument-progress.md` by marking those entries `done`.

How `/testchimp evolve` uses it:

- Treat `plans/knowledge/truecoverage-instrument-progress.md` as the plan baseline.
- If MCP analytics show high-signal gaps that are already `planned`, prioritize instrumenting them.
- If analytics suggests missing events that are not in the tracker, add them as `planned` (or explain why they are out of scope).
- Full evolve workflow (Analyze → Plan → Execute), phase gates, and where to persist evolve plans: [`evolve-coverage.md`](./evolve-coverage.md).

## Ongoing: `/testchimp evolve`

When the project has **not** explicitly opted out of TrueCoverage in `ai-test-instructions.md`, after requirement coverage and execution history, use MCP tools (see **SKILL.md**). Requests mirror the platform TrueCoverage API (JSON bodies use **camelCase** field names). If explicitly opted out, omit TrueCoverage MCP analytics unless the user asks to re-evaluate.

### Execution scopes (mental model)

Analytics messages embed **`ExecutionScope`**: environment, time window, optional release/branch/metadata filters, and optionally **`automationEmitsOnly`**.

| Scope field | Typical use |
|-------------|-------------|
| **`baseExecutionScope`** | **Real-user / production** (or the environment that best reflects real behavior). Drives funnel stats: relative frequency, funnel position, histograms, terminal %, session counts. |
| **`comparisonExecutionScope`** | **Secondary** window (often **QA / staging**) used to answer “did **automated tests** cover this event?” Coverage badges compare base vs this scope. |
| **`coverage_scope`** (child event tree) | Same idea as comparison: “which **next** events were seen under coverage” when drilling into transitions. |

Set **`automationEmitsOnly: true`** on **`comparisonExecutionScope`** or **`coverage_scope`** when you want coverage to count **only RUM emits that carry test identity** (`test_id` from the Playwright reporter). That **excludes manual sessions** on the same environment so “covered” is not polluted by ad-hoc QA. Omit the field or set **`false`** to include all traffic in that scope (legacy behavior). **Do not rely on `automationEmitsOnly` on the base scope** for filtering real-user metrics—the platform ignores it for base aggregates; use it only on comparison/coverage scopes.

### Recommended flow

1. **`list-rum-environments`** — Lists environment tags present in data; pick env values for scopes.
2. **`get-truecoverage-events`** — Body: `baseExecutionScope`, optional `comparisonExecutionScope` (add `automationEmitsOnly` on comparison when you want test-only coverage). **Returns** `eventSummaries[]` with `eventTitle`, `relativeFrequency`, `coverageStatus` (PRESENT/ABSENT vs comparison), position/histogram summaries, `numUniqueSessions`, terminal %.
3. Choose high-impact gaps, then for the identified events that you want to drill in to:
   - **`get-truecoverage-event-details`** — Time series, sample sessions, **metadata** breakdown with per-value **comparison coverage** (use `automationEmitsOnly` on `comparisonExecutionScope` to align metadata “covered” with test-tagged emits only).
   - **`get-truecoverage-child-event-tree`** — Top **next** events after the current title; pass **`coverage_scope`** with `automationEmitsOnly` when transition coverage should ignore manual paths.
   - **`get-truecoverage-event-transition`** / **`get-truecoverage-event-time-series`** — Deeper transition and metric series as needed.
4. Turn gaps into a prioritized plan (tests, instrumentation, or both).

### Metadata keys and “coverage”

Use metadata for gap analysis **only when the key is a meaningful product dimension** (e.g. role, plan tier, payment readiness) where behavior or risk differs.

Hard rule: **do not emit identifiers** as metadata keys or values (or plan for them in `plans/events/*.event.md`). In practice this means avoiding keys like `project_id`, `org_id`, `user_id`, any `*_id`, UUIDs, raw emails, or other high-cardinality identifiers. These explode cardinality and are not useful for sliced coverage.

Also avoid **free-text** or other high-cardinality dimensions unless the product logic genuinely branches on a small bounded set of values—the platform can mark keys as high-cardinality; prefer skipping those for coverage prioritization.

When in doubt, refer documentation: https://docs.testchimp.io/truecoverage/how-it-works

### Dot-scoped metadata (entity attributes)

**Mental model:** `testchimp.emit()` is how you **learn how real users move through the product** at the level of *journeys + slicing dimensions*, not raw logs. Before instrumenting, ask: *What slices matter for risk, for prioritizing tests, and for building fixtures that resemble production?* (examples: role, org tier, cart state, entitlements.)

**Convention (domain entities only):** When metadata describes a **domain entity** (eg: user, org, cart, subscription, …), prefer keys shaped **`{entity}.{attribute}`** with a **stable, low-cardinality** first segment:

- `user.role`, `user.has_fop` (boolean or enum—not raw payment instrument ids)
- `org.plan_tier`
- `cart.line_item_count_bucket` or `cart.is_empty` (buckets/enums, not SKUs)
- `product.availability_class` (small enum: `in_stock` / `backorder` / …)

Use **flat** keys for cross-cutting dimensions that are not “owned” by one entity (e.g. `entry_surface`, `experiment_cohort`) if that reads clearer—dot notation is a **scoping aid**, not a strict schema.

**Per-event minimalism:** Attach only fields that **change how you interpret that event** for coverage and QA. Do **not** dump whole domain objects onto every emit. The goal is to answer: *which kinds of entities perform which actions, how often, and are those slices exercised in automated tests?*—without cardinality explosion.

**Feedback loop (fixtures and tests):** Production-like traffic → distributions and transitions in TrueCoverage (e.g. `get-truecoverage-event-details`, `get-truecoverage-event-metadata-keys`, child event trees, time series) → **gaps** (common real slices with weak or missing test coverage) → **seed/probe endpoints** and **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`) that recreate those world-states → **SmartTests / API tests** → requirement scenarios where the product is under-specified. Dot-scoped keys make it obvious *which fixture dimensions* to extend (e.g. a `viewer` role fixture when `user.role=viewer` dominates a critical event).

Dot notation **does not** relax the rules above: it is **namespacing** for allowed, low-cardinality dimensions—not permission to add PII, ids, or unbounded text.

---

## Commands

TrueCoverage setup and ongoing instrumentation is part of `init` and `test` workflows. Below is for when just TrueCoverage specific tasks are needed to be done.

| User intent | Action |
|-------------|--------|
| `/testchimp setup truecoverage` (or setup-truecoverage) | Walk through RUM install, env vars, helper, reporter; persist the decision and notes under `### TrueCoverage Plan` in `plans/knowledge/ai-test-instructions.md`. |
| `/testchimp instrument` | Instrument current PR work with emits; run setup first if TrueCoverage is not yet enabled and the user wants it. |

---

## Event documentation: `plans/events/`

Events do **not** require server-side registration. To avoid duplicate names and document metadata for agents, add one **`*.event.md` file per event type** under **`plans/events/`** (under the mapped plans root). The platform treats these as **`EVENT_FILE`** (distinct from **`plans/knowledge/`** markdown).

**Dual purpose:** Each file is both (1) a **schema note** for metadata and (2) **durable planning memory**. On later runs—especially **`/testchimp evolve`** and when calling TrueCoverage MCP tools to interpret funnels, coverage gaps, and metadata slices—the agent should **re-open the matching `*.event.md`** so instrumented titles are not “mystery emits.” Write the body so a **future agent** (often you, in a new session) can recover **why** the event exists, **what** you hoped to learn from analytics, and **how** that ties to product risk and requirements.

**Frontmatter:**

| Field | Description |
|-------|-------------|
| `title` | kebab-case; match the event file basename (without `.event.md`). |
| `description` | Short factual line: when the event fires (user-visible moment or journey step). |
| `added-on` | Date instrumentation was added (ISO date). |
| `significance` | 1–5 for gap prioritization during evolve runs (1=low, 5=high). |

**Body — required sections (in this order):**

1. **`## Rationale`** (required; this name is preferred so tools and humans can grep it—acceptable synonyms: **`## Instrumentation rationale`**, **`## Why this event`**)

   Write for **your future self** when interpreting TrueCoverage stats and planning next steps. Include plain-language coverage of:

   - **Thinking / intent** — Why instrument *here* (not elsewhere), what product or UX question this emit is meant to illuminate, and any tradeoffs (e.g. kept title coarse to limit cardinality).
   - **Hypotheses / questions** — What you expect or want TrueCoverage data to answer (e.g. “Do users with `user.has_fop=false` abandon after this step disproportionately?”).
   - **Business criticality** — Why this journey slice matters (revenue, compliance, trust, activation, etc.).
   - **Requirement links** — Point to the **user stories / test scenarios** this event supports: `#US-…` / `#TS-…` ids and/or paths to markdown under `plans/stories/`, `plans/scenarios/`, or branch plans, so evolve and test planning stay grounded in the same scenarios you had in mind when adding the emit.

   This section is **not** a substitute for `description` in frontmatter; `description` stays short and factual; **`## Rationale`** holds the narrative and planning context you will need when MCP returns time series, transitions, and metadata breakdowns.

2. **`## Metadata keys`** (or keep the heading `## Metadata` if you prefer)

   Document each metadata key using the **dot-scoped** form when it refers to a domain entity (`user.role`, `org.plan_tier`, …). For each key, specify **allowed values or value type**—prefer small **enums** or buckets (booleans, `low|med|high`) over free text. Note cardinality intent (e.g. “bounded set of roles only”). Non-entity dimensions may stay flat if clearer. Avoid documenting identifier-like keys; they must not be emitted.

---

## MCP tools (TrueCoverage)

Configured via **`@testchimp/cli`** with `TESTCHIMP_API_KEY`: `list-rum-environments`, `get-truecoverage-events`, `get-truecoverage-event-details`, `get-truecoverage-child-event-tree`, `get-truecoverage-event-transition`, `get-truecoverage-event-time-series`, `get-truecoverage-session-metadata-keys`, `get-truecoverage-event-metadata-keys`.

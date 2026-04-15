# TrueCoverage

TrueCoverage connects **real user behavior** (from production) with **test execution** so you can see which important journeys are under-tested. Instrument the app with [`testchimp-rum-js`](https://www.npmjs.com/package/testchimp-rum-js); [`playwright-testchimp`](https://github.com/testchimphq/playwright-testchimp-reporter) tags the same events during runs with test identity. TestChimp aggregates both streams for coverage insights.

**Product overview:** [TrueCoverage intro](https://docs.testchimp.io/truecoverage/intro)

---

## Setup (library and credentials)

1. Install: `npm install testchimp-rum-js` (in the app under test, not only in the SmartTests package).
2. Prefer **one helper** (e.g. `emitProductEvent`) that wraps `testchimp-rum-js`, sets `TESTCHIMP_API_KEY`, `TESTCHIMP_PROJECT_ID`, and environment tag from your per-env config. Avoid scattering raw calls throughout codebase.
3. **Credentials:** Users get `TESTCHIMP_API_KEY` and project id from **TestChimp → Project Settings → Key Management**. Send them on event emits per library docs; tag **environment** (e.g. `QA`, `prod`) consistently.
4. **Vocabulary:** If you already use product analytics (PostHog, Segment, etc.), align event names where it helps—but TrueCoverage goals differ: prefer **semantic journey steps** (e.g. checkout completed) over noise (“button clicked”). Keep **metadata cardinality** low (few distinct values per key) to avoid explosion; use sampling aggressively if needed—goal is QA gap signal, not product analytics precision.

---

## Skill state: `<SKILL_DIR>/bin/.truecoverage_setup`

Agents persist the user’s choice in **`bin/.truecoverage_setup`** (create `bin/` if needed). Single line:

```text
enabled=true
```

Allowed values:

| Value | Meaning |
|--------|---------|
| `enabled=true` | TrueCoverage is in scope: follow instrument / audit steps below. |
| `enabled=false` | User opted out; **do not** prompt to set up or instrument for TrueCoverage until they ask (e.g. `/testchimp setup truecoverage`). |
| `enabled=later` | User asked to defer. **Do not** prompt again until the file’s **mtime** is older than **3 days**; then you may ask once whether to enable now. If they choose “not now but later” again, **touch** the file (update mtime) to snooze another 3 days. If they say never, set `enabled=false`. |

If the file is **missing**:

- Explain briefly what TrueCoverage adds (coverage gaps aligned with real usage, used in `/testchimp test` and `/testchimp audit`).
- Ask whether to set it up.
- If **yes:** set `enabled=true` and include setup + instrumentation in the relevant plan/execution phases.
- If **no:** set `enabled=false`.
- If **later:** set `enabled=later` and touch the file on snooze as above.

During **`/testchimp test`**, read this file **first** (see [testing-process.md](./testing-process.md)): only instrument and expand RUM when `enabled=true` (subject to the `later` / absent-file rules).

---

## Ongoing: `/testchimp test`

When `enabled=true` and the PR adds or changes **meaningful user journeys**:

1. **Plan:** Note TrueCoverage needs: new or updated events, helper placement, env config.
2. **Execute:** Emit events from the app code where it adds signal; use **`plans/events/`** (below) to document event types and metadata for consistency.

If `enabled=false` or `later` (within snooze), skip instrumentation unless the user explicitly asks.

---

## Ongoing: `/testchimp audit`

When `enabled=true`, after requirement coverage and execution history, use MCP tools (see **SKILL.md**). Requests mirror the platform TrueCoverage API (JSON bodies use **camelCase** field names).

### Execution scopes (mental model)

Analytics messages embed **`ExecutionScope`**: environment, time window, optional release/branch/metadata filters, and optionally **`automationEmitsOnly`**.

| Scope field | Typical use |
|-------------|-------------|
| **`baseExecutionScope`** | **Real-user / production** (or the environment that best reflects real behavior). Drives funnel stats: relative frequency, funnel position, histograms, terminal %, session counts. |
| **`comparisonExecutionScope`** | **Secondary** window (often **QA / staging**) used to answer “did **automated tests** hit this event?” Coverage badges compare base vs this scope. |
| **`coverage_scope`** (child event tree) | Same idea as comparison: “which **next** events were seen under coverage” when drilling into transitions. |

Set **`automationEmitsOnly: true`** on **`comparisonExecutionScope`** or **`coverage_scope`** when you want coverage to count **only RUM emits that carry test identity** (`test_id` from the Playwright reporter). That **excludes manual sessions** on the same environment so “covered” is not polluted by ad-hoc QA. Omit the field or set **`false`** to include all traffic in that scope (legacy behavior). **Do not rely on `automationEmitsOnly` on the base scope** for filtering real-user metrics—the platform ignores it for base aggregates; use it only on comparison/coverage scopes.

### Recommended flow

1. **`list_rum_environments`** — Lists environment tags present in data; pick env values for scopes.
2. **`get_truecoverage_events`** — Body: `baseExecutionScope`, optional `comparisonExecutionScope` (add `automationEmitsOnly` on comparison when you want test-only coverage). **Returns** `eventSummaries[]` with `eventTitle`, `relativeFrequency`, `coverageStatus` (PRESENT/ABSENT vs comparison), position/histogram summaries, `numUniqueSessions`, terminal %.
3. Choose high-impact gaps, then per event title:
   - **`get_truecoverage_event_details`** — Time series, sample sessions, **metadata** breakdown with per-value **comparison coverage** (use `automationEmitsOnly` on `comparisonExecutionScope` to align metadata “covered” with test-tagged emits only).
   - **`get_truecoverage_child_event_tree`** — Top **next** events after the current title; pass **`coverage_scope`** with `automationEmitsOnly` when transition coverage should ignore manual paths.
   - **`get_truecoverage_event_transition`** / **`get_truecoverage_event_time_series`** — Deeper transition and metric series as needed.
4. Turn gaps into a prioritized plan (tests, instrumentation, or both).

### Metadata keys and “coverage”

Use metadata for gap analysis **only when the key is a meaningful product dimension** (e.g. `plan_tier`, `payment_method` where behavior differs). **Do not** treat **user identifiers**, **free-text**, or **high-cardinality** dimensions (e.g. `user_id`, raw `user_country`) as goals to “cover every value” unless the product logic genuinely branches on them—the platform can mark keys as high-cardinality; prefer skipping those for coverage prioritization.

---

## Commands

| User intent | Action |
|-------------|--------|
| `/testchimp setup truecoverage` (or setup-truecoverage) | Walk through RUM install, env vars, helper, reporter; set `enabled=true` when done. |
| `/testchimp instrument` | Instrument current PR work with emits; run setup first if not `enabled=true` and user wants it. |

---

## Event documentation: `plans/events/`

Events do **not** require server-side registration. To avoid duplicate names and document metadata for agents, add one **`.md` file per event type** under **`plans/events/`** (under the mapped plans root).

**Frontmatter:**

| Field | Description |
|-------|-------------|
| `title` | kebab-case; match the filename. |
| `description` | Details about the event. Eg: When the event fires.|
| `added-on` | Date instrumentation was added (ISO date). |
| `significance` | 1–5 for audit prioritization (1=low, 5=high). |

**Body:** List metadata keys and allowed values or types (e.g. fixed vocab for `form-of-payment`, free text, max length etc).

---

## MCP tools (TrueCoverage)

Configured via **`testchimp-mcp-client`** with `TESTCHIMP_API_KEY`: `list_rum_environments`, `get_truecoverage_events`, `get_truecoverage_event_details`, `get_truecoverage_child_event_tree`, `get_truecoverage_event_transition`, `get_truecoverage_event_time_series`, `get_truecoverage_session_metadata_keys`, `get_truecoverage_event_metadata_keys`.

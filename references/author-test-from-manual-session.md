# SmartTest from a recorded manual session

## Goal

Author **one SmartTest** using a recorded manual session as a **reference guide** (steps, screenshots, notes) while autonomously navigating the app — not as a script to paste verbatim. This is the **same create-tests authoring playbook**; only the **session evidence source** differs:

| Source | When | How to load evidence |
| --- | --- | --- |
| **Cloud** | Pasted **Copy test generate prompt** / **`/testchimp author test for manual session: <id>`** | MCP/CLI **`get-manual-session-details`** |
| **Local folder** | Studio handoff: **`/testchimp create a smarttest for scenario: <ordinal>. for additional context - you can refer the recorded manual test session: <path>.`** | Read `<path>/job_detail.json` (and sibling screenshot files) on disk — **do not** call **`get-manual-session-details`** |

This flow is **authoring-only**. Do **not** run the full `/testchimp test` chain (Analyze, Plan, Validate, ExploreChimp) unless the user explicitly asks.

Product guide (cloud capture + prompt): [Creating SmartTests — from manual session capture](https://docs.testchimp.io/smart-tests/creating#2-from-manual-session-capture-chrome-extension).

## When agents should suggest this flow (fallback)

Use this as a **fallback**, not the default authoring path.

1. Agent is asked to create a SmartTest for a scenario (e.g. `/testchimp test`, create-tests, or “author test for `TS-<n>`”).
2. Scenario text alone is too thin (e.g. one-line description).
3. Agent **first** tries to infer enough Arrange/Act/Assert from the **codebase**, PR/branch changes, and existing harness (POMs, fixtures, seeds, sibling specs).
4. If that still fails — not enough to author without inventing the journey — **stop** and ask the user to capture a **manual test session** (Chrome extension or Studio Record), then paste the generate prompt / Studio handoff.

Do **not** suggest capture when a clarifying question, headed takeover, or further repo reading would unblock you. Full user-facing steps: [`write-smarttests.md`](./write-smarttests.md) § **Insufficient scenario context → suggest manual session capture**.

## Inputs

- **Scenario ordinal** (preferred when present) — from Studio / create-tests prompts such as `/testchimp create a smarttest for scenario: <n>`. Treat as the primary authoring scope (`TS-<n>`). Fetch with `get-test-scenarios --scenario-ordinal-ids <n>` when not already loaded from plans.
- **Cloud manual session id** — from `/testchimp author test for manual session: <id>…` or the viewer URL (`job_id` on `/smart-test-execution?job_id=…&test_type=manual`).
- **Local session folder path** — from `for additional context - you can refer the recorded manual test session: <path>` (Studio CREATE_TEST handoff). Absolute path to a folder under `~/.testchimp/data/sessions/…`.

## Workflow

### 1) Load manual session evidence

Choose **exactly one** source:

#### A) Local session folder (Studio)

When the prompt names a recorded manual test session **folder path**:

1. **Do not** call MCP/`get-manual-session-details`.
2. Read **`<path>/job_detail.json`** first (viewer-shaped detail: `testName`, `status`, `steps[]` with `stepId`, `description`/`code`, `notes`, `bugs`, and screenshot fields as **relative filenames** in the same folder).
3. Optionally read **`<path>/meta.json`** for `id`, `projectId`, `scenarioIds`, `environment`, `release`, `purpose`.
4. Screenshot refs are files in the **same directory** (not GCS). Prefer `steps[].code` and `steps[].notes`; open an image **only when needed** (ambiguous selector, unclear UI state, area note with a bounding box, or a stuck assertion).

Typical layout:

| File | Role |
|---|---|
| `meta.json` | Session metadata |
| `job_detail.json` | Steps / notes / relative screenshot refs |
| `screenshot-*.jpg` (etc.) | Images referenced by steps |

Then continue from step 2. If the prompt also names a **scenario ordinal**, that ordinal is authoritative for business context and annotations (prefer it over `meta.json` alone).

#### B) Cloud session id (platform Copy prompt)

Use MCP **`get-manual-session-details`**:

```json
{ "manualSessionId": "<session-id>" }
```

If MCP is unavailable, use CLI:

```bash
testchimp get-manual-session-details --manual-session-id "<session-id>"
```

The response includes:

- **`projectId`**, **`title`**, **`environment`**, **`release`**, **`branchName`**, **`status`**
- **`steps[]`** — `description`, `code` (recorded Playwright commands), **`screenshotUrl`** (short-lived signed URLs for GCS-stored screenshots; omitted when inline `data:` URLs were stored), **`notes[]`**
- **`linkedScenarios[]`** — `scenarioOrdinalId`, `scenarioTitle`
- **`linkedScenarioOrdinalIds[]`** — deduplicated ordinals for a single **`get-test-scenarios`** call

Read **`plans/knowledge/ai-test-instructions.md`** for environment provisioning before spawning Playwright. Satisfy **Preamble #4** (`TESTCHIMP_API_KEY` on the runner process) before any test run.

When **`branchName`** is present, resolve **`BASE_URL`** per [`environment-management.md`](./environment-management.md) (branch-scoped endpoint config) before navigating.

### 2) Load business context from linked scenarios

Prefer the **scenario ordinal from the prompt** when present (Studio create-smarttest handoff). Otherwise use **`linkedScenarioOrdinalIds`** / `meta.json` `scenarioIds` from the session.

If there is **no** scenario ordinal and **`linkedScenarioOrdinalIds`** is **empty**, derive test intent from session title/steps/notes and ask the user to link scenarios in the platform if scenario **`annotation`** linkage is required.

Otherwise:

1. Locate the mapped plans root via the **`.testchimp-plans`** marker file.
2. For each ordinal, check the mapped **`plans/scenarios/`** tree (platform path; repo folder name may differ) for **`TS-<n>.md`** or equivalent synced scenario files.
3. For ordinals **not** found locally, call **`get-test-scenarios`** **once** with all ids:

   ```bash
   testchimp get-test-scenarios --scenario-ordinal-ids 101,102
   ```

4. Collect all **`userStoryOrdinalIds`** from the response (dedupe), then call **`get-user-stories`** once with that set.

Use scenario + user story content to understand **business intent**, preconditions, and expected outcomes. The manual session shows **how a human exercised the flow**; scenarios define **what** must be verified.

### 3) Plan the test (arrange / act / assert)

Before writing code, for the combined scope of all linked scenarios:

- Identify **Arrange** — seed endpoints, fixtures, mocks, initial UI posture
- Identify **Act** — user-visible steps the test must perform
- Identify **Assert** — UI assertions and probe/read API validations

Load these references as needed during authoring:

- [`create-tests.md`](./create-tests.md) — create-tests workflow (this flow is Execute-style authoring for the named scenario)
- [`run-qa.md`](./run-qa.md) — Execute-phase batched order (seeds → probes → env → fixtures → tests); use the **Execute** sections only (not full Analyze/Plan/Validate chain)
- [`seeding-endpoints.md`](./seeding-endpoints.md), [`fixture-usage.md`](./fixture-usage.md), [`mocking_strategy.md`](./mocking_strategy.md)
- [`write-smarttests.md`](./write-smarttests.md) for UI SmartTest patterns and scenario **`annotation`** rules

**Multi-scenario sessions:** author **one SmartTest** with multiple scenario annotations in the same `annotation` array (one `{ type: 'scenario', description: '#TS-<n>' }` per linked scenario; see [`write-smarttests.md`](./write-smarttests.md)).

### 4) Author the SmartTest using the manual session as reference

Autonomously navigate the app (headed) the same way you would for scenario-only authoring. When blocked or uncertain:

- Consult **`steps[].code`** for recorded Playwright commands and selector hints
- Read **`steps[].notes[]`** for any additional comments the user left on session steps
- Open **`steps[].screenshotUrl`** / local screenshot files **only when needed** (do not preload every image — LLM cost)

Do **not** copy the recorded script line-for-line. Translate into maintainable SmartTest code with proper fixtures, seeds, and assertions aligned to the linked scenarios - following the rest of the test suite.

**Naming (file, test title, and script):** Name the spec file and `test('…')` title from the **linked scenario(s)** — slug the scenario title or reuse an existing spec in the same feature area (see [`write-smarttests.md`](./write-smarttests.md)). The manual session id is an opaque platform identifier; **do not** embed it in the filename, test title, or comments. Use scenario **`annotation`** entries (`{ type: 'scenario', description: '#TS-<n>' }`) for traceability instead.

Implement:

- Reuse or author **seed endpoints** and **probes** as needed
- Reuse or author **fixtures** (test-run scoped per [`fixture-usage.md`](./fixture-usage.md))
- Add scenario **`annotation`** entries (`{ type: 'scenario', description: '#TS-<n>' }`) using ordinals from the prompt / **`linkedScenarios`** (never invent `#TS-*` ids; `description` is **only** the id — no title)
- Run the test until it passes or report a clear blocker after multiple attempts fail.

### 5) Finish

- Confirm the SmartTest passes in a headed run against the environment in `ai-test-instructions.md`.
- If backend seed/probe code changed, restart or reprovision the environment before the final run.
- Do **not** run Validate-phase atlas work or ExploreChimp unless the user asks for the full `/testchimp test` chain.
- Best-effort **`report-agent-action`** for the new/updated SmartTest (`CREATED` / `UPDATED` + TestLocator). When this flow ran **standalone** (not nested under run-qa), mint a ULID if none exists and run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — **`ACTION_COMPLETED`** with `WORKFLOW` + `create-tests` (or the parent workflow id when nested).

## Difference from scenario-only authoring

| Scenario-only (`/testchimp create a smarttest for scenario: <n>`) | Manual session evidence |
| --- | --- |
| Business context from scenario + user stories only | Same, **plus** manual session steps/screenshots/notes as an unblock reference |
| Agent discovers UI entirely by exploration | Agent may consult what the human did when stuck on values, selectors, or flow order |
| May be part of full PR test workflow | **Authoring-only** by default |

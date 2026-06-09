# `/testchimp author test for manual session` — SmartTest from a recorded manual session

## Goal

Given a manual test session id (from the TestChimp manual session viewer **Copy script generate prompt**), fetch the session details and linked scenario business context, then author **one SmartTest** that covers all linked scenarios. Use the manual session steps, screenshots, and notes as a **reference guide** while autonomously navigating the app — not as a script to paste verbatim.

This flow is **authoring-only**. Do **not** run the full `/testchimp test` chain (Analyze, Plan, Validate, ExploreChimp) unless the user explicitly asks.

## Inputs

- **Manual session id** — parse from the pasted prompt (`/testchimp author test for manual session: <id>…`) or from the viewer URL (`job_id` on `/smart-test-execution?job_id=…&test_type=manual`).

## Workflow

### 1) Fetch manual session details (MCP preferred)

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

If **`linkedScenarioOrdinalIds`** is **empty**, the session has no mapped scenarios — derive test intent from session title/steps/notes and ask the user to link scenarios in the platform if **`// @Scenario:`** linkage is required.

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

- [`testing-process.md`](./testing-process.md) — Execute-phase batched order (seeds → probes → env → fixtures → tests); use the **Execute** sections only (not full Analyze/Plan/Validate chain)
- [`seeding-endpoints.md`](./seeding-endpoints.md), [`fixture-usage.md`](./fixture-usage.md), [`mocking_strategy.md`](./mocking_strategy.md)
- [`write-smarttests.md`](./write-smarttests.md) for UI SmartTest patterns and **`// @Scenario:`** comment rules

**Multi-scenario sessions:** author **one SmartTest** with multiple `// @Scenario: #TS-<n> <Title>` comments (one per linked scenario; see [`write-smarttests.md`](./write-smarttests.md)).

### 4) Author the SmartTest using the manual session as reference

Autonomously navigate the app (headed) the same way you would for scenario-only authoring. When blocked or uncertain:

- Consult **`steps[].code`** for recorded Playwright commands and selector hints
- Open **`steps[].screenshotUrl`** when present to see UI state at each step
- Read **`steps[].notes[]`** for any additional comments the user have left in the session steps.

Do **not** copy the recorded script line-for-line. Translate into maintainable SmartTest code with proper fixtures, seeds, and assertions aligned to the linked scenarios - following the rest of the test suite.

Implement:

- Reuse or author **seed endpoints** and **probes** as needed
- Reuse or author **fixtures** (test-run scoped per [`fixture-usage.md`](./fixture-usage.md))
- Add **`// @Scenario: #TS-<n> <Title>`** using ordinals/titles from **`linkedScenarios`** (never invent `#TS-*` ids)
- Run the test until it passes or report a clear blocker after multiple attempts fail.

### 5) Finish

- Confirm the SmartTest passes in a headed run against the environment in `ai-test-instructions.md`.
- If backend seed/probe code changed, restart or reprovision the environment before the final run.
- Do **not** run Validate-phase atlas work or ExploreChimp unless the user asks for the full `/testchimp test` chain.

## Difference from scenario-only authoring

| Scenario-only (`/testchimp test - author test for scenario: TS-<n>`) | Manual session flow |
| --- | --- |
| Business context from scenario + user stories only | Same, **plus** manual session steps/screenshots/notes as an unblock reference |
| Agent discovers UI entirely by exploration | Agent may consult what the human did when stuck on values, selectors, or flow order |
| May be part of full PR test workflow | **Authoring-only** by default |

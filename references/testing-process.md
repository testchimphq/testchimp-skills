# /testchimp test

This document defines the **phased workflow** for testing a PR with TestChimp.  
`/testchimp test` should follow this flow in order:

1. Plan
2. Setup
3. Execute
4. Cleanup

Use this as the primary reference for `/testchimp test`. For SmartTest authoring patterns and examples, load **[`write-smarttests.md`](./write-smarttests.md)** during the **Execute** phase. For **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`), **`testInfo`** scoping, and **probe** specs (`page.pause()`), load **[`fixture-usage.md`](./fixture-usage.md)**. For **test-only seed, teardown, and read** endpoints (discovery, proxy pattern, idempotency, post-UI assertions), load **[`seeding-endpoints.md`](./seeding-endpoints.md)**. For TrueCoverage rules (instrumentation, `plans/events/*.event.md`), load **[`truecoverage.md`](./truecoverage.md)** when RUM is in scope.

---

## Phase 1: Plan

Goal: produce a markdown plan document that is explicitly for **authoring TestChimp SmartTests**.

### Derive change context

Before planning scenarios and tests, derive the **change context**.

**Optional user focus (takes precedence when present):** If the user names an **area**, **user story**, **scenario**, or gives **additional focus instructions** (what to validate, edge cases, acceptance criteria), treat that as the primary scope for this run. Prioritize reading and testing against **that** context: locate matching or related material in the mapped `plans/` tree, align SmartTests and execution to it, and use PR/commit analysis only as supporting signal (e.g. to see what code might implement that area). Do **not** substitute a generic “whole PR” pass when the user has specified a narrower focus—unless they also ask for broader regression.

**Default when no extra focus is given:** Assume the user is on a PR branch and analyze **the PR’s changes**, then run the standard planning workflow (existing plans → missing plans → coverage gaps), **cross-referencing** mapped test plans to find relevant scenarios for the changed behavior.

1. **Assume PR branch by default**
   - Treat the current branch as a PR branch and analyze the delta against the base branch (typically `main`) using a merge-base diff (e.g. `git diff origin/main...HEAD`).
   - Extract **likely user-journey impact** from the change set. Do not limit this to “frontend changes”: backend-only changes can still affect user-facing behavior. Consider:
     - UI flows impacted (auth/checkout/onboarding/search/settings, etc.)
     - API contract / validation changes that surface as UI errors or changed UI states
     - Authorization/permission changes and role-based access
     - Feature flags, pricing/rules engines, state transitions, async jobs that affect UI
     - Analytics/tracking and error-state behavior

2. **Fallback when on `main`**
   - If the user is on `main` (or no clear PR branch exists), approximate the PR delta by reviewing the **last few commits** (commit messages + file changes) and infer which user journeys could be affected.

Use the derived change context to (a) locate existing relevant plans/scenarios, (b) identify missing stories/scenarios, and (c) drive targeted coverage queries (`get_requirement_coverage`, `get_execution_history`) to surface gaps.

**TrueCoverage gate:** Read `plans/knowledge/ai-test-instructions.md` first (if available) and follow **[`truecoverage.md`](./truecoverage.md)**. Only plan/execute TrueCoverage instrumentation when the project-level `### TrueCoverage Plan` indicates it is in scope (or the user explicitly opts in during this run).

The plan must include:

1. **Existing relevant plans**
   - Read the mapped `plans/` tree and identify stories/scenarios impacted by the PR.
   - Review PR changes and map changed behavior to existing scenarios.
   - Query MCP coverage for those areas (`get_requirement_coverage`, `get_execution_history`) and capture failing/missing coverage signals.
2. **Missing plans**
   - Identify missing stories/scenarios for behavior added or changed by the PR.
   - List what new stories/scenarios should be authored.
3. **Test case outline**
   - Define test cases to add or update.
   - For each case, specify **UI test**, **API test**, or **manual verification**.
   - Link each automated test case to scenario ids where available.
   - For API-designated cases, mark that execution should follow **[`api-testing.md`](./api-testing.md)**.
   - Determine API vs UI per scenario using this rubric:
     - Choose a **UI test** when the main risk is user-facing behavior (rendering, navigation, interaction state, accessibility, client-side validation).
     - Choose an **API test** when the main risk is backend contract/data behavior (request-response semantics, business rules, persistence, state transitions).
     - Choose **both** when layered confidence is needed (thin UI smoke + deeper API assertions).
     - Ask these checks: (1) what risk is being reduced, (2) can outcome be asserted from API state alone, (3) is browser interaction required by acceptance criteria, (4) does UI automation add maintenance cost without additional signal?
   - Record the decision rationale in 1-2 lines per planned case.
4. **Prerequisites + environment strategy**
   - **Fixtures + seed/read APIs (per test case):** Decide which **fixture-backed posture** each UI test needs. The **plan must list** which **`fixtures/`** dependencies apply to which case and any **missing** pieces: seed/teardown/**read** endpoints, env wiring, or new domain fixture modules. **Authoring or extending [`fixtures/`](./fixture-usage.md) and the APIs they call is part of Plan/Setup** when tests depend on specific data. Prefer **few reusable fixture extensions** composed in specs—not a unique mega-fixture per test. Extra one-off steps (e.g. toggle a flag) stay **inline** in the test when they do not deserve a shared fixture.
   - **Execution order (core idea):** Playwright runs **fixture setup** (seed via APIs) **before** the test body. The browser steps assume the backend/data already matches that posture. Do not skip fixtures when the plan called for seeded data.
   - Read `plans/knowledge/ai-test-instructions.md` first (if available), for persisted project decisions.
   - Decide environment mode:
     - **Persistent backend + local/preview frontend** for frontend-only changes when sufficient. This is fast, cheap - so favourable default.
     - **Isolated full-stack ephemeral environment** when backend changes affect behavior. This enables full stack isolation and stronger consistancy guarantees, but is slow to provision (~5-10 mins), and costs (since require actual deployment). Use only when necessary.
   - If using persistent environments, infer reusable data from existing tests, **`fixtures/`**, POMs, and env files; ask user only for missing critical values.
   - If using ephemeral environments, call `get_eaas_config`; if it returns empty/unconfigured, stop and ask user to configure EaaS in TestChimp. Refer `/references/environment-management` for more details on setup and provision.
5. **Infra gaps**
   - Identify missing seed/teardown/read endpoints or missing harness infrastructure (see **[`seeding-endpoints.md`](./seeding-endpoints.md)**).
   - Include remediation tasks in the plan before test authoring.
6. **TrueCoverage (when enabled for the project)**
   - Use **[`truecoverage.md`](./truecoverage.md)** as the full reference (RUM helper, credentials, **`plans/events/*.event.md`** format, audit/MCP). If the PR adds or materially changes **user journeys** worth measuring, plan instrumentation accordingly.
   - **Defining events:** Choose **stable, semantic** names for journey steps (not one-off UI noise). For each event type you add or change, plan a matching **`plans/events/<kebab-case>.event.md`** file so agents share one vocabulary—see the **Event documentation** section in [`truecoverage.md`](./truecoverage.md).
   - **Per-event metadata keys:** These slice **per-event** coverage metrics. Use **only low-cardinality** keys whose values form a **small, meaningful set** for comparing coverage (e.g. coarse **checkout path**, **payment method** category). **Do not** include **PII**. **Do not** use **high-cardinality** keys or values (e.g. `org_id`, `user_id`, raw emails, free-text)—they are unsuitable for sliced coverage and explode cardinality. Design keys so each dimension answers: *“Would I want a coverage breakdown by this slice?”*
   - **Session metadata keys:** Use these for **session-wide, non-mutating** context that applies across the session (e.g. coarse **user role**, **region/country** bucket, **tenant tier** if bounded). Same constraints: **no PII**, **no identifiers or exploding value sets** as keys meant for slicing. Prefer a small enum-like vocabulary per key so **session-level** slices stay interpretable for coverage.

**Plan output:** write a `.md` plan artifact summarizing scenarios, missing scenarios, test matrix (UI/API/manual), prerequisites, environment choice, infra-gap actions, and TrueCoverage instrumentation when applicable.

---

## Phase 2: Setup

Goal: create the environment and prerequisites needed to author and run tests.

1. **Environment provision (when needed)**
   - If plan selected ephemeral env and `get_eaas_config` is configured, call `provision_ephemeral_environment` with current branch name.
   - Poll with `get_ephemeral_environment_status` roughly every minute until ready (typical provisioning time is several minutes). After 20 minutes if still not provisioned, inform the user to check the provider and ask whether to kill or keep trying. If user says to kill the environment, use mcp tool to kill the environment.
2. **Address infra gaps**
   - Implement or wire missing seed/teardown/read endpoints and **`fixtures/`** modules that the **plan** marked as missing, so tests can declare the needed fixtures and run.
3. **TrueCoverage setup (when planned / enabled)**
   - If instrumentation was planned and TrueCoverage is in scope per `plans/knowledge/ai-test-instructions.md`: ensure `testchimp-rum-js` is available in the **application** package, add or update a **single helper** for emits, wire **API key / project id / environment** from config, and add **`plans/events/*.event.md`** docs for new event types. Skip if the project plan indicates TrueCoverage is out of scope or the user declined.
4. **Fix plan gaps first**
   - Author missing stories/scenarios before writing tests.
   - Follow **[`test-planning.md`](./test-planning.md)** for MCP create/update and markdown structure.

**Setup outcome:** runnable environment, infra blockers resolved (or clearly flagged), plan artifacts complete enough for execution,TrueCoverage instrumentation updates planned out.

---

## Phase 3: Execute

Goal: author and validate SmartTests for planned cases.

1. Load **[`write-smarttests.md`](./write-smarttests.md)** and follow its authoring guidance (for UI test authoring).
2. **Sanity-check likely affected existing tests (small, best-effort subset)**: before writing new tests, identify a **small set** of existing tests that are likely related to the derived change context (based on paths touched, scenarios referenced, and test naming). Run them first as a **quick regression check** (this is intentionally fuzzy; do not try to run *all* “possibly affected” tests).
   - If these tests **fail**, triage each failure:
     - If the PR intentionally changed the behavior, **update the test** (and/or fixtures) to match the new expected behavior and ensure the linked scenario still reflects requirements.
     - If the behavior should not have changed, treat it as a **real regression** and **call it out** clearly in the report (and prioritize fixing product code over “fixing tests”).
     - If it’s unclear, gather evidence (UI screenshots/logs/network) and explain why it’s ambiguous rather than guessing.
2. **Fixtures before UI:** For each UI case that the **plan** tied to a seeded posture, ensure the spec **imports `test` from `fixtures`** (merged entry) and **lists the needed fixtures** so setup runs before browser steps. See **[`fixture-usage.md`](./fixture-usage.md)**.
3. Create a Playwright browser session, authenticate once, and store storage state in a temporary file for reuse. Make sure the authored test also follows same via storageContext.
4. **Application emits (TrueCoverage):** When `enabled=true` and the plan called for new /updated events, add emits in the **app** code for those interactions and keep **`plans/events/*.event.md`** in sync. Do this **before** authoring individual SmartTests or API tests that depend on those events being emitted or on TrueCoverage picking them up. This work is independent of SmartTest files but should land in the same PR when possible.
5. Implement each planned test case (UI/API as planned), reusing storage state for faster repeated sessions. For writing API tests, refer **[`api-testing.md`](./api-testing.md)**.
6. Run written tests with Playwright and fix failures iteratively. **`cd`** to the mapped SmartTests root (folder with **`.testchimp-tests`**), then run via **`npx playwright …`** (see [`write-smarttests.md`](./write-smarttests.md) **Running Playwright**). Ensure **`TESTCHIMP_API_KEY`** is set in the shell (not only in **`.env-QA`**). If runs or MCP return **401**, follow the skill’s HTTP 401 guidance (Project Settings → Key management).
7. Retry fix-and-rerun up to **2 attempts per failing test**. If still failing, stop retrying those and clearly ask user for help with the unresolved failures (in the report created in the next phase).

---

## Phase 4: Cleanup and report

Goal: remove temporary resources and avoid leaked infrastructure. Communicate results to user.

1. If an ephemeral environment was provisioned, destroy it via `destroy_ephemeral_environment` using the returned environment id.
2. Delete temporary storage-state files created for login/session reuse.
3. Report what was done, flag any things that require user attention (such as failing tests etc.).
4. Include a summary of:
   - New TrueCoverage event emits added / updated
   - # of tests authored (with breakdown of API vs UI)  - and breakdown by failing / passing.
   - New or updated **fixtures** / seed endpoints
   - Any infra setups that was done

---

## Expected `/testchimp test` deliverables

- A test-plan markdown artifact for this PR (this is not for persistance, but for planning the work to be done - though we can leave it for the user to clean up the files - or create the plan in a system location such as ~.cursor/plans etc.).
- Any required new stories/scenarios authored (if gaps existed).
- New/updated SmartTests + API Tests and execution results.
- A short report of what was achieved.

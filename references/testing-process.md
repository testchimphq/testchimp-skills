# /testchimp test

This document defines the **phased workflow** for testing a PR with TestChimp.  
`/testchimp test` should follow this flow in order:

1. Plan
2. Setup
3. Execute
4. Cleanup

Use this as the primary reference for `/testchimp test`. For SmartTest authoring patterns and examples, load **[`write-smarttests.md`](./write-smarttests.md)** during the **Execute** phase. For **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`), **`testInfo`** scoping, and **probe** specs (`page.pause()`), load **[`fixture-usage.md`](./fixture-usage.md)**. For **test-only seed, teardown, and read** endpoints (discovery, proxy pattern, idempotency, post-UI assertions), load **[`seeding-endpoints.md`](./seeding-endpoints.md)**. For TrueCoverage rules (instrumentation, `plans/events/*.event.md`), load **[`truecoverage.md`](./truecoverage.md)** when RUM is in scope.

---

## Non-negotiables (agent guardrails for this flow)

Before running **any** Playwright command (headed or headless), or authoring **any** `ai-wright` steps:

- **Write the Plan artifact first**: produce a markdown plan document for this run (see Phase 1), grounded in PR diffs + existing `plans/` material.
- **Get explicit agreement on the Plan**: pause after the plan and wait for “go ahead” / approval to proceed to Setup + Execute.
- **Provision / select the environment per `plans/knowledge/ai-test-instructions.md`**: choose the recorded strategy and satisfy its “up + healthy” contract before Execute.
- **Default to headed authoring/debug**: during authoring and triage, prefer `--headed --debug` so the user can observe/intervene.
- **TrueCoverage belongs in the Plan**:
  - If the PR adds or changes **user journeys / user-facing behaviors**, the Plan must explicitly decide whether to instrument.
  - If TrueCoverage is **not configured yet** and there is **no explicit opt-out** recorded in `plans/knowledge/ai-test-instructions.md`, the agent must **ask the user** whether to enable it for this repo and include **RUM wiring + event docs** work in the Plan when the user agrees.
  - If TrueCoverage **is already configured**, the agent should **consider** whether there are **key user events** worth instrumenting for the changed behavior, and include them (with `plans/events/*.event.md` updates) when appropriate.
- **Mocking belongs in the Plan (always)**:
  - Explicitly decide per test case: **real backend**, **Playwright HTTP mocking** (`page.route` / `context.route`), and (when applicable) **AIMock** for LLM-backed flows.
  - If AIMock is selected, the Plan must include: wiring tasks, enablement mechanism (env flag / config), and how to validate it is actually being used.
- **Fixtures belong in the Plan (always)**:
  - For every UI SmartTest planned, list the required **fixture-backed posture** and any missing `fixtures/` modules or missing seed/read/teardown endpoints.
  - If new fixtures/endpoints are needed, treat them as **Setup blockers** (not “nice-to-haves”).
- **Blockers must be called out in the Plan**: list every known blocker with (a) owner (agent vs user), (b) the exact action required, and (c) the earliest phase it blocks.
- **Final checklist is required**: the plan document must end with an “Execution checklist” that the agent will tick through, including:
  - TrueCoverage plan respected (and instrumentation executed when in-scope)
  - MCP coverage-gap queries executed (when MCP is configured) and results recorded
  - Environment provisioned/selected per `ai-test-instructions` and health contract satisfied
  - Tests executed on that provisioned environment
  - Cleanup performed (ephemeral env destroy, temp artifacts not committed)

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

**TrueCoverage gate:** Read `plans/knowledge/ai-test-instructions.md` first (if available) and follow **[`truecoverage.md`](./truecoverage.md)**.

- If `ai-test-instructions.md` contains an **explicit opt-out** (TrueCoverage disabled / out of scope), respect it.
- If `ai-test-instructions.md` says TrueCoverage was **deferred during init**, do **not** treat that as “deferred forever”:
  - During **`/testchimp test`**, assume TrueCoverage is **in-scope now** for the PR and include the necessary wiring + event docs for the changed journeys.
- Otherwise, when the PR adds/changes **user journeys / user-facing behaviors**, the agent should:
  - **If not configured**: ask the user whether to enable TrueCoverage now; if yes, include RUM wiring + docs in the Plan.
  - **If configured**: decide whether to add/adjust instrumentation for key events introduced/changed by the PR, and include that work in the Plan.

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
6. **TrueCoverage (when applicable)**
   - Use **[`truecoverage.md`](./truecoverage.md)** as the full reference (RUM helper, credentials, **`plans/events/*.event.md`** format, audit/MCP).
   - If the PR adds or materially changes **user journeys / user-facing behaviors**, the plan must include a clear decision:
     - **Enable + wire TrueCoverage** (when not configured and no explicit opt-out exists; requires user agreement), or
     - **Add/adjust key events** (when already configured), or
     - **Do not instrument** (only with an explicit rationale + any opt-out reference).
   - **Defining events:** Choose **stable, semantic** names for journey steps (not one-off UI noise). For each event type you add or change, plan a matching **`plans/events/<kebab-case>.event.md`** file so agents share one vocabulary—see the **Event documentation** section in [`truecoverage.md`](./truecoverage.md).
   - **Per-event metadata keys:** These slice **per-event** coverage metrics. Use **only low-cardinality** keys whose values form a **small, meaningful set** for comparing coverage (e.g. coarse **checkout path**, **payment method** category). **Do not** include **PII**. **Do not** use **high-cardinality** keys or values (e.g. `org_id`, `user_id`, raw emails, free-text)—they are unsuitable for sliced coverage and explode cardinality. Design keys so each dimension answers: *“Would I want a coverage breakdown by this slice?”*
   - **Session metadata keys:** Use these for **session-wide, non-mutating** context that applies across the session (e.g. coarse **user role**, **region/country** bucket, **tenant tier** if bounded). Same constraints: **no PII**, **no identifiers or exploding value sets** as keys meant for slicing. Prefer a small enum-like vocabulary per key so **session-level** slices stay interpretable for coverage.

**Plan output:** write a `.md` plan artifact summarizing scenarios, missing scenarios, test matrix (UI/API/manual), prerequisites, environment choice, infra-gap actions, and TrueCoverage instrumentation when applicable.

### Phase 1 completion gate (must pass before Phase 2)

Before proceeding to **Setup**, the agent must confirm:

- [ ] **Plan artifact written** (path + brief summary).
- [ ] Plan is grounded in **PR diff** (`origin/main...HEAD`) or the fallback is explicitly documented.
- [ ] Relevant existing **plans/stories/scenarios** were located and mapped to the change context.
- [ ] **Missing plans** (stories/scenarios) were identified (and whether they must be authored now vs deferred is stated).
- [ ] **Test matrix** exists (UI/API/manual) and each planned test has a 1–2 line rationale.
- [ ] **Fixtures / seed / read / teardown prerequisites** are listed per planned test, with explicit blockers.
- [ ] **Mocking decisions** are recorded per test (real vs route mocks vs AIMock).
- [ ] **TrueCoverage decision** is explicitly recorded:
  - [ ] Opt-out/defer respected **OR**
  - [ ] Not configured → user will be asked (and wiring tasks are in plan) **OR**
  - [ ] Configured → key events considered (instrument vs not + rationale).
- [ ] **User agreement** received to proceed (or the run is explicitly declared “plan-only”).

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

### Phase 2 completion gate (must pass before Phase 3)

Before proceeding to **Execute**, the agent must confirm:

- [ ] Environment provisioned/selected per `plans/knowledge/ai-test-instructions.md` and **health validated** (how).
- [ ] Any plan-marked infra gaps (fixtures, seed/read/teardown endpoints, env wiring) are **implemented** or explicitly marked as blocking.
- [ ] TrueCoverage setup work is either:
  - [ ] completed (when planned), or
  - [ ] explicitly deferred with user agreement.

---

## Phase 3: Execute

Goal: author and validate SmartTests for planned cases.

1. Load **[`write-smarttests.md`](./write-smarttests.md)** and follow its authoring guidance (for UI test authoring).
2. **Targeted existing-tests smoke (keep it tiny + strongly related)**: run a **very small** set of existing tests that are **directly** tied to the PR’s changed behavior (same feature area / same story/scenario ids / same user journey). This is a **regression smoke**, not a “run existing tests” phase.
   - **Selection rule**: pick only tests with a clear, strong link to the change context. Avoid broad “possibly affected” guesses.
   - **Size + time box**: aim for **2–5 tests** (or the smallest equivalent set) and keep runtime to **~2-3 mins** total. If the suite isn’t that fast, shrink the set further.
   - **Stop early**: once you have basic regression signal (or you hit the time box), move on to next phases of the testing process.
   - If a smoke test **fails**, triage quickly:
     - If the PR intentionally changed the behavior, **update the test** (and/or fixtures) to the new expectation and ensure linked scenarios still reflect requirements.
     - If the behavior should not have changed, treat it as a **real regression** and **call it out** clearly (prioritize fixing product code over “fixing tests”).
     - If unclear, gather evidence (screenshots/logs/network) and state what’s ambiguous rather than guessing.
3. **Fixtures before UI:** For each UI case that the **plan** tied to a seeded posture, ensure the spec **imports `test` from `fixtures`** (merged entry) and **lists the needed fixtures** so setup runs before browser steps. See **[`fixture-usage.md`](./fixture-usage.md)**.
4. Create a Playwright browser session, authenticate once, and store storage state in a temporary file for reuse. Make sure the authored test also follows same via storageContext.
5. **Application emits (TrueCoverage):** When `enabled=true` and the plan called for new /updated events, add emits in the **app** code for those interactions and keep **`plans/events/*.event.md`** in sync. Do this **before** authoring individual SmartTests or API tests that depend on those events being emitted or on TrueCoverage picking them up. This work is independent of SmartTest files but should land in the same PR when possible.
6. Implement each planned test case (UI/API as planned), reusing storage state for faster repeated sessions. For writing API tests, refer **[`api-testing.md`](./api-testing.md)**.
7. Run written tests with Playwright and fix failures iteratively. **`cd`** to the mapped SmartTests root (folder with **`.testchimp-tests`**), then run via **`npx playwright …`** (see [`write-smarttests.md`](./write-smarttests.md) **Running Playwright**). Ensure **`TESTCHIMP_API_KEY`** is set in the shell (not only in **`.env-QA`**). If runs or MCP return **401**, follow the skill’s HTTP 401 guidance (Project Settings → Key management).
8. Retry fix-and-rerun up to **2 attempts per failing test**. If still failing, stop retrying those and clearly ask user for help with the unresolved failures (in the report created in the next phase).

### Phase 3 completion gate (must pass before Phase 4)

Before proceeding to **Cleanup and report**, the agent must confirm:

- [ ] A **tiny, strongly-related smoke** subset of existing tests was run (which + result) - if exists (if not - say so), explicitly time-boxed so execution stayed focused on authoring new tests.
- [ ] New/updated tests were authored per the plan and linked to scenario ids **only when ids exist** (never invented).
- [ ] Playwright executed from the mapped SmartTests root (folder with `.testchimp-tests`).
- [ ] `TESTCHIMP_API_KEY` was present in the run environment; any 401s were handled per guidance.
- [ ] All planned tests either:
  - [ ] pass, or
  - [ ] have a clear failure report + next steps (no silent skipping).

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

### Phase 4 completion gate (must pass before ending the run)

Before ending the run, the agent must confirm:

- [ ] Ephemeral environments destroyed (if created).
- [ ] Temporary auth/storage-state artifacts removed.
- [ ] Generated artifacts not committed (`test-results/`, `playwright-report/`, traces/videos/screens).
- [ ] Final report includes: what was tested, what was added/changed (tests/fixtures/endpoints/instrumentation), what failed (if anything), and next steps.

---

## Expected `/testchimp test` deliverables

- A test-plan markdown artifact for this PR (this is not for persistance, but for planning the work to be done - though we can leave it for the user to clean up the files - or create the plan in a system location such as ~.cursor/plans etc.).
- Any required new stories/scenarios authored (if gaps existed).
- New/updated SmartTests + API Tests and execution results.
- A short report of what was achieved.

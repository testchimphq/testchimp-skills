# /testchimp test

This document defines the **phased workflow** for testing a PR with TestChimp.  
`/testchimp test` should follow this flow in order:

1. Plan
2. Setup
3. Execute
4. Cleanup

Use this as the primary reference for `/testchimp test`. For SmartTest authoring patterns and examples, load **[`write-smarttests.md`](./write-smarttests.md)** during the **Execute** phase. For TrueCoverage rules (state file, instrumentation, `plans/events/`), load **[`truecoverage.md`](./truecoverage.md)** when RUM is in scope.

---

## Phase 1: Plan

Goal: produce a markdown plan document that is explicitly for **authoring TestChimp SmartTests**.

**TrueCoverage gate:** Read **`<SKILL_DIR>/bin/.truecoverage_setup`** and follow **[`truecoverage.md`](./truecoverage.md)** (absent file, `enabled=true|false|later`, and 3-day snooze). If you may prompt the user (e.g. first run or `later` expired), resolve their choice and update the file before relying on instrumentation.

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
   - Identify world-state prerequisites for each test (accounts, entities, feature flags, seed state).
   - Read `plans/knowledge/ai-test-instructions.md` first (if available), for persisted project decisions.
   - Decide environment mode:
     - **Persistent backend + local/preview frontend** for frontend-only changes when sufficient.
     - **Isolated full-stack ephemeral environment** when backend changes affect behavior.
   - If using persistent environments, infer reusable data from existing tests, fixtures, POMs, and env files; ask user only for missing critical values.
   - If using ephemeral environments, call `get_eaas_config`; if it returns empty/unconfigured, stop and ask user to configure EaaS in TestChimp.
5. **Infra gaps**
   - Identify missing seed/teardown endpoints or missing harness infrastructure.
   - Include remediation tasks in the plan before test authoring.
6. **TrueCoverage (when `enabled=true` in `.truecoverage_setup`)**
   - If the PR adds or materially changes **user journeys** worth measuring, plan which **semantic events** to emit, optional **metadata** keys (low cardinality), and new or updated **`plans/events/*.md`** entries for agent reference.

**Plan output:** write a `.md` plan artifact summarizing scenarios, missing scenarios, test matrix (UI/API/manual), prerequisites, environment choice, infra-gap actions, and TrueCoverage instrumentation when applicable.

---

## Phase 2: Setup

Goal: create the environment and prerequisites needed to author and run tests.

1. **Environment provision (when needed)**
   - If plan selected ephemeral env and `get_eaas_config` is configured, call `provision_ephemeral_environment` with current branch name.
   - Poll with `get_ephemeral_environment_status` roughly every minute until ready (typical provisioning time is several minutes). After 20 minutes if still not provisioned, inform the user to check the provider and ask whether to kill or keep trying. If user says to kill the environment, use mcp tool to kill the environment.
2. **Address infra gaps**
   - Implement or wire missing seed/teardown setup identified during planning.
3. **TrueCoverage setup (when planned and `enabled=true`)**
   - If instrumentation was planned: ensure `testchimp-rum-js` is available in the **application** package, add or update a **single helper** for emits, wire **API key / project id / environment** from config, and add **`plans/events/`** docs for new event types. Skip if `.truecoverage_setup` is not `enabled=true` or the user declined.
4. **Fix plan gaps first**
   - Author missing stories/scenarios before writing tests.
   - Follow **[`test-planning.md`](./test-planning.md)** for MCP create/update and markdown structure.

**Setup outcome:** runnable environment, infra blockers resolved (or clearly flagged), plan artifacts complete enough for execution.

---

## Phase 3: Execute

Goal: author and validate SmartTests for planned cases.

1. Load **[`write-smarttests.md`](./write-smarttests.md)** and follow its authoring guidance (for UI test authoring).
2. Create a Playwright browser session, authenticate once, and store storage state in a temporary file for reuse.
3. Implement each planned test case (UI/API as planned), reusing storage state for faster repeated sessions. For writing API tests, refer **[`api-testing.md`](./api-testing.md)**.
4. **Application emits (TrueCoverage):** When `enabled=true` and the plan called for new /updated events, add emits in the **app** code for those interactions and keep **`plans/events/`** in sync. This is independent of SmartTest files but should land in the same PR when possible.
5. Run written tests with Playwright and fix failures iteratively.
6. Retry fix-and-rerun up to **2 attempts per failing test**. If still failing, stop retrying those and clearly ask user for help with the unresolved failures (in the report created in the next phase).

---

## Phase 4: Cleanup and report

Goal: remove temporary resources and avoid leaked infrastructure. Communicate results to user.

1. If an ephemeral environment was provisioned, destroy it via `destroy_ephemeral_environment` using the returned environment id.
2. Delete temporary storage-state files created for login/session reuse.
3. Report what was done, flag any things that require user attention (such as failing tests etc.).

---

## Expected `/testchimp test` deliverables

- A test-plan markdown artifact for this PR (this is not for persistance, but for planning the work to be done - though we can leave it for the user to clean up the files - or create the plan in a system location such as ~.cursor/plans etc.).
- Any required new stories/scenarios authored (if gaps existed).
- New/updated SmartTests + API Tests and execution results.
- A short report of what was achieved.

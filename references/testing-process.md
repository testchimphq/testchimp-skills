# /testchimp test

This document defines the **strict workflow** for testing a PR with TestChimp.

`/testchimp test` MUST follow this flow in order:

1. **Analyze**
2. **Plan**
3. **Execute**
4. **Validate**
5. **Cleanup**

Use this as the primary reference for `/testchimp test`. For SmartTest authoring patterns and examples, load **[`write-smarttests.md`](./write-smarttests.md)** during the **Execute** phase. For **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`), **`testInfo`** scoping, and **probe** specs (`page.pause()`), load **[`fixture-usage.md`](./fixture-usage.md)**. For **test-only seed, teardown, and read** endpoints (discovery, proxy pattern, idempotency, post-UI assertions), load **[`seeding-endpoints.md`](./seeding-endpoints.md)**. For TrueCoverage rules (instrumentation, `plans/events/*.event.md`), load **[`truecoverage.md`](./truecoverage.md)** when RUM is in scope.

### Phase gating (required)

Do **not** advance **Analyze → Plan → Execute → Validate → Cleanup** until the **prior phase’s completion gate** is satisfied. **Nothing implied; nothing skipped silently.**

- For **every** gate line item: mark **done**, **blocked**, or **`N/A`** with a **one-line justification**.
- Record gate outcomes in the **branch plan file** (`<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`) under a short **“Phase N completion”** subsection (or tick inline next to the plan checklist) so reruns are deterministic.

---

## Non-negotiables (agent guardrails for this flow)

Before running **any** Playwright command (headed or headless), or authoring **any** `ai-wright` steps, the agent MUST follow the flow below and satisfy the gates.

- **Plan first (no upfront smoke runs)**:
  - Do **not** start by “running a few smoke tests” or spinning up a local/ephemeral environment just to smoke the app.
  - Go through **Analyze → Plan** first so the plan can decide the required **stories/scenarios**, **tests**, and any required **seed/teardown/read endpoints** and **fixtures**.
  - Only provision/start an environment in **Execute**  (after the plan makes infra needs explicit - and any new seed / probe endpoints are implemented, so that we dont have to restart after the changes).
- **Persist and reuse a per-branch Plan artifact first (REQUIRED)**:
  - **Always** create/update the **current branch** plan at:
    - `<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`
  - **Before planning**, **check for the existence** of that file:
    - If it exists, **read it first**, then update it based on (a) what’s already planned/done, (b) current PR diffs and plan materials, and (c) any additional user context for *this* run.
    - If it does not exist, create it and do the full Plan phase (see Phase 1).
  - The plan file must have YAML frontmatter containing:
    - `LastRunOnCommit: <commit_sha>` (commit at which this branch plan was last updated by `/testchimp test`)
  - The plan body must contain a **checklist** of action items, where each item is explicitly marked **done** (`- [x]`) or **not done** (`- [ ]`), so reruns are deterministic.
- **Get explicit agreement on the Plan**: the agent MUST pause after writing/updating the branch plan and wait for user approval before running Setup/Execute work.
- **Backend posture first (no assumptions; world-state driven)**:
  - For each planned test (i.e. each scenario you intend to validate), the agent MUST explicitly define the **required world state** (“posture”) as if the environment is **empty** other than what the currently-selected fixtures establish.
  - The posture definition MUST include:
    - **Prerequisite entities** (e.g. products, checkout configuration, feature flags, org/project/user roles, billing state etc.).
    - **Creation mechanism per entity** (fixture reuse, new fixture, seed endpoint, or mocking).
    - **Assertions** that prove posture is correct (via UI checks and/or probe/read endpoints).
  - If posture requires data that cannot be created with existing fixtures, then the Plan MUST prefer this chain (in order) and list the missing pieces as Execute blockers:
    1) **Reuse existing fixtures** (`<tests_root>/fixtures/`) by adding the fixture dependency to the test signature.
    2) **Create/update fixtures** (per-test, retry-safe; `testInfo` scoped) that call seed/probe endpoints (refer `references/fixture-usage` for guidance).
    3) **Create/update seed/probe/teardown endpoints** to support the fixture (guarded, idempotent, aligned to production flows where possible).
  - If seed/probe endpoints or fixtures are missing, that is a **Plan output** and a **hard Execute blocker** until addressed in Execute.
- **Environment strategy is binding**:
  - The agent MUST follow `plans/knowledge/ai-test-instructions.md` for environment provisioning (local vs ephemeral) and the “up + healthy” contract.
  - After seed/probe/backend changes, the agent MUST ensure the running environment actually includes those changes (restart/reprovision).
- **TrueCoverage belongs in the Plan**:
  - If the PR adds or changes **user journeys / user-facing behaviors**, the Plan must explicitly decide whether to instrument.
  - If TrueCoverage is **not configured yet** and there is **no explicit opt-out** recorded in `plans/knowledge/ai-test-instructions.md`, the agent must **ask the user** whether to enable it for this repo and include **RUM wiring + event docs** work in the Plan when the user agrees.
  - If TrueCoverage **is already configured**, the agent should **consider** whether there are **key user events** worth instrumenting for the changed behavior, and include them (with `plans/events/*.event.md` updates) when appropriate.
- **Mocking belongs in the Plan (always)**:
  - Explicitly decide per test case: **real backend**, **Playwright HTTP mocking** (`page.route` / `context.route`), and (when applicable) **AIMock** for LLM-backed flows.
  - If AIMock is selected, the Plan must include: wiring tasks, enablement mechanism (env flag / config), and how to validate it is actually being used.
- **Fixtures belong in the Plan (always; favor reuse)**:
  - For every planned UI SmartTest, the Plan MUST name the **exact fixture dependencies** (what you will add to the test signature) that establish the posture.
  - The agent MUST **search existing fixtures first** and strongly prefer reuse over creating new fixture modules.
  - If reuse is impossible, the Plan MUST specify:
    - which **new fixture(s)** will be added/extended,
    - which **seed/probe/teardown endpoint(s)** (if any) are required to implement that fixture,
    - and how the fixture proves posture correctness (read/probe assertions).
  - If new fixtures/endpoints are needed, treat them as **Execute blockers** (not “nice-to-haves”).
- **Re-run is mandatory**:
  - Any new/changed automated test MUST be executed with the real runner (UI: Playwright + browser; API: real HTTP execution) and re-run after fixes until it passes, or is explicitly recorded as failing with next steps. No “assumed pass”.
- **Scenario-link comments are mandatory (Validate phase; anomaly-driven)**:
  - Every SmartTest that represents a scenario MUST include one or more `// @Scenario: #TS-<n> <Title>` comments **as the first statement(s) in the test body** (see `SKILL.md` guardrails).
  - Missing `// @Scenario:` is an **anomaly**: it indicates either (a) the agent forgot to link, or (b) the scenario does not exist yet (planning gap).
  - The agent MUST fix anomalies in **Validate**:
    - If a relevant scenario already exists, add the missing `// @Scenario:` comment(s).
    - If no relevant scenario exists, create it via **MCP-first** (fallback to CLI) and then add the comment(s) using the real returned ID(s).
- **Cleanup is mandatory**:
  - Any environment created or started during Execute (local stack, dev server, ephemeral/EaaS env) MUST be torn down in Cleanup, and the plan must record what was stopped/destroyed (or `N/A` with reason).
- **Blockers must be called out in the Plan**: list every known blocker with (a) owner (agent vs user), (b) the exact action required, and (c) the earliest phase it blocks.

---

## Phase 1: Analyze

Goal: gather evidence and inputs needed to produce a high-signal Plan. This phase is *read-only* (no production code changes; no tests authored yet).

### Locate the branch plan file (always first)

1. **Resolve `<MAPPED_PLANS_ROOT>`**
   - Find the mapped plans root by locating the `.testchimp-plans` marker file (see `SKILL.md` → Marker files). The directory containing `.testchimp-plans` is `<MAPPED_PLANS_ROOT>`.
2. **Resolve `<branch_slug>`**
   - First resolve the **current git branch name** (preferred command):
     - `git branch --show-current`
   - **If empty** (detached HEAD), fall back to:
     - `git rev-parse --abbrev-ref HEAD`
     - If still not usable, use the short commit SHA: `git rev-parse --short HEAD`
   - **Define `<branch_slug>` deterministically from the branch name** (filename-safe):
     - Start with the resolved branch name string.
     - Lowercase it.
     - Replace any sequence of characters that is not `[a-z0-9]` with a single `_` (this includes `/` in branch names like `feature/foo`).
     - Trim leading/trailing `_`.
     - If the result is empty, use `detached_<short_sha>`.
3. **Resolve the plan path**
   - `<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`
4. **Branch-plan-first behavior**
   - If the file exists: read it, then continue planning based on **existing checklist state** + new context.
   - If missing: create it, then do the full planning steps below.

### Analyze inputs

The Analyze phase must gather:

- **Change context**
  - PR diff vs base (`origin/main...HEAD`), or an explicit fallback if not available.
- **Relevant plans context**
  - Existing stories/scenarios under `plans/` that match the change context.
  - Whether new stories/scenarios are needed.
- **Posture sketch (high level; no implementation yet)**
  - For each candidate scenario to test, write a quick sketch of the **world state prerequisites** and what fixtures/endpoints are likely needed.
  - This is intentionally lightweight in Analyze; the full mapping is written in Plan.
- **Platform evidence (via TestChimp CLI/MCP when available)**
  - Use **TestChimp CLI** (`testchimp ...`) when MCP tools are not available.
  - Suggested queries:
    - `testchimp get-requirement-coverage --folder-path <plans/... or tests/...>` (scoped to the affected area)
    - `testchimp get-execution-history --folder-path <tests/...>` (to see recent failures/flake)
  - Record results (relevant summaries) in the branch plan file (high level; no giant dumps).

### Phase 1 completion gate (Analyze → Plan)

Before proceeding to **Plan**, the agent must record **done/blocked/`N/A`** for each item (in the branch plan file):

- [ ] Branch plan exists and was read/created.
- [ ] Change context captured (diff vs base or explicit fallback).
- [ ] Relevant existing plan docs identified (stories/scenarios/events/knowledge).
- [ ] Coverage/execution history queried via CLI/MCP where applicable (or `N/A`).

---

## Phase 2: Plan

Goal: produce a written plan (persisted in the branch plan file) that the user explicitly approves, and that the agent can execute deterministically.

The Plan MUST be written under the branch plan file with these sections (in order):

1. **Test plan updates** (plans layer)
   - Stories/scenarios to create/update.
     - **Never invent IDs** means: never assume fake `#US-...` / `#TS-...` ids.
     - If scenarios / stories are missing for the PR changes, the Plan must explicitly list the **new** stories/scenarios to be created so the platform generates **real IDs**.
     - **Timing rule**: the actual `create-user-story` / `create-test-scenario` calls (and subsequent `update-user-story` and `update-test-scenario`) must be performed **only in Execute**, **after** the user approves the Plan generated.
2. **System infra updates** (product/backend)
   - Seed/teardown/read (probe) endpoints to add/update to support the **posture** required by the planned tests.
   - Seed authoring MUST follow the project’s recorded strategy in `plans/knowledge/ai-test-instructions.md`.
     - If the strategy is missing/unclear, the Plan MUST explicitly call that out as a blocker and align with the user (do not invent a new approach silently).
   - TrueCoverage instrumentation changes (events/metadata + docs) when in scope.
3. **Test infra updates** (tests harness)
   - Fixtures to create/update to enforce the posture using seed/probe endpoints, with explicit **reuse-first** analysis.
   - Mocking strategy decisions and helpers (when applicable).
4. **Test updates** (tests themselves)
   - SmartTests (UI) and/or API tests to add/update, each mapped to a scenario when an id exists.
   - Each test entry MUST include a **Posture table**:
     - prerequisite entities
     - fixture dependencies (reuse-first)
     - required seed/probe endpoints (if any)
     - any mocks
     - post-UI backend assertions (probe/read)

The Plan MUST also include:

- **Explicit user approval** checkpoint (the agent must stop here until approved). Include user approval status as a frontmatter field and update it once the user gives you consent to proceed.
- An **Execute checklist** that mirrors the four buckets above plus “validate test runs”, where each line is marked **done / blocked / N/A**.
- A **Validate checklist**:
  - Scenario-link comment audit + remediation plan (MCP/CLI create if missing, then add `// @Scenario:` comments).
- A **Cleanup checklist**:
  - Local env/process teardown steps and/or ephemeral environment destroy steps, aligned to the environment strategy used.

### Phase 2 completion gate (Plan → Execute)

Before proceeding to **Execute**, the agent must record **done/blocked/`N/A`** for each (in the branch plan file):

- [ ] Plan written with the four required sections.
- [ ] Each planned test has an explicit **backend posture** and the seed/probe/fixture mapping.
- [ ] Environment strategy chosen per `plans/knowledge/ai-test-instructions.md`.
- [ ] User explicitly approved the plan to proceed.

---

## Phase 3: Execute (do the plan)

Preamble before execution: Verify that the plan doc created above is present. Verify that it indicates user has approved. If not - PAUSE and do NOT continue.

Goal: execute the approved plan, and keep the plan checklists updated so reruns are deterministic.

During Execute, the agent MUST maintain a checklist in the branch plan file with these sections and mark each line as **done / blocked / N/A**:

### A) Test plan updates (plans layer)

- [ ] Create/update stories as planned (via CLI/MCP create/update tools).
- [ ] Create/update scenarios as planned (via CLI/MCP create/update tools).

### B) System infra updates (product/backend)

- [ ] Seed endpoints added/updated.
- [ ] Probe/read endpoints added/updated.
- [ ] Teardown endpoints added/updated (or `N/A` if posture is fully isolated per testInfo scoping).
- [ ] TrueCoverage instrumentation + `plans/events/*.event.md` updates (or `N/A` with rationale).

### C) Environment provisioning (must follow `ai-test-instructions.md`)

- [ ] Provisioned/selected environment per strategy.
- [ ] Environment is **healthy** (record how verified).
- [ ] If system infra changed (new seed endpoints added etc.): environment restarted/reprovisioned so changes are present.

### D) Test infra updates (fixtures/mocks)

- [ ] Fixtures implemented/updated to create the required posture using seed endpoints.
- [ ] Fixtures implemented/updated to assert posture using probe/read endpoints.
- [ ] Mocking helpers added/updated (or `N/A`).

### E) Test updates (tests themselves)

- [ ] SmartTests authored/updated (UI) **using fixtures** (import merged `test` from `fixtures/index.js`) -> These should be authored using a real playwright browser - refer writing smarttests guide.
- [ ] API tests authored/updated (if planned).
- [ ] Tests linked to scenarios **only when ids exist** (never invented).

### Dogfooding note (TestChimp testing TestChimp)

If the product-under-test is TestChimp itself (or you are testing a “planning UI” feature), do **not** treat repository `plans/` files as proof of runtime state.
Your tests must establish a **world-state posture** in the target project (seed a test project and create the required plan artifacts like event files via seed endpoints + fixtures), then validate the UI against that seeded state.

### F) Validate test runs (NON-NEGOTIABLE)

- [ ] UI tests executed with Playwright against a real browser (headed by default during triage). Note that this is an additional run (after the initial authoring run) to validate that the test that was authored can be run successfully - and gives the expected results. You may re-adjust the test and retry up to 2 attempts. If blocked - then raise the concerns to the user.
- [ ] API tests executed against real endpoints.
- [ ] Failing tests triaged and re-run until pass, or explicitly left failing with next steps.

---

## Phase 4: Validate (linkage + anomalies)

Goal: ensure the resulting test suite is correctly linked to requirements and can be trusted by TestChimp coverage/reporting.

### What to validate

1. **Scenario-link comment audit (required)**
   - For every SmartTest that should correspond to a scenario:
     - Confirm there is at least one `// @Scenario: #TS-<n> <Title>` comment INSIDE the test body.
2. **Anomaly handling (required)**
   - If a test is missing `// @Scenario:`:
     - Treat it as an anomaly.
     - Determine whether a relevant scenario already exists (from plans, or by querying TestChimp).
     - If it exists: add the comment.
     - If it does not exist: create the scenario via **MCP tools first** (fallback to CLI) and then add the comment using the real returned ID.
   - Never hallucinate `#TS-*` ids - only use ones returned by using create-test-scenario exposed by cli / mcp.

### Phase 4 completion gate (Validate → Cleanup)

Record in branch plan file:

- [ ] Scenario-link comment audit completed for all touched/new SmartTests.
- [ ] Any missing links remediated (scenario created if needed; comments added).
- [ ] Any remaining anomalies explicitly listed with next steps (only if blocked).

---

## Phase 5: Cleanup (environment teardown)

Goal: leave the developer machine / CI job in a clean state.

### What to cleanup

- **Local**: stop any local stack or dev servers started for this run (or record `N/A` if none were started).
- **Ephemeral/EaaS**: destroy any ephemeral environments provisioned for this branch (or record `N/A` if none were provisioned).

### Phase 5 completion gate (Cleanup → Done)

Record in branch plan file:

- [ ] Local processes/environments stopped (or `N/A` + reason).
- [ ] Ephemeral environments destroyed (or `N/A` + reason).

---

## Final report (always)

At the end, report:

- What plan items were completed vs blocked.
- What changed in system infra (seed/probe/TrueCoverage).
- What changed in test infra (fixtures/mocks).
- What tests were added/updated and their run results.
- Validate outcomes (scenario-link audit: pass/fail/anomalies fixed).
- Any cleanup done (local env stop, ephemeral env destroy, temp artifacts removed, generated artifacts not committed).

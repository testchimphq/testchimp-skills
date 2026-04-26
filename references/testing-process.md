# /testchimp test

This document defines the **strict workflow** for testing a PR with TestChimp.

`/testchimp test` MUST follow this flow in order:

1. **Analyze**
2. **Plan**
3. **Execute**
4. **Validate**
5. **Cleanup**

Use this as the primary reference for `/testchimp test`. For SmartTest authoring patterns and examples, load **[`write-smarttests.md`](./write-smarttests.md)** during the **Execute** phase. For **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`), **`testInfo`** scoping, and **probe** specs (`page.pause()`), load **[`fixture-usage.md`](./fixture-usage.md)**. For **test-only seed, teardown, and read** endpoints (discovery, proxy pattern, idempotency, post-UI assertions), load **[`seeding-endpoints.md`](./seeding-endpoints.md)**. For TrueCoverage rules (instrumentation, `plans/events/*.event.md`), load **[`truecoverage.md`](./truecoverage.md)** when RUM is in scope.

**Per-test planning:** In **Plan**, the agent must **list every test** it will write, then for **each** test define **Arrange / Act / Assert** with the nested subsections in [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase). In **Execute**, follow the [Batched order (Execute phase)](#batched-order-execute-phase) so seed/probe work is done **once** for the whole batch before fixtures and test authoring (avoiding unnecessary backend restarts per test).

### Phase gating (required)

Do **not** advance **Analyze → Plan → Execute → Validate → Cleanup** until the **prior phase’s completion gate** is satisfied. **Nothing implied; nothing skipped silently.**

- For **every** gate line item: mark **done**, **blocked**, or **`N/A`** with a **one-line justification**.
- Record gate outcomes in the **branch plan file** (`<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`) under a short **“Phase N completion”** subsection (or tick inline next to the plan checklist) so reruns are deterministic.

---

## Non-negotiables (agent guardrails for this flow)

Before running **any** Playwright command (headed or headless), or authoring **any** `ai-wright` steps, the agent MUST follow the flow below and satisfy the gates.

- **Plan first (no upfront smoke runs)**:
  - Do **not** start by “running a few smoke tests” or spinning up a local/ephemeral environment just to smoke the app.
  - Go through **Analyze → Plan** first so the plan can decide the required **stories/scenarios**, **the exact list of tests to author**, and any required **seed/teardown/read (probe) endpoints** and **fixtures**.
  - Only provision/start an environment in **Execute** (after the plan makes infra needs explicit—and **seed/probe endpoint implementations are done all done** per [Batched order (Execute phase)](#batched-order-execute-phase), so the backend is not restarted needlessly after each test).
- **Test list in Plan (REQUIRED)**:
  - The Plan MUST include an explicit **enumerated list of tests** to be written (e.g. one bullet or table row per SmartTest/API test, with a working title and mapping intent to scenarios).
- **Per-test Arrange / Act / Assert (REQUIRED)**:
  - For **each** test in that list, the Plan MUST use the full structure in [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase). **Arrange** is prerequisite **world state**; **Act** is what the test does; **Assert** splits **UI validations** and **backend validations** (with probe endpoints when backend state must be read).
- **Plan structure guard (REQUIRED)**:
  - Before asking for user approval, the agent MUST **self-check every proposed test**: the Arrange / Act / Assert structure is **strictly** followed, and **each section is either complete** (plain-English, actionable content) **or explicitly marked** as requiring **user input** (with what is missing). When the user later supplies data, those sections MUST be **updated** in the branch plan (no silent gaps).
- **Persist and reuse a per-branch Plan artifact (REQUIRED)**:
  - **Always** create/update the **current branch** plan at:
    - `<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`
  - **Before planning**, **check for the existence** of that file:
    - If it exists, **read it first**, then update it based on (a) what’s already planned/done, (b) current PR diffs and plan materials, and (c) any additional user context for *this* run.
    - If it does not exist, create it and do the full Plan phase (see Phase 1).
  - The plan file must have YAML frontmatter containing:
    - `LastRunOnCommit: <commit_sha>` (commit at which this branch plan was last updated by `/testchimp test`)
  - The plan body must contain a **checklist** of action items, where each item is explicitly marked **done** (`- [x]`) or **not done** (`- [ ]`), so reruns are deterministic.
- **Get explicit agreement on the Plan**: the agent MUST pause after writing/updating the branch plan and wait for user approval before running Setup/Execute work.
- **Backend posture first (no assumptions; world-state driven)** (aligns with **Arrange**):
  - For each planned test, **Arrange** must define the **required world state** as if the environment is **empty** other than what the selected fixtures will establish.
  - If posture requires data that cannot be created with existing fixtures, the Plan MUST prefer this chain and list the missing pieces as Execute blockers:
    1) **Reuse existing fixtures** (`<tests_root>/fixtures/`) by adding the fixture dependency to the test signature.
    2) **Create/update fixtures** (per-test, retry-safe; `testInfo` scoped) that call seed/probe endpoints (see [`references/fixture-usage.md`](./fixture-usage.md)).
    3) **Create/update seed/probe/teardown endpoints** to support the fixture; document under **Arrange → Fixtures plan → Seed endpoint updates** and batch-implement in Execute per [Batched order (Execute phase)](#batched-order-execute-phase).
  - If seed/probe endpoints or fixtures are missing, that is a **Plan output** and a **hard Execute blocker** until addressed in Execute.
- **Environment strategy is binding**:
  - The agent MUST follow `plans/knowledge/ai-test-instructions.md` for environment provisioning (local vs ephemeral) and the “up + healthy” contract.
  - After seed/probe/backend changes, the agent MUST ensure the running environment actually includes those changes (restart/reprovision **after** batched endpoint work—see [Batched order (Execute phase)](#batched-order-execute-phase)).
  - **PR-scoped env requirement (critical)**:
    - If the branch/PR includes **backend changes** (business logic, seed/probe endpoints, auth changes, or anything the tests depend on), the agent MUST run validation against a **PR-scoped environment** that includes the updated code. This may be:
      - **Local** stack built from the current branch, or
      - **Ephemeral/EaaS** environment provisioned from the branch.
    - Follow the repo’s environment contract in `plans/knowledge/ai-test-instructions.md` (local vs ephemeral/EaaS, “up + healthy” criteria, restart/reprovision rules).
    - **Super critical:** If you run tests against an existing stable environment that does **not** include the PR’s backend changes, you are **not testing the change**.
    - Do **not** validate backend changes against a stable/staging backend unless you have verified those specific changes are already deployed there. Typically, `.env-` files in tests folder will contain `BASE_URL` that points to such stable environments. If you are using them - you MUST ensure that the changes are present in that env - by confirming with the user. Default approach should be consulting the ai-test-instructions file and see how to spin up environments to test.
- **TrueCoverage belongs in the Plan**:
  - If the PR adds or changes **user journeys / user-facing behaviors**, the Plan must explicitly decide whether to instrument.
  - If TrueCoverage is **not configured yet** and there is **no explicit opt-out** recorded in `plans/knowledge/ai-test-instructions.md`, the agent must **ask the user** whether to enable it for this repo and include **RUM wiring + event docs** work in the Plan when the user agrees.
  - If TrueCoverage **is already configured**, the agent should **consider** whether there are **key user events** worth instrumenting for the changed behavior, and include them (with `plans/events/*.event.md` updates) when appropriate.
- **Mocking belongs in the Plan (always)**:
  - Explicitly decide per test case: **real backend**, **Playwright HTTP mocking** (`page.route` / `context.route`), and (when applicable) **AIMock** for LLM-backed flows.
  - If AIMock is selected, the Plan must include: wiring tasks, enablement mechanism (env flag / config), and how to validate it is actually being used.
- **Fixtures belong in the Plan (always; favor reuse)** (lives under **Arrange → Fixtures plan** for each test):
  - For every planned UI SmartTest, the Plan MUST name the **exact fixture dependencies** (what you will add to the test signature) that establish the posture.
  - The agent MUST **search existing fixtures first** and strongly prefer reuse over creating new fixture modules.
  - If reuse is impossible, the Plan MUST specify: new/extended **fixtures**, **seed/probe** needs, and how the fixture proves posture (see **Assert → Backend validations** when probes are required).
  - If new fixtures/endpoints are needed, treat them as **Execute blockers** (not “nice-to-haves”).
- **Batched Execute order (REQUIRED)**:
  - During **Execute**, follow [Batched order (Execute phase)](#batched-order-execute-phase): implement **all** seed endpoint updates for **all** planned tests, then **all** probe endpoint updates, then **(re)start the backend** if any endpoints changed, then **all** fixtures, **then** author tests, UI actions, and assertions per the Plan.
- **Re-run is mandatory**:
  - Any new/changed automated test MUST be executed with the real runner (UI: Playwright + browser; API: real HTTP execution) and re-run after fixes until it passes, or is explicitly recorded as failing with next steps. No “assumed pass”.
- **Scenario-link comments (required; keep existing platform workflow)**:
  - The existing flow—create/update **user stories** and **test scenarios** via MCP/CLI after plan approval, with **real** `#TS-…` / `#US-…` ids—is **unchanged** and still required.
  - Every SmartTest that represents a scenario MUST include one or more `// @Scenario: #TS-<n> <Title>` comments **as the first statement(s) in the test body** (see `SKILL.md` guardrails).
  - **Execution-time rule:** when **authoring** each test (per [Batched order (Execute phase)](#batched-order-execute-phase)), add the **scenario link comment** to the test after the corresponding platform ids exist, consistent with the Plan’s story/scenario list.
- **Validation failure triage (REQUIRED):** see [Validation failure triage](#validation-failure-triage).
- **Cleanup is mandatory**:
  - Any environment created or started during Execute (local stack, dev server, ephemeral/EaaS env) MUST be torn down in Cleanup, and the plan must record what was stopped/destroyed (or `N/A` with reason).
- **Blockers must be called out in the Plan**: list every known blocker with (a) owner (agent vs user), (b) the exact action required, and (c) the earliest phase it blocks.

### Validation failure triage

When **UI** or **backend** validations fail (during Execute or when re-running tests), the agent MUST reason whether the failure is a **bug in the system under test** or a **defect in the test** (wrong steps, incomplete Arrange, wrong expectation, unstable locator, incorrect probe).

- **If it is a system bug:** change the **application implementation** so it meets the correct expected behavior; keep the test aligned with the **intended** product behavior.
- **If it is a test bug:** change the **test** (or fixtures, seed data, or probe expectations)—do not “fix” production code to match a bad test.

---

## Required structure for each proposed test (Plan phase)

The branch plan MUST contain a subsection **per test** (SmartTest and/or API test), using this template. **Do not omit** headings; use **`TBD (needs user: …)`** when a section is incomplete.

### Tests to write (inventory)

First, a short **numbered list of all tests** to be authored in this run (titles only; maps to the subsections below).

For **each** test, include:

### Arrange

Describe the **world state** in which the test will run: prerequisite entities and the **state they must be in** before any UI/API actions (e.g. “a signed-in user whose saved payment method is an **expired** card”).

- This is a **plain-English** description of what must exist and how it should be set up—**not** the implementation yet.

#### Fixtures plan

**How** that world state will be materialized for automation:

- **Existing fixtures to use** (names/paths; what each contributes).
- **New or updated fixtures** (what to add, and why).
- Reuse-first: prefer extending existing `mergeTests` / fixture modules over duplicating setup.

#### Seed endpoint updates

Include **only** when new or updated fixtures require **new or changed** seed (or test-only data) **APIs** on the app-under-test:

- List each **seed endpoint** to **create** or **update** so fixtures can build the required posture.
- If no seed work is required (fixtures only compose existing data), state **`N/A`** with one line.

### Act

Plain-English list of **actions** the test will perform (user journey, API calls, navigation)—the **test steps** as the user or client would do them, in order. This is what Playwright (or an API client) will automate.

### Assert

#### UI validations

Plain-English: what the test will **verify in the browser** (visible text, navigation outcome, error banners, disabled buttons, etc.).

#### Backend validations

Plain-English: the **expected backend state** after the act phase (e.g. order in **accepted** state, event enqueued, DB row). Include:

- What should be true in persistence, queues, or domain state.
- **Probe / read endpoints:** when state cannot be inferred from the UI, specify **test-only read/probe** HTTP endpoints that return the data the test will assert (DB snapshots, queue depth, record lookups). If new probe endpoints are needed, list them here; implement them in the batched **probe** step in [Batched order (Execute phase)](#batched-order-execute-phase).
- If only UI-level checks are sufficient for a given test, state that backend checks are **`N/A`** with rationale.

### Plan structure guard (before user approval)

For **each** test in the inventory:

- [ ] **Arrange** has a clear world-state description.
- [ ] **Fixtures plan** names existing + new/updated fixtures (or `N/A` with justification if no Playwright fixture is used—rare for UI tests).
- [ ] **Seed endpoint updates** is complete or `N/A` (with no hidden missing seeds).
- [ ] **Act** lists concrete steps in order.
- [ ] **Assert** has both **UI validations** and **Backend validations** subsections; each is complete **or** explicitly **`TBD (needs user: …)`** / blocked.

---

## Batched order (Execute phase)

After the user approves the Plan, during **Execute** implement work in this order **across all tests** in the plan (so the backend is not cycled for every test):

1. **Seed endpoint updates (implementation)**  
   Add or change **all** seed-related routes/handlers required by **any** test’s **Arrange → Seed endpoint updates**.

2. **Probe endpoint updates (implementation)**  
   Add or change **all** test-only **read/probe** endpoints required by **any** test’s **Assert → Backend validations** (and any read helpers fixtures need).

3. **(Re)start or reprovision the backend**  
   If **any** seed or probe endpoint (or other backend test-only code) was added or changed, bring up the app-under-test **once** with those changes loaded (per `ai-test-instructions.md`). **Do not** start the stack before step 1–2 if those steps had work—avoid stale code.

4. **Fixture implementation**  
   Create or update **all** Playwright fixtures (and related helpers) needed so each test can obtain the **Arrange** world state.

5. **Test authoring (per test; follow the plan)**  
   For each test, in spec code:

   - Use the **fixtures** identified in that test’s **Fixtures plan** so the browser (or client) starts from the right posture.
   - Add **`// @Scenario: #TS-…`** link comment(s) per existing workflow (stories/scenarios created in **Execute** after approval; use **real** ids from MCP/CLI).
   - Implement **Act** (UI or API steps).
   - Implement **Assert**: **UI validations** plus **probe-based API checks** as planned.

6. **Run and triage**  
   Execute the real runner. On failure, apply [Validation failure triage](#validation-failure-triage) (system bug → fix product; test bug → fix test).

**Relationship to phases below:** The checklist subsections in **Phase 3: Execute** follow this order. **Phase 4: Validate** remains for **scenario-link audit** and any cross-cutting anomalies; it does not replace per-test assertions in step 5–6.

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
- **Candidate tests and posture (high level; no implementation yet)**
  - A preliminary list of **which tests** might be needed and rough **Arrange** sketches; full **Arrange/Act/Assert** is written in Plan.
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

The Plan MUST be written under the branch plan file. It MUST include the following **top-level** sections (in order), **and** the [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase) for every listed test.

1. **Test plan updates** (plans layer)
   - Stories/scenarios to create/update.
     - **Never invent IDs** means: never assume fake `#US-...` / `#TS-...` ids.
     - If scenarios / stories are missing for the PR changes, the Plan must explicitly list the **new** stories/scenarios to be created so the platform generates **real IDs**.
     - **Timing rule**: the actual `create-user-story` / `create-test-scenario` calls (and subsequent `update-user-story` and `update-test-scenario`) must be performed **only in Execute**, **after** the user approves the Plan generated.
2. **Tests to write (inventory) + per-test Arrange / Act / Assert**
   - Use **[Tests to write (inventory)](#tests-to-write-inventory)** and, for each test, the full template under [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase).
   - **Cross-link:** The older **“Posture table”** (prerequisite entities, fixture deps, seed/probe, mocks, post-UI assertions) is **subsumed** by **Arrange** (world state + fixtures + seed updates) and **Assert** (UI + backend + probes). Mocks, if any, can be noted under **Arrange** (e.g. “HTTP mock for payment provider”) or in a short **Notes** line under that test.
3. **System infra updates** (product/backend) — *summary / deduplication layer*
   - A consolidated list of all **seed** and **probe** endpoint work (may duplicate what each test’s **Seed endpoint updates** and **Backend validations** already state—intentional for a single “build list”).
   - Teardown routes if needed.
   - TrueCoverage instrumentation changes (events/metadata + docs) when in scope.
4. **Test infra updates** (tests harness) — *summary*
   - Consolidated fixture/mock work (details remain per test under **Arrange → Fixtures plan**).
5. **Meta**
   - **Explicit user approval** checkpoint (the agent must stop here until approved). Include user approval status as a frontmatter field and update it once the user consents to proceed.
   - Run the [Plan structure guard (before user approval)](#plan-structure-guard-before-user-approval) for every test; record pass/fail or `TBD` items.
   - An **Execute checklist** that mirrors [Batched order (Execute phase)](#batched-order-execute-phase) plus environment bring-up, test runs, and triage.
   - A **Validate checklist** (Phase 4): scenario-link comment audit + remediation.
   - A **Cleanup checklist**: local env/process teardown and/or ephemeral environment destroy, aligned to the environment strategy used.

The Plan MUST also include:

- **Blockers** (if any) per non-negotiables.

### Phase 2 completion gate (Plan → Execute)

Before proceeding to **Execute**, the agent must record **done/blocked/`N/A`** for each (in the branch plan file):

- [ ] Plan includes **Tests to write (inventory)** and **per-test** Arrange / Act / Assert for **each** test.
- [ ] [Plan structure guard (before user approval)](#plan-structure-guard-before-user-approval) satisfied for every test (or only `TBD` with explicit user-input labels—**not** silent blanks).
- [ ] Stories/scenarios to create (no fake ids) and timing rule clear.
- [ ] System infra and test infra summaries align with the per-test subsections.
- [ ] Environment strategy chosen per `plans/knowledge/ai-test-instructions.md`.
- [ ] User explicitly approved the plan to proceed.

---

## Phase 3: Execute (do the plan)

Preamble before execution: Verify that the plan doc created above is present. Verify that it indicates the user has approved. If not—**PAUSE** and do **not** continue.

Goal: execute the approved plan in **[Batched order (Execute phase)](#batched-order-execute-phase)**, and keep the plan checklists updated so reruns are deterministic.

During Execute, the agent MUST maintain a checklist in the branch plan file and mark each line as **done / blocked / N/A**.

### 1) Seed endpoint updates (all tests)

- [ ] All seed endpoints from the Plan (per-test **Arrange → Seed endpoint updates** + consolidated list) are **implemented** in the product/backend code.

### 2) Probe endpoint updates (all tests)

- [ ] All probe/read endpoints from **Assert → Backend validations** (and any fixture read helpers) are **implemented**.

### 3) Environment: load new backend code (if 1 or 2 had changes)

- [ ] If **any** seed or probe (or related test-only) backend code was added or changed: environment is **(re)started or reprovisioned** so the running stack includes that code (per `ai-test-instructions.md`).
- [ ] If no backend endpoint changes in 1–2: record **`N/A`** (no restart solely for this reason).

### 4) Test plan updates (stories/scenarios on platform) — *after code is in place for seeds/probes or in parallel if independent*

- [ ] Create/update stories as planned (via CLI/MCP), per timing rule.
- [ ] Create/update scenarios as planned (via CLI/MCP); obtain **real** ids for `// @Scenario:` comments.

### 5) Fixtures (all tests)

- [ ] Create/update **all** fixtures and helpers so each test’s **Arrange** posture is reachable.

### 6) Tests (authoring + validations)

- [ ] For **each** planned test: author SmartTest (and/or API test) using the named **fixtures**; add **`// @Scenario:`** with real ids; implement **Act**; implement **Assert** (UI + probe API calls as planned).
- [ ] **Never** invent scenario ids; only use ids from the platform.
- [ ] Re-run the real Playwright (or API) runner until pass or explicit failure with next steps.

### 7) Dogfooding note (TestChimp testing TestChimp)

If the product-under-test is TestChimp itself (or you are testing a “planning UI” feature), do **not** treat repository `plans/` files as proof of runtime state.
Your tests must establish a **world-state posture** in the target project (seed a test project and create the required plan artifacts like event files via seed endpoints + fixtures), then validate the UI against that seeded state.

### 8) Triage (ongoing)

- [ ] On red runs: apply **system bug vs test bug** reasoning; fix the correct layer; re-run.

---

## Phase 4: Validate (linkage + anomalies)

Goal: ensure the resulting test suite is correctly linked to requirements and can be trusted by TestChimp coverage/reporting. Per-test **Act/Assert** validation already happened in **Execute**; this phase closes **gaps in scenario linkage** only.

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

# /testchimp test

This document defines the **strict workflow** for testing a PR with TestChimp.

`/testchimp test` MUST follow this flow in order:

1. **Analyze**
2. **Plan**
3. **Execute**

Use this as the primary reference for `/testchimp test`. For SmartTest authoring patterns and examples, load **[`write-smarttests.md`](./write-smarttests.md)** during the **Execute** phase. For **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`), **`testInfo`** scoping, and **probe** specs (`page.pause()`), load **[`fixture-usage.md`](./fixture-usage.md)**. For **test-only seed, teardown, and read** endpoints (discovery, proxy pattern, idempotency, post-UI assertions), load **[`seeding-endpoints.md`](./seeding-endpoints.md)**. For TrueCoverage rules (instrumentation, `plans/events/*.event.md`), load **[`truecoverage.md`](./truecoverage.md)** when RUM is in scope.

### Phase gating (required)

Do **not** advance **Analyze → Plan → Execute** until the **prior phase’s completion gate** is satisfied. **Nothing implied; nothing skipped silently.**

- For **every** gate line item: mark **done**, **blocked**, or **`N/A`** with a **one-line justification**.
- Record gate outcomes in the **branch plan file** (`<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`) under a short **“Phase N completion”** subsection (or tick inline next to the plan checklist) so reruns are deterministic.

---

## Non-negotiables (agent guardrails for this flow)

Before running **any** Playwright command (headed or headless), or authoring **any** `ai-wright` steps, the agent MUST follow the flow below and satisfy the gates.

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
- **Backend posture first (no assumptions)**:
  - For each test, the agent MUST explicitly define the **required backend state** (“posture”) and the assertions that prove it.
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
- **Fixtures belong in the Plan (always)**:
  - For every UI SmartTest planned, list the required **fixture-backed posture** and any missing `fixtures/` modules or missing seed/read/teardown endpoints.
  - If new fixtures/endpoints are needed, treat them as **Execute blockers** (not “nice-to-haves”).
- **Re-run is mandatory**:
  - Any new/changed automated test MUST be executed with the real runner (UI: Playwright + browser; API: real HTTP execution) and re-run after fixes until it passes, or is explicitly recorded as failing with next steps. No “assumed pass”.
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
     - **Timing rule**: the actual `create-user-story` / `create-test-scenario` calls must be performed **only in Execute**, **after** the user approves the Plan generated.
2. **System infra updates** (product/backend)
   - Seed/teardown/read (probe) endpoints to add/update to setup the world-state required for the tests to be done, and assertions to be made.
   - TrueCoverage instrumentation changes (events/metadata + docs) when in scope.
3. **Test infra updates** (tests harness)
   - Fixtures to create/update to enforce the posture using seed/probe endpoints.
   - Mocking strategy decisions and helpers (when applicable).
4. **Test updates** (tests themselves)
   - SmartTests (UI) and/or API tests to add/update, each mapped to a scenario when an id exists.

The Plan MUST also include:

- **Explicit user approval** checkpoint (the agent must stop here until approved). Include user approval status as a frontmatter field and update it once the user gives you consent to proceed.
- An **Execute checklist** that mirrors the four buckets above plus “validate test runs”, where each line is marked **done / blocked / N/A**.

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

## Final report (always)

At the end, report:

- What plan items were completed vs blocked.
- What changed in system infra (seed/probe/TrueCoverage).
- What changed in test infra (fixtures/mocks).
- What tests were added/updated and their run results.
- Any cleanup done (ephemeral env destroy, temp artifacts removed, generated artifacts not committed).

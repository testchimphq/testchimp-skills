# /testchimp run QA

**Synonym:** `/testchimp test` (same workflow **`run-qa`** — use either prompt).

This document defines the **strict workflow** for Run QA with TestChimp (typically on a PR / feature branch).

> **Workflow overlay (skill ≥ 1.0.0)** — **Workflow id:** `run-qa` (canonical prompt **`/testchimp run QA`**; synonym **`/testchimp test`**). **Policy:** `plans/knowledge/policies/run-qa.policy.md` (or `--policy` / matching frontmatter; fallback `ai-test-instructions.md`). Default subflow order includes **`run-smart-regression`** after create-tests (see [`assets/policies/run-qa.policy.md`](../assets/policies/run-qa.policy.md)). Persist a **ULID** `workflow_execution_id` on the branch plan **before Execute**; on mutating actions call **`report-agent-action`** (best-effort) with that same id. **Before treating the run as done:** [Report workflow execution](./policies-and-traceability.md#report-workflow-execution) (reconcile ledger → emit missing reports → `ACTION_COMPLETED` with `WORKFLOW` + `run-qa`). Details: [`policies-and-traceability.md`](./policies-and-traceability.md). Full Smart regression playbook: [`run-smart-regression.md`](./run-smart-regression.md) (Phase 5 below remains authoritative if an agent only reads this file).

> **create-tests / nested under run-qa:** When the user asked only **`/testchimp create tests`** or this playbook is reached as a **subflow of run-qa / upkeep**, do **not** start a second Plan → approve → Execute cycle. Use the parent plan’s scope and `workflow_execution_id`; run the **Execute** authorship steps for tests only (skip a nested Analyze/Plan gate and skip later run-qa-only phases unless the parent plan called for them). Standalone **`/testchimp run QA`** (or synonym **`/testchimp test`**) still follows the full phase chain below.

## Primary outcome: automated tests (not manual QA)

The objective of **`/testchimp run QA`** (synonym **`/testchimp test`**) is to **produce and run automated coverage**: **API tests** and **UI SmartTests** (Playwright on web; **Mobilewright** on native mobile when **`project_type`** is **`mobile`**, **`multi-platform`**, or legacy **`ios`/`android`**), with fixtures, seeds, and probes as needed. **Strongly prefer** shipping executable specs over delegating verification to humans.

**Project type:** After locating the SmartTests root (**`.testchimp-tests`**), read that file. **Empty or missing `project_type`** → **`web`**. **`project_type=mobile`** or legacy **`ios`/`android`** → **mobile** (unified `mobilewright.config.ts`, `mobile/e2e/{common,ios,android}/`, `api/`). **`project_type=multi-platform`** → **both** configs + `web/` + `mobile/` + shared `api/`. **Authoring paths, fixture barrels, and `shared/` helpers:** [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) (required for Plan/Execute). **Mobile UI:** [`mobilewright-smarttests.md`](./mobilewright-smarttests.md) — **`screen`** / **`device`**, **no** ai-wright. **Fixtures:** [`fixture-usage.md`](./fixture-usage.md).

**Platform scope (mobile & multi-platform, PR branch):** Before **Plan** approval, resolve which of **`web`**, **`ios`**, and **`android`** this run covers. **Inform** the user when deduction is confident; **ask** when ambiguous. Persist **`## Platform scope (this run)`** on the branch plan and require **User confirmed: yes** before **Execute**. See [`platform-scope.md`](./platform-scope.md).

## “Run tests” / CI green vs `/testchimp run QA`

- **“Run tests” / CI green** (colloquial or CI-only checks) means at minimum **Phase 4: Validate** is **green** for the relevant automated specs: real runner, scenario links, and agreed validation bar met.
- **`/testchimp run QA`** (synonym **`/testchimp test`**) means this document’s **full phase chain** through **Phase 5 (Smart regression)**, then **Phase 6 (ExploreChimp)** whenever the PR/branch plan scope includes **new or materially changed UI SmartTests** (specs that drive real UI and use **`markScreenState`** or will once stable—especially when new screen-states are introduced), unless the branch plan records **`N/A`** with a **one-line rationale** under **Phase 2, section 7** (same user approval window as the rest of the plan). **`N/A`** is the **exception** (e.g. API-only change, no UI journey, user declined cost)—not the default. **`/testchimp explore`** remains the path when exploration is the **primary** task; Phase 6 reuses the same playbook after Smart regression.

- **Recommend manual testing only as a last resort**—when automation is genuinely blocked after documented attempts (e.g. missing credentials the user must supply, hardware-only flows, legal restriction), and the branch plan must state **why** automation was not completed and what remains.
- Do **not** substitute “user should click through X” for missing SmartTests/API tests when the stack and requirements support automation.

## Arrange, Act, Assert: universal shape for every test

**Every** automated test you add or extend—**UI SmartTest** (Playwright) or **API test**—follows **Arrange → Act → Assert** (same order, same meaning):

| Phase | Meaning | What the Plan must capture |
|--------|---------|----------------------------|
| **Arrange** | **World state before the first meaningful step** | What entities, relationships, flags, auth, and external posture must be true *before* **Act** runs. This is where you choose **strategy** (fixtures, seeds, mocks, clock)—not implementation yet. |
| **Act** | **The behavior under test** | Ordered **steps** the user or client performs (navigation, clicks, form fills, API calls). This is the **stimulus** you will automate. |
| **Assert** | **Expected outcomes after Act** | **UI**: what must be visible or absent on screen. **Backend / system**: persisted or async truth the UI might not show—via **probe/read** endpoints when needed. |

**Why the Plan forces three headings per test:** Vague plans skip straight to “write a test” and then discover missing data or no way to verify the backend. Requiring **Arrange**, **Act**, and **Assert** as separate written sections **forces** you to (1) define posture clearly enough for a **fixture / seed audit** to run, (2) bound scope so **Act** is not a grab bag, and (3) decide **how** you will prove success (**DOM-only vs probes**). **Execute** then follows **[Batched order (Execute phase)](#batched-order-execute-phase)**: implement support for **Arrange** (seeds + fixtures) and **Assert** (probes) before coding **Act** in the spec.

**Naming in the branch plan:** Use the exact headings **`### Arrange`**, **`### Act`**, **`### Assert`** under each test (see [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase)). Do not collapse Arrange into Act or hide assertions inside Act prose.

`/testchimp run QA` (synonym `/testchimp test`) MUST follow this flow in order:

1. **Analyze**
2. **Plan**
3. **Execute**
4. **Validate**
5. **Smart regression** — [Phase 5](#phase-5-smart-regression-check): run linked specs for **likely affected** scenarios (from `plans/` + PR); fix regressions in existing tests when needed.
6. **ExploreChimp** — [Phase 6](#phase-6-explorechimp): **default-on** for UI SmartTest deltas once **Phase 5** is green; branch plan **`yes`** or documented **`N/A`** ([Phase 2 §7](#7-explorechimp-branch-plan-yes-or-documented-na)). Run on **new + materially changed + regression-touched** UI specs (see Phase 6).
7. **Cleanup** (see [Phase 7: Cleanup](#phase-7-cleanup-environment-teardown))

Use this as the primary reference for `/testchimp run QA` (synonym `/testchimp test`). During **Plan** and **Execute**, load **[`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)** first so every proposed test names its **folder**, **fixture barrel**, and **runner**. For SmartTest authoring patterns, load **[`write-smarttests.md`](./write-smarttests.md)**; for **mobile** UI, **[`mobilewright-smarttests.md`](./mobilewright-smarttests.md)**. For **fixtures** (`mergeTests`, `api/fixtures`, `mobile/fixtures`, `web/fixtures`, `shared/` helpers), load **[`fixture-usage.md`](./fixture-usage.md)**. For **test-only seed, teardown, and read** endpoints (discovery, proxy pattern, idempotency, post-UI assertions), load **[`seeding-endpoints.md`](./seeding-endpoints.md)**. For TrueCoverage rules (instrumentation, `plans/events/*.event.md`), load **[`instrument-truecoverage.md`](./instrument-truecoverage.md)** when RUM is in scope. For **ExploreChimp** (UX analytics on UI test pathways), load **[`run-explorechimp.md`](./run-explorechimp.md)** for env vars, operator checklist, and execution details once **Phase 2 §7** is **`yes`** (or when running **`/testchimp explore`**). **Environment:** follow **[Binding: ai-test-instructions (environment and FAQ playbook)](#binding-ai-test-instructions-environment-and-faq-playbook)** below; [`environment-management.md`](./environment-management.md) supplements that file but does **not** override it.

**Per-test planning:** In **Plan**, the agent must **list every test**, then for **each** test write **Arrange → Act → Assert** using the template in [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase)—see [Arrange, Act, Assert: universal shape for every test](#arrange-act-assert-universal-shape-for-every-test). In **Execute**, follow [Batched order (Execute phase)](#batched-order-execute-phase) so Arrange-supporting seeds and Assert-supporting probes land **once** per batch before fixtures and test code.

### Phase gating (required)

Do **not** advance **Analyze → Plan → Execute → Validate → Phase 5 (Smart regression) → Phase 6 (ExploreChimp) → Phase 7 (Cleanup)** until the **prior phase’s completion gate** is satisfied. **Nothing implied; nothing skipped silently.**

- For **every** gate line item: mark **done**, **blocked**, or **`N/A`** with a **one-line justification**.
- Record gate outcomes in the **branch plan file** (`<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`) under a short **“Phase N completion”** subsection (or tick inline next to the plan checklist) so reruns are deterministic.

---

## Non-negotiables (agent guardrails for this flow)

Before running **any** Playwright / Mobilewright test command (headed or headless), or authoring **any** `ai-wright` steps (**web only**), the agent MUST follow the flow below and satisfy the gates.

- **`TESTCHIMP_API_KEY` (P0 — required on the runner process):** Any command that runs Playwright/Mobilewright with **`@testchimp/playwright`** must execute with **`TESTCHIMP_API_KEY`** set in **that process’s environment** (Execute, Validate, Phase 5, Phase 6, CI). **IDE/MCP-only** config does **not** satisfy the runner. **Resolution order:** SmartTests-root walk-up → host MCP config → read **`mcpServers.*.env.TESTCHIMP_API_KEY`** (never print) → **export** or **inject** into the shell / CI **`env:`** / wrapper used to spawn tests. If missing, blank, or placeholder, **STOP** with a blocker + fix steps (including: if only MCP was updated, reload MCP **and** ensure the **next** runner spawn inherits the key). **Reporter disabled**, **401**, and “missing key” logs → **same** remediation. If the agent **cannot verify** the key is on the test process env **before** spawning the runner, **halt** — do **not** run tests speculatively. See **`SKILL.md`** Preamble **#4** and [`run-explorechimp.md`](./run-explorechimp.md).

- **Runner / config:** Use the config and `--project` from [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) (`playwright.config.js` vs `mobilewright.config.ts`, `web` / `api` / `ios` / `android`). Mobile UI projects need **`projects[].use.platform`** (`ios` | `android`) for `@testchimp/playwright` TrueCoverage ([`instrument-truecoverage.md`](./instrument-truecoverage.md)).

- **Hard prerequisite before Analyze/Plan (decision memory):**
  - Before starting **Analyze** or drafting the branch plan, read `plans/knowledge/ai-test-instructions.md` and extract pre-agreed environment decisions from **`## Environment Provision Strategy`** (for example local spin-up vs Bunnyshell/EaaS vs staging/branch environment path, URL resolution, and health gates).
  - The Plan must reflect and preserve those decisions. Do not defer this read until Execute.

- **Plan first (no upfront smoke runs)**:
  - Do **not** start by “running a few smoke tests” or spinning up a local/ephemeral environment just to smoke the app.
  - Go through **Analyze → Plan** first so the plan can decide the required **stories/scenarios**, **the exact list of tests to author**, and any required **seed/teardown/read (probe) endpoints** and **fixtures**.
  - Only provision/start an environment in **Execute** (after the plan makes infra needs explicit—and **seed/probe endpoint implementations are all done** per [Batched order (Execute phase)](#batched-order-execute-phase), so the backend is not restarted needlessly after each test).
- **Test list in Plan (REQUIRED)**:
  - The Plan MUST include an explicit **enumerated list of tests** to be written (e.g. one bullet or table row per SmartTest/API test, with a working title and mapping intent to scenarios).
- **Per-test Arrange → Act → Assert (REQUIRED)**:
  - For **each** test in the inventory, the Plan MUST use the full structure in [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase): three top-level sections **in order**—**Arrange** (world state + fixtures plan + seed endpoint updates), **Act** (ordered steps under test), **Assert** (UI validations + backend validations / probes). This is the **same** AAA shape every spec will follow; the Plan is invalid without all three.
  - **Purpose check:** **Arrange** must be rich enough that [World-state → seed/fixture traceability](#world-state--seedfixture-traceability-required) can map every prerequisite to an existing fixture/seed or to **new** work. **Act** must list **concrete** steps (no “exercise the feature”). **Assert** must state **both** UI expectations and whether **backend/probe** checks are required (`N/A` only with rationale).
- **Plan structure guard (REQUIRED)**:
  - Before asking for user approval, the agent MUST **self-check every proposed test**: **Arrange → Act → Assert** headings are present **in that order**, nested subsections (**Fixtures plan**, **Seed endpoint updates**, **UI validations**, **Backend validations**) are filled or honestly **`TBD`**, and **each section is either complete** (plain-English, actionable) **or explicitly marked** as requiring **user input** (with what is missing). When the user later supplies data, those sections MUST be **updated** in the branch plan (no silent gaps).
- **Persist and reuse a per-branch Plan artifact (REQUIRED)**:
  - **Always** create/update the **current branch** plan at:
    - `<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`
  - **Before planning**, **check for the existence** of that file:
    - If it exists, **read it first**, then update it based on (a) what’s already planned/done, (b) current PR diffs and plan materials, and (c) any additional user context for *this* run.
    - If it does not exist, create it and do the full Plan phase (see Phase 1).
  - The plan file must have YAML frontmatter containing:
    - `LastRunOnCommit: <commit_sha>` (commit at which this branch plan was last updated by `/testchimp run QA`)
  - The plan body must contain a **checklist** of action items, where each item is explicitly marked **done** (`- [x]`) or **not done** (`- [ ]`), so reruns are deterministic.
- **Get explicit agreement on the Plan**: the agent MUST pause after writing/updating the branch plan and wait for user approval before running Setup/Execute work.
- **Arrange drives infra (no assumptions; world-state first)**:
  - For each planned test, **Arrange** must define the **required world state** as if the environment is **empty** other than what the selected fixtures will establish—that definition is what the **fixture / seed audit** consumes to find gaps.
  - If posture requires data that cannot be created with existing fixtures, the Plan MUST prefer this chain and list the missing pieces as Execute blockers:
    1) **Reuse existing fixtures** (`<tests_root>/fixtures/`) by adding the fixture dependency to the test signature.
    2) **Create/update fixtures** (per-test, retry-safe; `testInfo` scoped) that call seed/probe endpoints (see [`references/fixture-usage.md`](./fixture-usage.md)).
    3) **Create/update seed/probe/teardown endpoints** to support the fixture; document under **Arrange → Fixtures plan → Seed endpoint updates** and batch-implement in Execute per [Batched order (Execute phase)](#batched-order-execute-phase).
  - If seed/probe endpoints or fixtures are missing, that is a **Plan output** and a **hard Execute blocker** until addressed in Execute.
- **Environment and provisioning:** non‑negotiable rules live under **[Binding: ai-test-instructions (environment and FAQ playbook)](#binding-ai-test-instructions-environment-and-faq-playbook)**—read that subsection before **Execute** and whenever provisioning or validation misbehaves.
- **Environment before test authoring (strict):**
  - In both first-pass execution and reruns, confirm environment provisioning and target URL decisions from `ai-test-instructions.md` **before authoring or executing tests** (including fixture-driven test setup). Tests are authored by executing real steps, so environment provisioning must be settled first.
- **TrueCoverage belongs in the Plan** (default **opted-in** per [`instrument-truecoverage.md`](./instrument-truecoverage.md)) **for web and native mobile** when the PR touches user-facing journeys:
  - **Web:** `@testchimp/rum-js` in the app bundle, `installTestChimp` on **`fixtures/`** or **`web/fixtures/`**, `plans/events/`, etc.
  - **Mobile native** (**`project_type=mobile`** or legacy **`ios`/`android`**): native RUM SDK ([`instrument-truecoverage.md`](./instrument-truecoverage.md)), URL scheme / intent filter + SDK handlers, `installTestChimp` on **`mobile/fixtures/index.js`** with `{ uiFixture: 'screen' }`, Mobilewright **`device`** for automation URLs—same opt-in / opt-out policy via **`### TrueCoverage Plan`**.
  - If the PR adds or changes **user journeys / user-facing behaviors**, the Plan must include TrueCoverage work unless `plans/knowledge/ai-test-instructions.md` **explicitly** opts out.
  - If RUM is **not yet wired**, the Plan must include **RUM install for the target platform, init/emit helper, reporter, env, `plans/events/`**, and progress-tracker updates—**without** treating “not configured” as permission to skip. Only skip when **`### TrueCoverage Plan`** (or an explicit equivalent) states **opt-out**.
  - If TrueCoverage **is already configured**, the agent should **consider** which **key user events** need new or updated emits for the changed behavior, and include them (with `plans/events/*.event.md` updates—including required **`## Rationale`** and metadata sections per [`instrument-truecoverage.md`](./instrument-truecoverage.md)) when appropriate.
- **Mocking belongs in the Plan (always)**:
  - Explicitly decide per test case: **real backend**, **Playwright HTTP mocking** (`page.route` / `context.route`), and (when applicable) **AIMock** for LLM-backed flows.
  - If AIMock is selected, the Plan must include: wiring tasks, enablement mechanism (env flag / config), and how to validate it is actually being used.
- **Fixtures belong in the Plan (always; favor reuse)** (lives under **Arrange → Fixtures plan** for each test):
  - For every planned UI SmartTest, the Plan MUST name the **exact fixture dependencies** (what you will add to the test signature) that establish the posture.
  - The agent MUST **search existing fixtures first** (correct barrel: `api/fixtures/`, `mobile/fixtures/`, `web/fixtures/`, or flat `fixtures/` on **web** — see [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)) and strongly prefer reuse over creating new fixture modules.
  - Put **cross-platform seed factories** (e.g. `createSeedUser`) in **`shared/`**; wire them from domain `*.fixture.js` files under the appropriate **`fixtures/`** barrel.
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
- **Cleanup (Phase 7) is mandatory**:
  - Any environment created or started during Execute (local stack, dev server, ephemeral/EaaS env) MUST be torn down in **Phase 7**, and the plan must record what was stopped/destroyed (or `N/A` with reason).
- **Blockers must be called out in the Plan**: list every known blocker with (a) owner (agent vs user), (b) the exact action required, and (c) the earliest phase it blocks.

### Binding: ai-test-instructions (environment and FAQ playbook)

`plans/knowledge/ai-test-instructions.md` is the **only authoritative contract** for how this repo provisions environments for **test authoring** and **validation**. Agents routinely break runs by ignoring it or improvising (wrong compose profile, ad hoc staging URL, skipping health wait). Treat the file as **law** unless the user explicitly agrees to change it (then **update the file** so the next run stays deterministic).

**Strict rules**

1. **Read before you provision** — At the start of **Analyze** (env-relevant context) and again at the start of **Execute**, read `ai-test-instructions.md` in full enough to apply **`## Environment Provision Strategy`** (and subsections such as **Local - Test Authoring**, EaaS/Bunnyshell, Branch Management, CI) exactly as written: commands, profiles, env vars, **`BASE_URL` / `BACKEND_URL`** resolution, MCP provision steps, and “healthy” criteria.
2. **No freelance environments** — Do **not** switch to a different stack (e.g. “I’ll just use staging”) because it is convenient. If the documented path fails, **fix the path or document a blocker**—do not silently pick another target.
3. **FAQ first on blockers** — The file MUST include a **FAQ-style** section for recurring pitfalls (recommended heading: **`## Past learnings — authoring & validation (FAQ)`**; see [`init-testchimp.md`](./init-testchimp.md) template). **Whenever** you hit provisioning, health-check, auth, URL, port, volume, or seed-order friction: **search that FAQ next** after re-reading **`## Environment Provision Strategy`**. Treat matching entries as the **preferred playbook** before experimenting.
4. **Update after novel resolutions** — If the current issue is **not** already in the FAQ and you **resolve** it in this cycle, you MUST append a new entry: **`### Q:`** short symptom / error / situation; **`**A:**`** concrete fix (exact commands, file paths, env values to set, order of operations, MCP tool used). Keep entries project-specific and actionable. Same rule applies after **successful** workarounds the team would want again (not only failed attempts).
5. **Restart/reprovision** — After seed/probe/backend changes, ensure the running environment includes those changes per the **same** file (restart order, reprovision, push-before-EaaS, etc.—see [Batched order (Execute phase)](#batched-order-execute-phase)).

**PR-scoped environment (critical)**

- If the branch/PR includes **backend changes** (business logic, seed/probe endpoints, auth changes, or anything the tests depend on), validation MUST run against a **PR-scoped** environment that includes that code: **local** stack from the current branch **or** **ephemeral/EaaS** from the branch—**as `ai-test-instructions.md` prescribes**.
- **Super critical:** Running against a **stable/staging** URL that does **not** include the PR’s backend changes is **not** validating the change. Do **not** use stable backends for that unless the file explicitly allows it **and** you have verified the change is deployed there. If tests use `.env-*` with a fixed `BASE_URL`, that choice must still match the contract in `ai-test-instructions.md`.

### World-state → seed/fixture traceability (required)

This checklist is the **fixture / seed audit** for **Arrange**: it turns the written world state into a concrete gap list (fixtures, seed routes, teardown, probes). Agents often under-specify **Arrange** and mark **Seed endpoint updates** as `N/A` (“lazy N/A”) while the **world state** actually requires new data, flags, or entities—that breaks **Act** (the run fails or lies) and **Assert** (you prove the wrong post-state). That is a **Plan defect**. For **every** proposed test, before the Plan structure guard passes:

1. **Enumerate entities and flags** implied by **Arrange** (users, orgs, roles, billing state, feature flags, inventory, time windows, third-party stub posture, etc.).
2. **Map each item** to an existing fixture + seed/read API **or** mark it as **missing**.
3. **If any item is missing**, the Plan MUST list **concrete** seed/teardown/read endpoint changes (routes, payloads, guards) and **fixture** file changes—not a vague “may need seed.” **`N/A`** for seed updates is allowed **only** when every Arrange requirement is already satisfied by **existing** fixtures and endpoints (name them).
4. **Cross-check Act**: steps that create or mutate data may require **teardown** or idempotent seed patterns; call that out in the consolidated **System infra updates** section.
5. **Cross-check Assert → Backend validations**: every probe must exist or be listed as new probe work—same batched implementation order as seeds.

During **Analyze**, skim **`fixtures/`** and existing seed routes **before** claiming `N/A`. During **Execute**, do not start fixture or test authoring until seed **and** probe implementations for the batch are done and the stack is restarted if required ([`seeding-endpoints.md`](./seeding-endpoints.md), [`fixture-usage.md`](./fixture-usage.md)).

### Validation failure triage

When **UI** or **backend** validations fail (during Execute or when re-running tests), the agent MUST reason whether the failure is a **bug in the system under test** or a **defect in the test** (wrong steps, incomplete Arrange, wrong expectation, unstable locator, incorrect probe).

- **If it is a system bug:** change the **application implementation** so it meets the correct expected behavior; keep the test aligned with the **intended** product behavior.
- **If it is a test bug:** change the **test** (or fixtures, seed data, or probe expectations)—do not “fix” production code to match a bad test.

---

## Required structure for each proposed test (Plan phase)

The branch plan MUST contain one block **per test** (SmartTest and/or API test), using the template below. Each block is the **written specification** of that test’s **Arrange → Act → Assert** before any code is written—see [Arrange, Act, Assert: universal shape for every test](#arrange-act-assert-universal-shape-for-every-test).

**Do not omit** the three top-level headings **`### Arrange`**, **`### Act`**, **`### Assert`**; use **`TBD (needs user: …)`** inside a subsection when something is still unknown.

### Tests to write (inventory)

First, a short **numbered list of all tests** to be authored in this run (titles only; each numbered item maps to a full **Arrange / Act / Assert** block below). For **`mobile`** / **`multi-platform`**, tag each row with **`web`**, **`ios`**, or **`android`** per [`platform-scope.md`](./platform-scope.md).

For **each** test, include **in this order**:

### Arrange

**Goal:** Make the **starting reality** unambiguous so the team (and the agent in **Execute**) knows **exactly** what must exist before the first step of **Act**. Poor Arrange text is the main reason seed and fixture work is underestimated.

Describe the **world state** in which the test will run: prerequisite entities and the **state they must be in** before any UI/API actions (e.g. “a signed-in user whose saved payment method is an **expired** card”, “org on trial with feature flag X off”).

- **Plain-English only** here—what must be true, not how to code it.
- **Scope:** Include auth/session, feature flags, billing or entitlements, third-party stub posture, and time-sensitive state if the scenario depends on it—anything **Act** assumes is already true.

#### Fixtures plan

**Goal:** Declare **how Arrange becomes true in automation**—which Playwright fixtures (or API client setup) will run before the test body. This is what **Execute** step “fixtures” will implement.

- **Existing fixtures to use** (names/paths; what each contributes toward Arrange).
- **New or updated fixtures** (what to add, and why).
- Reuse-first: prefer extending existing `mergeTests` / fixture modules over duplicating setup.

#### Seed endpoint updates

**Goal:** List every **backend/test-only** change required so **Arrange** is achievable. This feeds the consolidated **System infra updates** section and **Execute** batch 1 (seeds).

List **every** seed/teardown (or test-only data) **API** change required—not only net-new routes but **updates** to existing handlers (new fields, new entity types, new idempotency keys, new guards).

- For each **missing** Arrange dimension identified in the [world-state trace](#world-state--seedfixture-traceability-required), list the **endpoint**, **method/path**, and **what posture** it establishes.
- If you write **`N/A`**, the line must justify that **all** Arrange dimensions are covered by **already-implemented** seeds/fixtures you named in **Fixtures plan**—not “probably fine.”

### Act

**Goal:** Specify the **ordered stimulus**—what the test will *do*—so automation is bounded and reviewable. **Act** is not a second place to describe Arrange; it is **steps only** (user journey or API sequence).

Plain-English **numbered or bulleted** list of actions in **execution order** (navigation, clicks, form fields, API calls, waits that are part of the scenario). This is exactly what Playwright (or an API client) will reproduce.

- One step = one user- or client-visible action (split “open modal then submit” into two steps when both matter).
- If **Act** creates or mutates data that **Assert** will check via the backend, that should already be anticipated under **Assert → Backend validations** (and probes).

### Assert

**Goal:** Split **how you know the test passed** into **surface (UI)** and **truth (backend/async)** so you do not accidentally ship tests that only check the happy path in the DOM while the server is wrong.

#### UI validations

Plain-English: what the test will **verify in the browser** after **Act** (visible text, URL, error banners, disabled buttons, toasts, empty states).

#### Backend validations

Plain-English: the **expected system state** after **Act** (e.g. order **accepted**, message enqueued, row soft-deleted). Include:

- What should be true in persistence, queues, or domain state.
- **Probe / read endpoints:** when state cannot be inferred from the UI, specify **test-only read/probe** HTTP endpoints that return the data the test will assert (DB snapshots, queue depth, record lookups). If new probe endpoints are needed, list them here; implement them in the batched **probe** step in [Batched order (Execute phase)](#batched-order-execute-phase).
- If only UI-level checks are sufficient for a given test, state that backend checks are **`N/A`** with rationale.

### Plan structure guard (before user approval)

For **each** test in the inventory:

- [ ] **World-state trace** completed: entities/flags from **Arrange** mapped to fixtures/seeds or explicitly listed as new work ([World-state → seed/fixture traceability](#world-state--seedfixture-traceability-required)).
- [ ] **Arrange** states a clear **world state** (not implementation); **Fixtures plan** and **Seed endpoint updates** align with that state.
- [ ] **Fixtures plan** names existing + new/updated fixtures (or `N/A` with justification if no Playwright fixture is used—rare for UI tests).
- [ ] **Seed endpoint updates** is complete or **`N/A`** only with the **strict** justification above (named existing coverage); no “TBD” hidden as `N/A`.
- [ ] **Act** lists **concrete, ordered** steps (the automation script); no Arrange-only prose mixed in as “steps.”
- [ ] **Assert** has **UI validations** and **Backend validations** subsections; probes listed where backend truth matters; each subsection is complete **or** explicitly **`TBD (needs user: …)`** / blocked.

---

## Batched order (Execute phase)

After the user approves the Plan, during **Execute** implement work in this order **across all tests** in the plan (so the backend is not cycled for every test). This order mirrors **Arrange → Act → Assert** in code: **support Arrange** (seeds, then fixtures), **support Assert** (probes), **then implement Act and Assert** in the spec (with **Assert** already specified so you do not author blind).

1. **Seed endpoint updates (implementation)**  
   Add or change **all** seed-related routes/handlers required by **any** test’s **Arrange → Seed endpoint updates**.

2. **Probe endpoint updates (implementation)**  
   Add or change **all** test-only **read/probe** endpoints required by **any** test’s **Assert → Backend validations** (and any read helpers fixtures need).

3. **(Re)start or reprovision the backend**  
   If **any** seed or probe endpoint (or other backend test-only code) was added or changed, bring up the app-under-test **once** with those changes loaded (per `ai-test-instructions.md`). **Do not** start the stack before step 1–2 if those steps had work—avoid stale code.

4. **Fixture implementation**  
   Create or update **all** Playwright fixtures (and related helpers) needed so each test can obtain the **Arrange** world state.

5. **Test authoring (per test; follow the plan)**  
   For each test, in spec code—**map 1:1 from the Plan’s Arrange / Act / Assert**:

   - **Arrange (code):** Use the **fixtures** from that test’s **Fixtures plan** so the browser (or client) starts from the documented posture.
   - Add **`// @Scenario: #TS-…`** link comment(s) only after stories/scenarios were created in **Execute** (step before fixtures/tests, or earlier in this batch) with **real** ids from MCP/CLI — never invent, never leave plan markdown without `id:`.
   - **Act (code):** Implement the ordered steps from the Plan’s **Act** section (UI or API automation).
   - **Assert (code):** Implement the Plan’s **Assert** section: **UI validations** plus **probe-based API checks** from **Backend validations** where specified.

6. **Run and triage**  
   Execute the real runner. On failure, apply [Validation failure triage](#validation-failure-triage) (system bug → fix product; test bug → fix test).

**Relationship to phases below:** The checklist subsections in **Phase 3: Execute** follow this order. **Phase 4: Validate** remains for **scenario-link audit** and any cross-cutting anomalies; it does not replace per-test assertions in step 5–6. **Phase 5 (Smart regression)** runs after Phase 4 is **green** (see [Phase 5](#phase-5-smart-regression-check)). **Phase 6 (ExploreChimp)** runs after Phase 5 when **Phase 2 §7** is **`yes`** (default for UI SmartTest deltas—see [§7](#7-explorechimp-branch-plan-yes-or-documented-na)); when **`N/A`**, skip Phase 6 per the branch plan ([`run-explorechimp.md`](./run-explorechimp.md)).

---

## Phase 1: Analyze

Goal: gather evidence and inputs needed to produce a high-signal Plan. This phase is *read-only* (no production code changes; no tests authored yet).

**Mandatory pre-step (first action):** Before any Analyze work, open `plans/knowledge/ai-test-instructions.md` and read **`## Environment Provision Strategy`** plus **`## Past learnings — authoring & validation (FAQ)`**. Use those pre-agreed decisions as constraints for planning and later execution; do not postpone this read to Execute.

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
  - A preliminary list of **which tests** might be needed. For each, jot **rough Arrange / Act / Assert** so Phase 2 is not cold-starting—the full three-section template is still required in **Plan**.
- **Smart regression (reconnaissance for Plan §6)** — From PR diff + existing **`plans/stories/`** and **`plans/scenarios/`** under `<MAPPED_PLANS_ROOT>`, note **likely affected** scenarios (same feature area, shared flows, touched APIs/screens). Record candidate **`#TS-…`** ids for the branch plan; linked specs are resolved in **Phase 5** via `// @Scenario:` grep under the SmartTests root.
- **ExploreChimp (reconnaissance for Plan §7)** — For **UI** changes, note which SmartTests could serve **Phase 6** (**new**, **regression-touched**, and **materially changed** UI specs; new screen-states). The **`yes`** vs **`N/A`** decision and target list are finalized in the branch plan under **[Phase 2 §7](#7-explorechimp-branch-plan-yes-or-documented-na)** (default **`yes`** for UI SmartTest deltas unless an allowed exception applies); this Analyze bullet is reconnaissance only.
- **Platform scope (mobile & multi-platform only)** — Read **`.testchimp-tests`** `project_type`. If **`mobile`** or **`multi-platform`**, apply [`platform-scope.md`](./platform-scope.md): draft **`## Platform scope (this run)`** on the branch plan (decision, confidence, rationale). **Inform** the user of the chosen platform(s) or **ask** when the PR diff does not clearly imply a single platform. Do not proceed to **Plan** user approval with **User confirmed: pending**.
- **Platform evidence (via TestChimp CLI/MCP when available)**
  - Use **TestChimp CLI** (`testchimp ...`) when MCP tools are not available.
  - Suggested queries:
    - `testchimp get-requirement-coverage --folder-path <plans/... or tests/...>` (scoped to the affected area; **omit `--branch-name`** so coverage aggregates across branch copies). On **mobile** / **multi-platform** repos, interpret multiple **`platform`** rows per scenario; add `--platform ios` or `--platform android` when analyzing one stack **in scope** for this run ([`platform-scope.md`](./platform-scope.md)).
    - `testchimp get-execution-history --folder-path <tests/...>` (recent failures/flake; omit `--branch-name` unless you need one branch only). For a single scenario’s runs: `--scenario-id <platform-scenario-uuid>` with optional `--platform web|ios|android` (CLI **≥ 0.1.6**).
  - Record results (relevant summaries) in the branch plan file (high level; no giant dumps).

### Phase 1 completion gate (Analyze → Plan)

Before proceeding to **Plan**, the agent must record **done/blocked/`N/A`** for each item (in the branch plan file):

- [ ] Branch plan exists and was read/created.
- [ ] Change context captured (diff vs base or explicit fallback).
- [ ] Relevant existing plan docs identified (stories/scenarios/events/knowledge).
- [ ] **Fixture/seed discovery:** scanned the correct **`fixtures/`** barrel(s) and **`shared/`** per scaffold type ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)); noted existing seed/read routes (or `N/A` + reason).
- [ ] **`ai-test-instructions.md`:** re-read (or created stub via user direction) **`## Environment Provision Strategy`** and **`## Past learnings — authoring & validation (FAQ)`** (or `N/A` + reason if plans root missing—then stop and recommend `/testchimp init`).
- [ ] Coverage/execution history queried via CLI/MCP where applicable (or `N/A`).
- [ ] **Smart regression:** candidate affected scenarios noted for **Plan §6** (reconnaissance; final list refined in **Phase 5**).
- [ ] **ExploreChimp:** candidate UI specs noted for **Plan §7** (reconnaissance only; final **`yes`** / **`N/A`** belongs in **[Phase 2 §7](#7-explorechimp-branch-plan-yes-or-documented-na)** during **Plan**).
- [ ] **Platform scope:** for **`mobile`** / **`multi-platform`**, branch plan **`## Platform scope (this run)`** drafted; user **informed** or **asked** per [`platform-scope.md`](./platform-scope.md) (`N/A` for **web-only** `project_type`).

---

## Phase 2: Plan

Goal: produce a written plan (persisted in the branch plan file) that the user explicitly approves, and that the agent can execute deterministically.

The Plan MUST be written under the branch plan file. It MUST include the following **top-level** sections (in order), **and** the [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase) for every listed test.

0. **Platform scope (this run)** — **Required** when **`project_type`** is **`mobile`** or **`multi-platform`**. Use the template in [`platform-scope.md`](./platform-scope.md). Filter **Tests to write**, **§6 Smart regression**, and **§7 ExploreChimp** to platforms in scope. **Web-only** projects: omit this section or mark **`N/A`**.
1. **Test plan updates** (plans layer)
   - Stories/scenarios to create/update.
     - **Never invent IDs** means: never assume fake `#US-...` / `#TS-...` ids, and **never** plan to write story/scenario `.md` files without a platform-issued `id:` (omitting `id` is forbidden).
     - If scenarios / stories are missing for the PR changes, the Plan must explicitly list the **new** stories/scenarios to be created so the platform generates **real IDs**.
     - **Timing rule**: the actual `create-user-story` / `create-test-scenario` calls (and subsequent `update-user-story` and `update-test-scenario`) must be performed **only in Execute**, **after** the user approves the Plan generated. Sequence per artifact: **create (get ordinalId) → write markdown with `id:` already set → update**. See [`author-plans.md`](./author-plans.md).
2. **Tests to write (inventory) + per-test Arrange → Act → Assert**
   - Use **[Tests to write (inventory)](#tests-to-write-inventory)** and, for **each** test, the full template under [Required structure for each proposed test (Plan phase)](#required-structure-for-each-proposed-test-plan-phase). The three sections are **mandatory** so **Arrange** drives the seed/fixture audit, **Act** defines executable steps, and **Assert** commits to UI vs probe proof—see [Arrange, Act, Assert: universal shape for every test](#arrange-act-assert-universal-shape-for-every-test).
   - **Cross-link:** The older **“Posture table”** (prerequisite entities, fixture deps, seed/probe, mocks, post-UI assertions) is **subsumed** by **Arrange** (world state + fixtures + seed updates) and **Assert** (UI + backend + probes). Mocks, if any, can be noted under **Arrange** (e.g. “HTTP mock for payment provider”) or in a short **Notes** line under that test.
3. **System infra updates** (product/backend) — *summary / deduplication layer*
   - A consolidated list of all **seed** and **probe** endpoint work (may duplicate what each test’s **Seed endpoint updates** and **Backend validations** already state—intentional for a single “build list”).
   - Teardown routes if needed.
   - TrueCoverage instrumentation changes (events/metadata + docs) when in scope.
4. **Test infra updates** (tests harness) — *summary*
   - Consolidated fixture/mock work (details remain per test under **Arrange → Fixtures plan**).
5. **User approval and plan structure guard**
   - **Explicit user approval:** The agent must stop until the user approves the branch plan. Record approval status in plan frontmatter when the user consents.
   - Run the [Plan structure guard (before user approval)](#plan-structure-guard-before-user-approval) for every test; record pass/fail or `TBD` items.
6. **Smart regression scope (likely affected scenarios)**
   - List **candidate** scenario ids (**`#TS-…`**) likely affected by the PR, with a **one-line rationale** each (from **`plans/scenarios/`**, parent **`plans/stories/`**, and PR diff—not invented ids).
   - Note that **linked SmartTests** will be resolved in **Phase 5** by searching the SmartTests root for `// @Scenario: #TS-<n>` (and optional MCP **`get-requirement-coverage`** on affected `plans/...` folders).
   - Record **`N/A`** only when the PR is **greenfield** (no existing scenarios in scope) or **no plausible regression surface** (e.g. docs-only)—with one-line justification.
7. **ExploreChimp branch plan (yes or documented N/A)**
   - **Default:** When the PR/plan scope includes **new or materially changed UI SmartTests** (real UI; **`markScreenState`** in use or planned once stable—especially **new screen-states** in authored tests), record **`yes`** in §7 and list **target UI SmartTest files** (paths or globs). **Phase 6** then runs after **Phase 5: Smart regression** is green. Treat **§7 as `yes`** in those cases unless the user **explicitly opts out** before plan approval or the case is **`N/A`** with a **one-line rationale** (e.g. **API-only** change, **no UI journey**, **user declined cost**). **`N/A`** must appear on the branch plan (same approval window as the rest of the plan)—do **not** skip Phase 6 silently or treat ExploreChimp as “only if the user asks later.”
   - **ExploreChimp target list (when `yes`):** Include **all** of: (a) **new** UI specs from this PR, (b) **materially changed** UI specs from this PR, and (c) **regression suite** UI specs that were **run or updated** in **Phase 5** (not only net-new tests). Refresh the list on the branch plan after Phase 5 completes.
   - If **`yes`**: confirm the user accepts **extra runtime / API cost** as part of the same plan approval. Execution: **[Phase 6: ExploreChimp](#phase-6-explorechimp)** and [`run-explorechimp.md`](./run-explorechimp.md).
8. **Workflow checklists (phase hygiene)**
   - An **Execute checklist** (Phase 3) that mirrors [Batched order (Execute phase)](#batched-order-execute-phase) plus environment bring-up, test runs, and triage.
   - A **Validate checklist** (Phase 4): scenario-link comment audit + **`markScreenState`** / atlas remediation.
   - A **Smart regression checklist** (Phase 5): affected scenarios, linked specs, run results, fixes.
   - A **Cleanup checklist** (Phase 7): local env/process teardown and/or ephemeral environment destroy, aligned to the environment strategy used.

The Plan MUST also include:

- **Blockers** (if any) per non-negotiables.

### Phase 2 completion gate (Plan → Execute)

Before proceeding to **Execute**, the agent must record **done/blocked/`N/A`** for each (in the branch plan file):

- [ ] Plan includes **Tests to write (inventory)** and **per-test** Arrange / Act / Assert for **each** test.
- [ ] [Plan structure guard (before user approval)](#plan-structure-guard-before-user-approval) satisfied for every test (or only `TBD` with explicit user-input labels—**not** silent blanks).
- [ ] **World-state → seed/fixture** trace done for every test: consolidated **System infra** / **Test infra** lists match per-test **Arrange** (no orphan `N/A` seeds).
- [ ] Stories/scenarios to create (no fake ids) and timing rule clear.
- [ ] System infra and test infra summaries align with the per-test subsections.
- [ ] Environment strategy **matches** `plans/knowledge/ai-test-instructions.md` (no improvised alternate URLs); FAQ section **consulted** for known env pitfalls affecting this PR scope.
- [ ] User explicitly approved the plan to proceed.
- [ ] **Platform scope:** **`User confirmed: yes`** on branch plan (or **`N/A`** — web-only project); platform list matches inventory and §6/§7.
- [ ] **Smart regression:** branch plan **§6** lists candidate affected scenarios (or **`N/A`** + rationale).
- [ ] **ExploreChimp:** branch plan **§7** records **`yes`** vs **`N/A`** (+ target specs when **`yes`**, including new + changed + regression-touched UI specs); default-on policy for UI deltas applied; matches what the user approved.

---

## Phase 3: Execute (do the plan)

Preamble before execution: Verify that the plan doc created above is present. Verify that it indicates the user has approved. If not—**PAUSE** and do **not** continue.

**Execute preamble — environment (mandatory):** Immediately after approval, re-open `plans/knowledge/ai-test-instructions.md` and confirm how this run will provision and target the app (**commands**, **URLs**, **MCP flows**, **health gates**). If anything is ambiguous, resolve it **before** seed/probe work—**do not** guess `BASE_URL`. If you hit a blocker, apply **[Binding: ai-test-instructions (environment and FAQ playbook)](#binding-ai-test-instructions-environment-and-faq-playbook)** step 3 (FAQ first); after a **novel** fix, apply step 4 (append FAQ entry).

**Execute preamble — `TESTCHIMP_API_KEY` (P0):** Before the first **`npx playwright test`** / Mobilewright invocation, confirm the **runner** process will have **`TESTCHIMP_API_KEY`** set (non-blank); resolve via **`SKILL.md`** walk-up + export if needed. If you cannot verify, **halt**—do not run tests to “see what happens.”

Goal: execute the approved plan in **[Batched order (Execute phase)](#batched-order-execute-phase)**, and keep the branch plan checklists updated so reruns are deterministic.

During Execute, the agent MUST maintain a checklist in the branch plan file and mark each line as **done / blocked / N/A**.

### 1) Seed endpoint updates (all tests)

- [ ] All seed endpoints from the Plan (per-test **Arrange → Seed endpoint updates** + consolidated list) are **implemented** in the product/backend code.

### 2) Probe endpoint updates (all tests)

- [ ] All probe/read endpoints from **Assert → Backend validations** (and any fixture read helpers) are **implemented**.

### 3) Environment: load new backend code (if 1 or 2 had changes)

- [ ] If **any** seed or probe (or related test-only) backend code was added or changed: environment is **(re)started or reprovisioned** so the running stack includes that code (per `ai-test-instructions.md`).
- [ ] If no backend endpoint changes in 1–2: record **`N/A`** (no restart solely for this reason).

### 4) Test plan updates (stories/scenarios on platform) — *after code is in place for seeds/probes or in parallel if independent*

- [ ] For **each** new story: **`create-user-story`** → **Write returned `content`** (already has **`id: US-<ordinalId>`**) → edit body if needed → **`update-user-story`**.
- [ ] For **each** new scenario: **`create-test-scenario`** → **Write returned `content`** (already has **`id: TS-<ordinalId>`** + **`story:`**) → edit body if needed → **`update-test-scenario`**.
- [ ] **Never** write story/scenario markdown that omits or blanks **`id:`** (that is not a valid “don’t invent ids” workaround). If **`update-*`** errors on missing id/story, fix by using create’s returned content — do not invent ids.
- [ ] Obtain **real** ids for `// @Scenario:` comments from those create responses (or existing synced plan files).
- [ ] Self-check: every new/changed story/scenario path under the plans root has a non-empty **`id:`** before leaving this step.

### 5) Fixtures (all tests)

- [ ] Create/update **all** fixtures and helpers so each test’s **Arrange** posture is reachable.

### 6) Tests (authoring + validations)

- [ ] For **each** planned test: author SmartTest (and/or API test) using the named **fixtures**; add **`// @Scenario:`** with real ids; implement **Act**; implement **Assert** (UI + probe API calls as planned).
- [ ] When the user pastes a platform **Copy test generate prompt** for **`TS-<n>`**: call **`get-test-scenarios`** with that ordinal, then **`get-user-stories`** for linked story ordinals returned (see [`author-plans.md`](./author-plans.md)).
- [ ] When the user pastes a **Copy test generate prompt** / **Copy prompt** / legacy **Copy script generate prompt** from the manual session viewer (or **`/testchimp author test for manual session`**): call **`get-manual-session-details`**, then follow [`author-test-from-manual-session.md`](./author-test-from-manual-session.md) (authoring-only; use **`linkedScenarioOrdinalIds`** for a single **`get-test-scenarios`** batch when plans are not synced).
- [ ] **Insufficient context fallback (only after codebase inference fails):** If a planned scenario is too thin to author and the repo/PR still does not reveal the journey, **do not invent steps** — suggest Chrome-extension manual session capture (scenario selected) and wait for the pasted prompt. Guidance: [`write-smarttests.md`](./write-smarttests.md) § **Insufficient scenario context**; docs: [manual session capture](https://docs.testchimp.io/smart-tests/creating#2-from-manual-session-capture-chrome-extension). Continue other tests that have enough context.
- [ ] **Never** invent scenario ids; only use ids from the platform.
- [ ] Re-run the real Playwright (or API) runner until pass or explicit failure with next steps.

### 7) Dogfooding note (TestChimp testing TestChimp)

If the product-under-test is TestChimp itself (or you are testing a “planning UI” feature), do **not** treat repository `plans/` files as proof of runtime state.
Your tests must establish a **world-state posture** in the target project (seed a test project and create the required plan artifacts like event files via seed endpoints + fixtures), then validate the UI against that seeded state.

### 8) Triage (ongoing)

- [ ] On red runs: apply **system bug vs test bug** reasoning; fix the correct layer; re-run.

---

## Phase 4: Validate (linkage + anomalies)

Goal: ensure the resulting test suite is correctly linked to requirements and can be trusted by TestChimp coverage/reporting. Per-test **Act** and **Assert** checks already ran in **Execute**; this phase closes **gaps in scenario linkage** and **screen/state vocabulary** for traces and atlas-backed tooling.

### What to validate

1. **Scenario-link comment audit (required)**
   - For every SmartTest that should correspond to a scenario:
     - Confirm there is at least one `// @Scenario: #TS-<n> <Title>` comment INSIDE the test body.
2. **Screen-state atlas (SmartTests) — during Validate only**
   - **Do not** spend multi-iteration **Execute** time naming every screen/state; do vocabulary work **here**, after tests pass functionally.
   - **Before** the validation run (or before editing specs for trace quality): load existing project vocabulary with **`testchimp list-screen-states`** in the **shell** (preferred for agents; see [`cli.md`](./cli.md) § **Screen-state atlas**) **or** MCP **`list-screen-states`** when MCP is available. Parse the JSON response and keep **`(screen, state)`** pairs in working memory for reuse.
   - Run the touched UI specs **headed** for this pass when possible (correct config + `--project` per **Non-negotiables**) (per **`SKILL.md`** — e.g. `npx playwright test … --headed`) and **inspect the live UI** at each transition so names match **user-visible** surfaces; do not invent markers from code paths alone. Use trace/screenshot evidence if headed runs are not possible.
   - After **stable** UI following a real transition (navigation, modal, meaningful DOM change), compare to the prior checkpoint; when the UI meaningfully changes, **reuse** an existing **`(screen, state)`** from the list when it fits; otherwise call **`testchimp upsert-screen-states`** (or MCP **`upsert-screen-states`**) **before** editing the spec, then add **`await markScreenState`** with the **exact** strings you registered. Ensure the test callback includes **`markScreenState`** (fixture from **`installTestChimp`** on the merged `test` in **`fixtures/index.js`**), then add **`await markScreenState('<Screen>', '<State>')`** (or omit the second argument for **`default`**) on the correct line so it appears in Playwright traces. **Do not** add `import { markScreenState } from '@testchimp/playwright/runtime'`.
   - **Do not** add or rely on legacy **`// @Screen:`** / **`// @State:`** comment annotations for new or updated work — that path is **legacy**; the **`markScreenState` fixture** is canonical for new specs.
3. **Anomaly handling (required)**
   - If a test is missing `// @Scenario:`:
     - Treat it as an anomaly.
     - Determine whether a relevant scenario already exists (from plans, or by querying TestChimp).
     - If it exists: add the comment.
     - If it does not exist: create the scenario via **MCP tools first** (fallback to CLI) using **create → write with `id: TS-…` → update**, then add the comment using the real returned ID.
   - Never hallucinate `#TS-*` ids - only use ones returned by using create-test-scenario exposed by cli / mcp.
   - Never “fix” a missing scenario by writing `plans/scenarios/**/*.md` without a platform **`id:`**.

### Phase 4 completion gate (Validate → Phase 5)

Record in branch plan file:

- [ ] Scenario-link comment audit completed for all touched/new SmartTests.
- [ ] Any missing links remediated (scenario created if needed; comments added).
- [ ] Screen/state vocabulary: **`testchimp list-screen-states`** (CLI) or MCP **`list-screen-states`** was used before atlas / `markScreenState` edits (or **`N/A`** with reason — e.g. no UI SmartTests touched).
- [ ] Meaningful UI transitions in touched SmartTests have **`markScreenState`** at the right step, or **`N/A`** with reason (no meaningful transitions in scope).
- [ ] Any remaining anomalies explicitly listed with next steps (only if blocked).
- [ ] **Handoff to Phase 5:** Confirm **`TESTCHIMP_API_KEY`** on the runner and correct config/`--project` per scaffold (see non-negotiables). If branch plan **§6** is **`N/A`**, record that scenario identification still runs from PR + plans but no linked specs are expected—or skip Phase 5 per plan rationale.

### Mark plan items implementation-done (human-gated, after Validate is green)

After **Phase 4** passes and the user confirms the PR implements the planned stories/scenarios, call **`mark-plan-items-implementation-done`** (MCP) or **`testchimp mark-plan-items-implementation-done`** (CLI) with **`scenarioOrdinalIds`** / **`userStoryOrdinalIds`** — the **numeric** parts of **`TS-<n>`** / **`US-<n>`** only (not platform UUIDs). This updates **`lifecycle_fields.status`** in the DB to **`done`**; it does **not** write **`status`** into plan markdown frontmatter.

For **prioritization during `/testchimp test` Analyze**, treat a scenario as implementation-complete when lifecycle is **`done`** **or** when it is branch-implemented and validated (tests green on the branch). **`/testchimp evolve`** is stricter: only **`done`** on the scenario **and** parent story counts for test authoring.

---

## Phase 5: Smart regression check

> **Full guidance:** [`run-smart-regression.md`](./run-smart-regression.md) (`workflow-id: run-smart-regression`) — scoping (explicit / feature branch / default + `get-last-run-workflow-detail`), depends on connect-to-test-env, plan→approve when standalone, and `report-agent-action` on fixes. **Keep reading this section** so Phase 5 behavior is unchanged if the agent only has this file.

Goal: after **new/changed** tests are **authored and validated** (Phase 4), find **existing** coverage that the PR may have broken, **run** those SmartTests/API tests, and **rectify** failures (test vs product per [Validation failure triage](#validation-failure-triage)).

This phase is **codebase-driven** (no new platform APIs required): scenarios and stories live under the mapped **`plans/`** tree; linkage to specs is via **`// @Scenario: #TS-<n>`** comments in the SmartTests root.

### When to run

**Always** after **Phase 4** is green, unless the branch plan **§6** records **`N/A`** with rationale (e.g. greenfield repo with no existing scenarios, docs-only PR). **Do not** skip silently when existing plans and linked tests exist.

### 1) Identify likely affected scenarios

Using **PR diff**, **branch plan §6**, and plan markdown under **`<MAPPED_PLANS_ROOT>`**:

1. Read relevant **`plans/stories/`** and **`plans/scenarios/`** (folder paths give feature context; scenario **`story:`** frontmatter links to parent stories—see [`author-plans.md`](./author-plans.md)).
2. Select scenarios **likely affected** when they share:
   - The same **feature area**, screens, routes, or APIs touched by the PR
   - The same **user journey** or business rules changed in product code
   - **Sibling** scenarios under the same story folder when the story’s scope overlaps the PR
3. **Exclude** scenarios already covered by **new** tests authored in this run (unless you still want a regression run for confidence).
4. Optionally corroborate with MCP/CLI **`get-requirement-coverage`** scoped to affected **`plans/...`** folders (omit **`--branch-name`** unless you need one branch only).
5. Record on the branch plan: **`#TS-…`** id, title, **why** it is in the regression set.

**Never invent** `#TS-…` ids—only ids present in plan files or returned by the platform.

### 2) Resolve linked SmartTests

From the SmartTests root (directory containing **`.testchimp-tests`**):

1. Search **`*.spec.{js,ts}`** for `// @Scenario: #TS-<n>` matching each affected scenario id (a spec may cover **multiple** scenarios).
2. Build a **deduplicated** list of spec files (and API tests if they use the same comment convention).
3. Record the list on the branch plan under **Phase 5 completion**.

### 3) Run the regression suite

- **`cd`** SmartTests root; run per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — **Preamble #4** required.
- Prefer **headless** for regression unless debugging (headed default remains for **authoring** per `SKILL.md`).
- Re-run after fixes until **pass** or each failure is **explicitly blocked** with next steps.

### 4) Rectify failures

Apply [Validation failure triage](#validation-failure-triage):

- **Product regression:** fix application code; keep tests aligned with intended behavior.
- **Test outdated:** update the **existing** spec (fixtures, steps, assertions, probes)—document material changes on the branch plan for **ExploreChimp** handoff.

If a failure reveals a **missing** scenario for new behavior, add it to the branch plan backlog (create in platform during Execute rules if not already done)—do not invent ids in comments.

### Phase 5 checklist

- [ ] Affected scenarios identified from **plans + PR** (listed on branch plan).
- [ ] Linked specs resolved via **`// @Scenario:`** grep (listed on branch plan).
- [ ] Regression suite executed with real runner (**`TESTCHIMP_API_KEY`** on process).
- [ ] Failures triaged; tests and/or product updated; suite re-run to green or explicit blockers recorded.
- [ ] Branch plan **§7 ExploreChimp targets** updated to include **regression-touched** UI specs (if **§7** is **`yes`**).
- [ ] Best-effort **`report-agent-action`** on mutating regression fixes (same ULID as the run-qa plan).

### Phase 5 completion gate (Phase 5 → Phase 6)

Record in branch plan file:

- [ ] Affected scenarios + linked spec paths documented (or **`N/A`** + rationale per **§6**).
- [ ] Regression run results recorded (pass / fail / blocked).
- [ ] Any **materially changed** existing specs noted for **Phase 6** ExploreChimp scope.
- [ ] **Handoff to Phase 6:** If **§7** is **`yes`**, confirm ExploreChimp target list = **union** of new UI specs, changed UI specs, and regression-updated UI specs with **`markScreenState`** (add markers in Phase 4 or a quick Validate pass on touched regression specs if UI flows changed).

---

## Phase 6: ExploreChimp

Goal: **UX analytics** along UI SmartTest pathways after **Phase 5** is **green** and **scenario links** + **`markScreenState`** / atlas quality meet the Validate bar on all specs in scope.

### When to run

When the **branch plan** **[§7](#7-explorechimp-branch-plan-yes-or-documented-na)** records **`yes`** and that choice was covered by the **same user approval** as the rest of the plan. **`yes`** is the **default** for PR/plan scope that includes **new or materially changed UI SmartTests** (see §7). If the plan records **`N/A`** with rationale, skip this entire phase and go to **Phase 7**.

### ExploreChimp test selection (required)

Run ExploreChimp on the **union** of:

1. **New** UI SmartTests authored for this PR (branch plan inventory).
2. **Materially changed** UI SmartTests from this PR (edits in Execute/Validate).
3. **Regression suite** UI SmartTests that were **executed or updated** in **Phase 5** (existing linked specs—not only net-new files).

**Do not** limit Phase 6 to newly authored tests only. Pure API specs remain out of scope ([`run-explorechimp.md`](./run-explorechimp.md)).

### Phase 6 checklist

- [ ] **`TESTCHIMP_API_KEY`** verified on the **same process** that will run Playwright/Mobilewright with **`EXPLORECHIMP_ENABLED`** (P0 — non-negotiables); do not rely on MCP-only config for the child runner.
- [ ] Re-read **`plans/knowledge/ai-test-instructions.md`** (**`## ExploreChimp`** + **Environment Strategy**).
- [ ] Run ExploreChimp per **[`run-explorechimp.md`](./run-explorechimp.md)** on the **UI specs in the updated §7 target list**: mobile UI projects with **`use.platform`**, **`EXPLORECHIMP_ENABLED`**, **`TESTCHIMP_BATCH_INVOCATION_ID`**, **`TESTCHIMP_API_KEY`**, optional source/regex vars when **`NETWORK`** is included.
- [ ] If the plan was **`N/A`**: ensure **`N/A`** + one-line justification is already in the branch plan, then skip execution.

### Phase 6 completion gate (Phase 6 → Phase 7)

Record in branch plan file:

- [ ] ExploreChimp batch **completed** per plan, or **`N/A`** with justification (per **§7**).
- [ ] Target spec list matches **new + changed + regression-touched** UI coverage (not new-only).

---

## Phase 7: Cleanup (environment teardown)

Goal: leave the developer machine / CI job in a clean state.

### What to cleanup

- **Local**: stop any local stack or dev servers started for this run (or record `N/A` if none were started).
- **Ephemeral/EaaS**: destroy any ephemeral environments provisioned for this branch (or record `N/A` if none were provisioned).

### Phase 7 completion gate (Cleanup → Done)

Record in branch plan file:

- [ ] Local processes/environments stopped (or `N/A` + reason).
- [ ] Ephemeral environments destroyed (or `N/A` + reason).
- [ ] **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** done (`ACTION_COMPLETED` / `ACTION_FAILED` for `WORKFLOW` + `run-qa`).

---

## Final report (always)

At the end, report:

- What plan items were completed vs blocked.
- What changed in system infra (seed/probe/TrueCoverage).
- What changed in test infra (fixtures/mocks).
- What tests were added/updated and their run results.
- **Smart regression (Phase 5):** affected scenarios, linked specs run, pass/fail, and any existing tests updated—or **`N/A`** with rationale.
- **ExploreChimp (Phase 6):** executed per branch plan **§7** (specs targeted: new + changed + regression-touched) when **`yes`**, or **`N/A`** with rationale on the plan; whether **`## ExploreChimp`** in **`ai-test-instructions.md`** was updated.
- Validate outcomes (scenario-link audit: pass/fail/anomalies fixed).
- Any cleanup done (local env stop, ephemeral env destroy, temp artifacts removed, generated artifacts not committed).
- Whether **`ai-test-instructions.md`** FAQ (**`## Past learnings — authoring & validation (FAQ)`**) was **updated** with any new Q/A entries from this run (or explicitly **none**).

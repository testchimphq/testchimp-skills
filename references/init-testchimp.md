# /testchimp init

Initialize the repo for TestChimp using a phased workflow. This document is for **AI agents** and must be run as **Phase 0 (optional smoke) -> Phase 1 (Requirement gather) -> Phase 2 (Plan) -> Phase 3 (Execution)**. Do not jump directly into implementing every setup task.

### Phase gating (required — same style as `/testchimp evolve`)

Between phases, **stop and complete the phase’s completion gate** before continuing. Treat gates like [`upkeep.md`](./upkeep.md): **nothing implied**, **nothing skipped silently**.

- For **every** gate checklist line: mark **done** (one-line evidence is enough) or **`N/A`** with a **one-line justification** (why this run/repo does not need it).
- Record outcomes in **`plans/knowledge/ai-test-instructions.md`** (recommended: short **“Phase N completion”** subsections) **and/or** the chat transcript so reruns are deterministic.

---

## Purpose

`/testchimp init` often includes long-running and branching work: EaaS decisions, seeding strategy, harness setup, mocking (Playwright `page.route` + optional AIMock), existing Playwright import strategy, CI wiring, and TrueCoverage setup. To keep this reliable, agents must:

1. collaborate with the user on a concrete action plan first,
2. persist decisions and item status in `plans/knowledge/ai-test-instructions.md`,
3. execute each action item methodically and update progress after each item.

### Source of truth: `plans/knowledge/ai-test-instructions.md`

Project-level decisions must be persisted in `plans/knowledge/ai-test-instructions.md` so teammates and agents share the same choices across workstations.

At minimum, `/testchimp init` should ensure this file contains the following sections (author or update as needed):

```md

# TestChimp Init Progress

## Completed Items

## Pending Items

## Deferred Items

---
## Environment Provision Strategy

### Local - Test Authoring

### CI - Test Execution

## TrueCoverage Plan

## Mocking Plan

## ExploreChimp

<!-- Optional: default sources / which tests to explore on PRs, product quirks, blockers. Do **not** treat NETWORK URL regex as an init requirement. Ignore obsolete network-analytics config. Agents MUST read this before ExploreChimp runs. See references/run-explorechimp.md. -->

## Past learnings — authoring & validation (FAQ)

<!-- FAQ-style playbook: each entry = symptom / blocker → resolution. Agents MUST consult this before improvising env fixes; MUST append a new Q/A after resolving any issue not already listed. See `references/run-qa.md` (ai-test-instructions binding). -->

### Q: (example) Local stack reports healthy but tests hit wrong API host

**A:** (example) `BASE_URL` in `.env-QA` pointed at staging; local compose only brought up UI. Document the correct export and which service owns `BASE_URL` for local runs.

```

Keep this file **project-level only** (avoid workstation-specific progress like “installed MCP client on my laptop”).

**`## Past learnings — authoring & validation (FAQ)`:** Maintain this section as a **running FAQ** for test authoring and validation: wrong ports, compose profiles, stale volumes, auth to preview envs, EaaS provision failures, flaky health checks, seed order, etc. Use a consistent **`### Q: …` / `**A:** …`** pattern so agents (and humans) can scan quickly. Init should **create** the heading (even if only the example stub remains until the first real incident); `/testchimp test` and evolve runs **grow** it whenever a blocker is hit and fixed.

**TrueCoverage opt-in / opt-out:** Do **not** restate policy here—use **[Key Area 4 — TrueCoverage](#key-area-4-truecoverage-infra-rum-journey-events)** (single canonical block) and [`instrument-truecoverage.md`](./instrument-truecoverage.md).

### Two scopes: workstation vs project

Init mixes **two independent scopes**. Agents must not collapse them into a single “are we done?” signal.

| Scope | What it covers | How to tell if it is already done |
|--------|----------------|-------------------------------------|
| **Workstation** (per machine) | Host MCP registration: `npx` runs **`@testchimp/cli`** with the **`mcp`** subcommand (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)); the **project-scoped** MCP config file (e.g. **`.cursor/mcp.json`** in Cursor, **`.mcp.json`** at repo root for Claude Code — see [Workstation gate](#workstation-gate-always-first)) contains a **`testchimp`** server entry with **`env.TESTCHIMP_API_KEY`** and **`env.TESTCHIMP_PROJECT_ID`** set to **real** values (not empty, not placeholders). Optionally shell `TESTCHIMP_API_KEY` for Playwright / ai-wright. | **Check local config every time** — never infer from git. Agent **creates or patches** the project MCP file during init when missing or incomplete. |
| **Project** (repo / team) | Shared decisions: environment strategy, TrueCoverage, mocking, import/CI plans, action items — persisted under **`plans/knowledge/ai-test-instructions.md`**. | If that file **exists and is substantively populated** (sections filled, not just a stub), treat **project-level** decisions as already captured unless the user wants to change them. |

**Critical:** A teammate who clones the repo after project init may see a complete **`ai-test-instructions.md`** and still have **no** MCP client or key on **their** laptop. **`/testchimp init` must always run the workstation checks and fixes** in that situation, even when project-level markdown is already done.

---

## Opening message (required, first user-facing step)

When **`/testchimp init`** starts, the **first substantive message to the user** must set expectations before deep technical work. **Immediately after** that message, run the **[Workstation gate](#workstation-gate-always-first)** and the rest of this document (Preamble checks in **`SKILL.md`** apply as usual).

**Include the following substance** (adapt wording slightly for tone; keep meaning):

- **During init**, TestChimp sets up **complete QA infrastructure** for the project: seeding endpoints, test environment management, CI setup, fixtures, **TrueCoverage instrumentation** (web: `@testchimp/rum-js`; native: **TestChimpRum** on iOS/Android per [`instrument-truecoverage.md`](./instrument-truecoverage.md)), and test scaffolds with proper TestChimp integration (Playwright on web; Mobilewright on **`mobile`** / **`multi-platform`** — see **`.testchimp-tests`**, [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md), [`mobilewright-smarttests.md`](./mobilewright-smarttests.md)).
- **After init**, the user mainly runs **`/testchimp test`** when they finish a PR and want it tested.
- **Ongoing**, the agent runs the full QA workflow — when speaking to the user, use first person: *I will run the complete QA workflow* to author tests for relevant scenarios, make the necessary QA infrastructure adjustments, identify coverage gaps, and address them.
- **Periodically**, run **`/testchimp evolve`** to analyze test coverage gaps and TrueCoverage insights, address them, and improve the suite. Persist each evolve run as a dated plan markdown file under **`<MAPPED_PLANS_ROOT>/knowledge/evolve_plans/`** (see [`upkeep.md`](./upkeep.md)) so later runs have traceability.
- **Periodically** (or when duplicate noise appears), run **`/testchimp cleanup`** to audit semantically similar SmartTests, mark legitimately distinct pairs, and remove true duplicates with approval ([`cleanup.md`](./cleanup.md)). Cleanup is **separate from evolve**.

**Always** include this overview link: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Workstation gate (always first)

Run this **before** optional smoke (Phase 0) or project requirement gathering (Phase 1–3). On **every** `/testchimp init`, complete:

1. **Resolve project MCP config path** — MCP config is **per project**, not global. From the SmartTests root (folder with `.testchimp-tests`), walk **up** toward the git/repo root and pick the **first existing** host config file, or the path you will **create** at the repo root if none exist:
   - **Cursor:** `<repo>/.cursor/mcp.json` (create **`.cursor/`** if needed)
   - **Claude Code:** `<repo>/.mcp.json` at the repository root
   - **Other hosts:** use that host’s documented **project-level** MCP JSON path; same walk-up rule as **`SKILL.md`** Preamble check **#4**
   - Prefer the path for the **active IDE/agent host** when you know it; if unsure, create/update **both** common paths only when they are absent or lack TestChimp — do not duplicate conflicting entries in the same repo without user direction.
2. **Create or patch MCP JSON (required when missing or incomplete)** — Read the blob in [`../assets/sample-mcp.json`](../assets/sample-mcp.json) as the canonical **`testchimp`** server template.
   - **No config file yet:** write a new file at the resolved path with the full contents of **`sample-mcp.json`** (placeholders intact).
   - **File exists but no `mcpServers.testchimp`:** parse existing JSON, **merge** the `testchimp` entry from **`sample-mcp.json`** into `mcpServers` without removing other servers, then write the file back.
   - **`testchimp` exists but `args` / `command` wrong:** apply **`SKILL.md`** Preamble check **#5** (`npx`, `["-y", "@testchimp/cli@latest", "mcp"]`).
   - **`env` missing keys:** ensure **`env`** includes **`TESTCHIMP_API_KEY`** and **`TESTCHIMP_PROJECT_ID`**. If a key already has a **non-placeholder** value, **preserve** it; only add missing keys or replace obvious placeholders.
   - **Placeholders (do not commit real secrets):**
     - `TESTCHIMP_API_KEY`: `PASTE_YOUR_PROJECT_API_KEY_HERE`
     - `TESTCHIMP_PROJECT_ID`: `PASTE_YOUR_PROJECT_ID_HERE`
   - After any write, **tell the user** they must paste the **project API key** and **project ID** from **TestChimp → Project Settings → Key management** into that file’s `env` block, then **reload MCP / restart the IDE**. **`TESTCHIMP_PROJECT_ID`** is not required for MCP tool calls (project is inferred from the API key) but **is required for TrueCoverage RUM instrumentation** — storing it here gives agents a single project-local source when wiring `testchimp.init()` / native RUM.
3. **Verify client + credentials** — Apply **`SKILL.md`** Preamble checks **#4** (`TESTCHIMP_API_KEY` resolvable; export for shell/Playwright per that item) and **#5** (CLI/MCP client version). If the key is still a placeholder, **stop** after informing the user (step 2); do not claim MCP is ready. When the key is real, re-check (e.g. MCP tool **`get-eaas-config`** must not return **401**).
   - **Inform platform (best-effort)** — Immediately after **`get-eaas-config`** succeeds (non-401), mint a fresh **ULID** and call MCP **`report-agent-action`** so the platform knows local-agent init ran:
     - `workflowId`: **`init`**
     - `workflowExecutionId`: the ULID
     - `actorType`: **`LOCAL_AGENT`**
     - `branchName`: current git branch
     - `entityType`: **`WORKFLOW`**
     - `entityIdentity`: **`init`** (must equal `workflowId`)
     - `actionType`: **`ACTION_COMPLETED`**
     - **Omit `userId`** — the MCP client injects it from **`TESTCHIMP_USER_ID`** in mcp.json `env` when present. Never print user ids or secrets.
     - **Omit** `policyFile` / `policyVersion` (init has no policy).
     - Failure of this report **must not** block the rest of init. Details: [`policies-and-traceability.md`](./policies-and-traceability.md).
4. **Seed composite policies (if missing)** — Ensure **`plans/knowledge/policies/`** exists under the mapped plans root. If **`run-qa.policy.md`** or **`upkeep.policy.md`** are absent, copy them from this skill’s [`../assets/policies/`](../assets/policies/) (do not overwrite existing team policies). See [`policies-and-traceability.md`](./policies-and-traceability.md).
5. **Gate: `connect-to-test-env` policy** — Before treating the environment as configured, confirm a usable **`connect-to-test-env`** policy exists (`plans/knowledge/policies/connect-to-test-env.policy.md` or matching frontmatter), **or** that **`## Environment Provision Strategy`** in `ai-test-instructions.md` is substantive enough to fall back. If neither exists, mark **Missing Config**, discuss with the user, and author/seed the policy ([`create-policy.md`](./create-policy.md)) — this is **blocking** for env-dependent work. Do **not** invent provision steps silently.
6. **Never skip** this block because **`ai-test-instructions.md`** exists or looks complete.

Only after the workstation gate passes (or is blocked only on user-supplied secrets) should you use **`ai-test-instructions.md`** to decide how much **project-level** Phase 1–3 work remains.

---

## Phase 0 - Quick smoke (optional but must be asked first)

### 0.1 Ask first

Complete the **[Workstation gate](#workstation-gate-always-first)** first. Then ask the user whether they want a quick smoke pass before full infra setup.

Use this explanation:

- Full init sets up enterprise QA infrastructure: TrueCoverage instrumentation, test-only **seed / teardown / read** endpoint discovery (full wiring often lands during **`/testchimp test`**), and branch-aware execution (including ephemeral environments) so E2E tests are done before PR merge with lower flakiness. Explain that TestChimp enables runtime intelligent steps for more reliable tests.
- This can be a larger cognitive investment, so quick smoke can provide immediate value first.

### 0.2 If user chooses quick smoke

Complete the **Playwright toolchain check** (**`SKILL.md`** Preamble check **#6**) first so **`npm install`** has been run at the correct package root. **Web:** **`@playwright/test` ≥ 1.59.0**. **Mobile:** install **mobilewright** + **`@mobilewright/test`** per [`mobilewright-smarttests.md`](./mobilewright-smarttests.md). Smoke authoring should prefer **real runner validation** (browser or device) when the environment allows.

Collaborate with the user to collect:

- **Web:** target URL to test; **mobile:** app build path / simulator or device target as needed,
- test authentication approach (credentials/session/token; never store secrets in git),
- a small set of critical verification flows.

Then:

1. Use **web:** browser/Playwright-driven exploration; **mobile:** device/emulator-driven runs per Mobilewright — to validate key flows.
2. Author **2-3 SmartTests** under the SmartTests root (directory containing `.testchimp-tests`).
3. **Web:** ensure tests demonstrate **`ai.act` / `ai.verify`** where they make sense (optionally **`ai.extract`**). **Mobile:** **no** ai-wright — use Mobilewright APIs and **`markScreenState`** only.
4. Follow patterns in [`write-smarttests.md`](./write-smarttests.md); for AI steps on web, [`ai-wright-usage.md`](./ai-wright-usage.md); for mobile, [`mobilewright-smarttests.md`](./mobilewright-smarttests.md).

Important prerequisite:

- If `.testchimp-tests` is missing, resolve plans/tests mapping first (see [Action item A - folder mappings and markers](#action-item-a---plans-and-tests-roots-testchimp-integrations)) before writing smoke tests.

### 0.3 After quick smoke

Prompt again: continue with full init setup?

- If **no**: record what was completed and what remains deferred in `plans/knowledge/ai-test-instructions.md`, then stop. Ask user to run `/testchimp init` when needed.
- If **yes**: continue to Phase 1.

Quick smoke by itself does **not** mean full init is complete. So do not write the init done marker file.

### Phase 0 completion gate (before Phase 1 — or before stopping if user declines full init)

Do **not** continue until **all** are satisfied (each **done** or **`N/A`** + one-line justification, recorded in `ai-test-instructions.md` and/or chat):

- [ ] **Quick smoke offered** — user was asked; choice recorded.
- [ ] **If smoke was accepted** — toolchain + smoke authoring steps **done**, or **`N/A`** + justification (e.g. blocked env).
- [ ] **Continue to full init?** — user answered; if **no**, deferrals/what-was-done written to `ai-test-instructions.md` and the run stops here; if **yes**, proceed to Phase 1.

---

## Phase 1 - Requirement gather phase (collect decisions + clarifications)

Before any infra implementation, the agent should first **discover what it can from the repo + local config**, then **report findings back to the user**. Only ask the user targeted clarifications when discovery is missing, ambiguous, or requires a deliberate choice.

Why this phase (quick education):
- Teams don’t usually know TestChimp’s infra expectations up front (mapped folders), so we front-load discovery to avoid rebuilding things that already exist.
- Idempotent seeding and **Playwright fixtures** (see [`fixture-usage.md`](./fixture-usage.md)) reduce “works on my machine” flakiness by aligning author-time and run-time data posture.
- For pre–PR-merge testing, isolated environments are necessary so agents validate against the exact PR-specific code/data they’re changing (otherwise they may author based on stale staging/main behavior).
- Environment strategy affects both CI behavior and the final `BASE_URL` resolution; setting it wrong usually breaks tests in CI, and choosing the wrong isolation level makes agent decisions inaccurate.

Do not start implementing mocking/env/truecoverage/CI until you have the user’s deliberate answers (or explicit acceptance of the agent’s proposed defaults) below.

**Do not** write or update `plans/knowledge/ai-test-instructions.md` (other than `## Init requirements`) until the user has answered in this conversation — **except** that the **[Workstation gate](#workstation-gate-always-first)** may (and should) be completed **before** those answers; workstation MCP/API-key setup does not wait on project-level Q&A.

**Project-level shortcut:** If **`ai-test-instructions.md`** is already substantively populated, treat Key Areas **3–6** (and similar) as **read-and-confirm** unless the user wants changes — but still run the **Workstation gate** and Key Area **1** marker / SmartTests root discovery.

### Key Area 1 — Basic TestChimp integration
- **Workstation subset:** MCP + API key expectations are defined in the **[Workstation gate](#workstation-gate-always-first)** above; do not skip them when `ai-test-instructions.md` exists in git.
- Agent discovery (report findings first):
  - Locate marker files on disk:
    - `.testchimp-plans` => plans root mapped
    - `.testchimp-tests` => SmartTests root mapped
  - Confirm the **SmartTests root** path (folder containing `.testchimp-tests`) for downstream key areas. **Existing Playwright classification and import strategy** are handled in [Key Area 2](#key-area-2--existing-playwright-suite--import-strategy).
- If either marker file is missing: ask the user to complete the minimum needed TestChimp Git integration + sync so marker files exist. **Also ask them to confirm:**
  - For **each** mapped folder (plans and tests, after mapping in TestChimp → Project Settings → Integrations), a **PR has been raised from the TestChimp platform** and **merged**, so the scaffold (including empty marker files) exists in the remote repo.
  - Their **local workspace has been updated** (e.g. `git pull` / sync) so they have pulled those PR changes. Markers only appear locally after the platform sync PRs are merged and the branch is up to date.
- The **[Workstation gate](#workstation-gate-always-first)** owns MCP file **create/merge**; Key Area 1 only confirms markers and re-validates MCP after the gate.
- If placeholders remain for **`TESTCHIMP_API_KEY`** or **`TESTCHIMP_PROJECT_ID`**: ask the user to paste both from **TestChimp → Project Settings → Key management** into the project MCP `env` block, reload MCP, then continue. Never commit real keys. Ensure **`get-eaas-config`** does not return **401** once the API key is set.

### Key Area 2 — Existing Playwright suite / import strategy

Why this area (quick education):

- Many repos are **not** greenfield: they already have Playwright specs, or specs live **outside** the mapped SmartTests folder. TestChimp needs an explicit **migration strategy** so Phase 2 plans the right moves and Phase 3 executes them **after approval**—see [`importing-existing-tests.md`](./importing-existing-tests.md).

Agent discovery (report findings first):

- Treat the folder containing `.testchimp-tests` as the **SmartTests root**.
- Scan for **`*.spec.{js,ts}`** only (not `*.test.*` — TestChimp uses **`*.spec.*`**), excluding **`setup/**`** and treating scaffold-only setup files as non-“suite” (e.g. `global.setup.spec.*` under `setup/` does not count as an existing e2e suite).
- Under that root, check **`playwright.config.*`** for **`@testchimp/playwright/reporter`** in `reporter` — if present, call out **prior SmartTests/TestChimp wiring** in findings.
- Classify: **greenfield** (no specs outside `setup/` beyond scaffold) vs **has existing Playwright** vs **dual-folder** (mapped SmartTests folder is empty/new but **`*.spec.{js,ts}`** exist elsewhere in the repo).

User choices (required when not greenfield, or when dual-folder / misaligned config):

- **Parallel SmartTests folder (gradual migration):** keep the mapped SmartTests root and **move specs and helpers over time** from a legacy Playwright folder; both may coexist until migration completes.
- **Retrofit in place:** adopt **`.testchimp-tests`**, `playwright.config.*`, **`@testchimp/playwright` reporter**, and **`import '@testchimp/playwright/runtime'`** inside the **existing** tree that already holds specs (see **Migration strategies** in [`importing-existing-tests.md`](./importing-existing-tests.md)).
- If legacy specs live **outside** the mapped folder: the plan must include **moving** them into the mapped folder on an agreed schedule **or** changing Git mapping—**plan in Phase 2**, **execute in Phase 3** after approval. Do **not** move files silently in Phase 1.
- **Runtime import (mandatory for imported specs):** Any **`*.spec.{js,ts}`** that is part of the SmartTests suite after import must include **`import '@testchimp/playwright/runtime'`** at the top of the file—required for TrueCoverage (test-side), **`ai-wright`** steps, and reporter integration. See [Required: runtime import in every spec file](./importing-existing-tests.md#required-runtime-import-in-every-spec-file) in [`importing-existing-tests.md`](./importing-existing-tests.md).

**Greenfield:** state N/A briefly; no import tasks beyond normal harness scaffold in Phase 2/3.

### Key Area 3 — Mocking (Playwright `page.route` + optional AIMock)

Why this area is placed here (quick education):

- **HTTP/API** mocking uses Playwright’s native **`page.route`** by default (no MSW install as a TestChimp default). **LLM** mocking via **AIMock** is **optional** and must be **explicitly chosen** by the user during init—see [`mocking_strategy.md`](./mocking_strategy.md).

**Defaults note (prefer over lengthy questioning):** Assume **`page.route`** for HTTP/API doubles when needed during later create-tests / test flows, and **AIMock only when the stack has LLM traffic and the user wants cost control**. Detailed Mocking Plan questioning is **optional**—skip deep discovery when the user is fine with defaults; still allow a short opt-in/defer for AIMock if relevant.

Agent discovery (report findings first; keep light unless user asks for depth):

- Whether specs or helpers already use **`page.route`** / **`context.route`** for HTTP interception.
- Whether **AIMock** (`@copilotkit/aimock` / `aimock` CLI per [upstream docs](https://github.com/CopilotKit/aimock)) or similar is already present.
- How **LLM / OpenAI-compatible** calls are resolved (hardcoded URL vs `OPENAI_BASE_URL` / SDK defaults) in frontend, backend, or shared packages.
- Whether **`<SmartTests root>/assets/goldens`** exists (or another agreed path for AIMock fixtures).

**Optional user question (AIMock):** Ask whether the user wants **AIMock** set up during this init so LLM interactions in the stack are **mocked during tests** (record/replay when feasible). Tell them they can **defer** and ask to set it up when needed; also state that **AIMock is highly recommended** when LLM calls are in the test path because it **removes ongoing LLM usage costs**. Record the choice (**yes / later / not applicable**—e.g. no LLM in scope). If skipped, record **`### Mocking Plan`** with defaults: `http_mocking: page.route as needed`, `aimock: deferred`.

Authoritative reference: [`mocking_strategy.md`](./mocking_strategy.md).

Agent stance (preferred behavior):

- **Phase 1:** Summarize findings lightly and lock **`http_mocking`** and **`aimock`** under `### Mocking Plan` per [`mocking_strategy.md`](./mocking_strategy.md) (defaults OK). Do **not** install or wire AIMock unless the user opts in (**yes**) or the plan explicitly schedules it; if **later**, record **deferred** with reason.
- **Phase 3:** Document or add **`page.route`** patterns as agreed. **Only if AIMock was enabled:** install AIMock, create `assets/goldens` when needed, refactor OpenAI-compatible URLs into **config/env** for tests, and document local + CI runs—per [`mocking_strategy.md`](./mocking_strategy.md) and vendor AIMock docs.

### Key Area 4 — TrueCoverage Infra (RUM + journey events)

**Native mobile:** If **`.testchimp-tests`** is **`mobile`** or **`multi-platform`** (legacy **`ios`/`android`** → mobile), Key Area 4 applies to the **native app**: wire **TestChimpRum**, URL scheme / intent filter, **`mobile/fixtures/index.js`** with **`installTestChimp(..., { uiFixture: 'screen' })`**, and **`use.platform`** on UI config projects ([`instrument-truecoverage.md`](./instrument-truecoverage.md), [`mobilewright-smarttests.md`](./mobilewright-smarttests.md)). Explicit opt-out under **`### TrueCoverage Plan`** → skip with rationale.

Why this area (quick education):
- TrueCoverage is extremely useful because it turns **production behavior** into **real coverage gaps**: what users actually do (features people engage with, where they spend time, where they drop off, and top-of-funnel vs later behavior, funnel flows etc.).
- Those signals are exposed through data APIs that are consumed via MCP by AI agents to identify critical gaps and to drive coverage improvements, and exploratory testing for UX issue identification, in a tight feedback loop.
- We still start with a minimal, consistent event slice so the initial setup is fast and stable, but the data remains actionable (not just noisy).
- Agent discovery (report findings first):
  - Check `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` for whether TrueCoverage is **enabled now**, **deferred**, or **disabled** (and for any prior instrumentation decisions).
  - Check whether **TrueCoverage RUM is already wired in the app codebase** (report as a finding either way):
    - **Web — dependency:** e.g. `@testchimp/rum-js` in the frontend / app `package.json` (and lockfile where present), not only under the SmartTests package.
    - **Web — usage:** imports or calls from `@testchimp/rum-js` and/or **`testchimp.init`** / **`testchimp.emit`** (or a thin wrapper) in application source.
    - **iOS — dependency:** `TestChimpRum` in Xcode SPM or `Package.swift`.
    - **iOS — usage:** `TestChimpRum.initialize` / `emit` / `handleAutomationURL` (or equivalent) in app source.
    - **Android — dependency:** JitPack `com.github.testchimphq:testchimp-rum-android:<tag>` with `maven("https://jitpack.io")` (see [JitPack](https://jitpack.io/#testchimphq/testchimp-rum-android)), or `io.testchimp:rum-android` on Maven Central when published, or local `:testchimp-rum` module.
    - **Android — usage:** `TestChimpRum.initialize` / `emit` / `handleAutomationIntent` (or equivalent), plus intent filter for `testchimp-rum://truecoverage/...` if automation is required.
    - If **dependency and usage are already present for this platform**, **call this out explicitly** in discovery findings (e.g. “RUM SDK installed and referenced for emits—init can focus on gaps vs `truecoverage-instrument-progress`, not greenfield wiring”). Optionally ask the user whether to **plan additional events** to instrument (expand `plans/knowledge/truecoverage-instrument-progress.md` and follow the `plans/events/` vs `plans/knowledge/` rules) versus only documenting what already exists.
  - Check `plans/knowledge/truecoverage-instrument-progress.md` (if present) for planned vs done events; optionally list existing `plans/events/*.event.md` files (these document **instrumented** event types only—see below).
- **Decision policy** (downstream `/testchimp test` / evolve behavior is also spelled out in [`instrument-truecoverage.md`](./instrument-truecoverage.md) → *Project decision*):
  - **Explicit opt-out / disabled** under `### TrueCoverage Plan` → complete discovery above; **skip** new RUM wiring unless the user reverses the decision.
  - **Any other state** (missing section, empty, deferred, enabled, or user re-opening the choice) → TrueCoverage stays **in scope**. **Init locks enablement only:** record **Yes now**, **Later** (defer), or **No** where **No** is **only** a **persisted explicit opt-out**—not “we never discussed it.” **Defer** is a **schedule snooze**, not an opt-out for later test flows.
- **Phase 3 — enablement lock (not full instrument):** Persist the choice under `### TrueCoverage Plan`. If **Yes now**, **do not** expand init into a full event-instrumentation campaign—tell the user the **next step is `/testchimp instrument`** (and/or `/testchimp setup truecoverage` for greenfield wiring depth). Optionally note whether basic RUM SDK deps already exist. Keep harness/deps/scaffold elsewhere in init; deep emit lists and `plans/events/*.event.md` belong to the instrument flow. Historical detail below remains as reference if the user explicitly asks to wire RUM during this init.
- **Phase 3 — implement RUM** *(only when the user explicitly wants wiring in this init pass, or residual unfinished scaffold)* when the recorded choice is **Yes now** and they opt into init-time wiring (**not** the default path—prefer **`/testchimp instrument`**):
  - set up **basic wiring** and instrument a **small initial event slice** (and create `plans/events/*.event.md` only for events actually instrumented), and
  - generate `plans/knowledge/truecoverage-instrument-progress.md` so the rest can be completed incrementally via `/testchimp instrument` (and/or during `/testchimp evolve`). See [`instrument-truecoverage.md`](./instrument-truecoverage.md). For evolve cadence and persisted evolve plans, see [`upkeep.md`](./upkeep.md).
  - **References:** [`references/instrument-truecoverage.md`](./instrument-truecoverage.md); **[@testchimp/rum-js on GitHub](https://github.com/testchimphq/testchimp-rum-js)**; **[testchimp-rum-ios](https://github.com/testchimphq/testchimp-rum-ios)**; **[testchimp-rum-android](https://github.com/testchimphq/testchimp-rum-android)**.
  - Confirm **`projectId`**, **`apiKey`**, and **`environment`** go to the **app runtime** (web: `testchimp.init({ projectId, apiKey, environment, ... })`; native: `TestChimpRum.initialize` with the same credentials pattern your stack uses—e.g. `BuildConfig` / plist on Android/iOS). **`environment`** must be **explicitly mapped** (SDKs do **not** read `TESTCHIMP_ENV` from the test process); document parity with SmartTests **`.env-*` / `TESTCHIMP_ENV`** or deliberate splits—see **[RUM environment tag](./instrument-truecoverage.md#rum-environment-tag-truecoverage-analytics-alignment)** in [`instrument-truecoverage.md`](./instrument-truecoverage.md). Do **not** put app secrets in `.env-QA` under the SmartTests root (`BASE_URL` lives there).
  - **Minimal instrumentation slice** (agent stance):
    - Helper wrapper location: pick (or create) a single app-runtime module dedicated to TrueCoverage emits in the **app under test** (web frontend, iOS target, or Android app module)—**not** inside the SmartTests root. Prefer an existing telemetry/analytics module if one exists; otherwise create a dedicated file. **Web:** call **`testchimp.init()` once**, then **`emit()`**. **Native:** call **`TestChimpRum.initialize` once**, then **`emit()`** (see platform READMEs).
    - **Sampling / volume:** Controlled by the SDK **`config` / `Options`** on init—see **[@testchimp/rum-js README](https://github.com/testchimphq/testchimp-rum-js)** (web) and the native package READMEs; [`instrument-truecoverage.md`](./instrument-truecoverage.md) summarizes knobs. For the first slice, prefer **conservative** limits; reuse any existing tuning in the repo/env when present; only introduce new limits when none exist.
    - Basic events to instrument (minimal, stable set):
      - **Semantic journey completion milestones** (good examples: `add-to-cart`, `checkout-completed` / `checkout`, `order-confirmed`; bad examples: “click button”, “click next”)
      - at least one **high-signal error variant** for a key journey step (good examples: `checkout-failed`, `checkout-validation-error`; avoid generic “ui_error” noise)
      - keep event names consistent with your app’s existing analytics vocabulary if you already have one; otherwise use kebab-case semantic steps
      - only add technical noise (page_view/route changes, raw API success/failure) if you cannot identify any user-journey milestones in the product
    - Event plan locking (folder contract):
      - **`plans/knowledge/`** — maintain the **full TrueCoverage plan**: planned vs not-yet-instrumented events, route/page breakdown, and rollout progress. Required: `plans/knowledge/truecoverage-instrument-progress.md`; summarize decisions and vocabulary under `### TrueCoverage Plan` in `plans/knowledge/ai-test-instructions.md` so Phase 3 doesn’t drift.
      - **`plans/events/`** — **only** `*.event.md` files (one per **instrumented** event type, frontmatter per [`instrument-truecoverage.md`](./instrument-truecoverage.md)). Do **not** put “planned but not wired” events here; those stay in the knowledge progress tracker until `/testchimp instrument` lands them.
      - wire the helper wrapper so it emits the identified minimal **instrumented** events (SmartTests should exercise the paths that trigger those emits).
    - Full plan + progress tracking (required during init when TrueCoverage is enabled): create/update `plans/knowledge/truecoverage-instrument-progress.md` (details in [`instrument-truecoverage.md`](./instrument-truecoverage.md)).

### Key Area 5 — Environment provision strategy (persistent vs ephemeral / EaaS)
Why this area (quick education):
- The key benefit of **ephemeral, pre–PR-merge environments** is **shift-left QA**: tests run against the exact PR-specific code/data stack, not stale staging/main.
- For agentic testing, isolated envs are crucial for **accurate reasoning** because agents can validate against the PR’s real behavior (deterministic inputs, fewer “it changed after merge” surprises).
- This also makes failures more explainable: when an isolated environment is used, the test environment context matches the PR diff.
- Persistent vs ephemeral still changes how CI is structured and how `BASE_URL` is resolved per PR, and ephemeral setups require additional provisioning steps (EaaS/Bunnyshell or another ephemeral mechanism).
- **Policy overlay:** Persist the agreed strategy in `ai-test-instructions.md` **and** prefer a **`plans/knowledge/policies/connect-to-test-env.policy.md`** (author from those decisions if missing — [`create-policy.md`](./create-policy.md)). Workstation gate treats connect-to-test-env policy as **required** before env is “configured.”
- Agent discovery (report findings first):
  - Inspect local CI/workflows and env files to see whether a `BASE_URL` (or a preview URL convention) already exists.
  - If ephemeral env tooling is present in the repo, note it as a candidate path.
- Local environment provisioning contract (must be explicit for later agents):
  - During init, persist in `plans/knowledge/ai-test-instructions.md` under `## Environment Provision Strategy` → `### Local - Test Authoring`:
    - a **single agent-runnable command** (or script entrypoint) to bring the stack up locally (prefer Docker Compose; if multiple prerequisites exist, prefer a single wrapper script entrypoint like `scripts/qa/local-up.sh`)
    - an explicit **wait-for-healthy** definition (health endpoints, compose healthchecks, ports, etc.) so later `/testchimp test` can do: provision → wait healthy → proceed
    - the resulting URLs and how they map to test variables (`BASE_URL`, `BACKEND_URL`, any `*_SERVICE_BACKEND_URL` used by fixtures and seed helpers)
  - If the stack is too complex to run locally, record that and use EaaS for author-time instead (with a “provision and wait” MCP tool preference).
- Where will automated E2E run for PRs? (pick what matches; user can combine)
  - Preview/deploy preview URL + shared backend (typical frontend PRs), and/or
  - Ephemeral full-stack environments per branch/PR (backend or data isolation), and/or
  - Discouraged fallback: persistent stage (`BASE_URL` in `.env-*`) with little or no PR-time E2E.
- If ephemeral: are you using (or planning) Bunnyshell with TestChimp? (yes / no / not sure). If the repo discovery/MCP EaaS hints are missing, ask the connection question; otherwise report what you found.
- If PR previews matter: do you rely on TestChimp Branch Management URL template/overrides for PR-specific `BASE_URL`, or fixed env files only?

### Key Area 6 — CI setup
- Agent discovery (report findings first):
  - Check whether `.github/workflows/` (or equivalent) already has Playwright/TestChimp-related CI.
  - Relate findings to **greenfield vs existing Playwright vs dual-folder** (see [`importing-existing-tests.md`](./importing-existing-tests.md)): e.g. existing workflows may `cd` to the wrong folder or omit `TESTCHIMP_API_KEY`.
- If discovery finds existing Playwright/TestChimp CI: report what it looks like (including whether it **`cd`**s into the **mapped SmartTests folder** and sets **`TESTCHIMP_API_KEY`**) and ask whether to reuse/adjust it.
- Otherwise: ask what CI system to use (GitHub Actions / others), whether it runs on PRs vs main, and whether it should start with shared/persistent envs or provision ephemeral envs per run.
- **Detail reference:** [`importing-existing-tests.md`](./importing-existing-tests.md) (cwd, env, alignment with mapped folder).

### Phase 1 completion gate (before Phase 2 — plan drafting)

Do **not** open Phase 2 until **all** are satisfied (each **done** or **`N/A`** + one-line justification):

- [ ] **Workstation gate** — completed on this run (not inferred from git).
- [ ] **Key Area 1** — markers / SmartTests root **discovered and reported** (or **blocker** + owner recorded).
- [ ] **Key Area 2** — suite classification + user’s import/migration stance (or **greenfield `N/A`** + justification).
- [ ] **Key Area 3** — Mocking stance recorded (defaults OK: `page.route` + AIMock when needed; deep questioning optional) + **`### Mocking Plan`** ready for Phase 2 (or explicit deferral + reason).
- [ ] **Key Area 4** — TrueCoverage **enablement** locked (**Yes now** / **Later** / explicit opt-out); if **Yes now**, next-step **`/testchimp instrument`** noted (empty section counts as “not decided,” not opt-out).
- [ ] **Key Area 5** — environment strategy **decided enough** + **`connect-to-test-env`** policy gate satisfied (or Missing Config + authoring plan) for Phase 2.
- [ ] **Key Area 6** — CI discovery + intended direction recorded for Phase 2.

---

## Phase 2 - Plan phase (draft the 6-area execution checklist)
Why this phase (quick education):
- The plan prevents the agent from drifting across infra choices by forcing a small, explicit checklist with acceptance criteria.
- It also ensures decisions land in `plans/knowledge/ai-test-instructions.md` so Phase 3 execution stays consistent.

Create a shared action list with status and notes in `plans/knowledge/ai-test-instructions.md` under an init-specific section (for example: `## Init action items`).

Each action item must include:
- `status`: `pending | in_progress | done | skipped | deferred`
- concise notes (decisions, blockers, links, trade-offs)

Your plan MUST include exactly these **6** key areas in this order (each starting with `pending`), and for each include the acceptance criteria:

1. Basic TestChimp integration
2. Existing Playwright suite / import strategy (use **skipped** or minimal notes when **greenfield**)
3. Mocking (Playwright `page.route` + optional AIMock)
4. TrueCoverage Infra
5. Environment provision strategy
6. CI setup

**Note:** Detailed **seed/teardown/read** endpoints and **`fixtures/`** ([`fixture-usage.md`](./fixture-usage.md)) are authored during **`/testchimp create tests`** / **`/testchimp test`** (`run-qa`) when scenarios require them—not a separate init gate. Init **does** keep harness / deps / Playwright or Mobilewright config / scaffold from templates.

Acceptance criteria (success checks):
- Basic TestChimp integration
  - invoke an MCP command (e.g. `get-eaas-config`) to ensure it is not returning `401 Unauthorized`
  - there are 2 folders with the `.testchimp-plans` and `.testchimp-tests` marker files
  - Playwright/Mobilewright harness layout per template (`setup` / `e2e` / `api` projects as applicable); fixture barrels may be stubbed—**fixture authoring** lands during create-tests / test flow
  - composite policies seeded under `plans/knowledge/policies/` when missing; **`connect-to-test-env`** policy or ai-test-instructions env strategy present (gate)
- Existing Playwright suite / import strategy
  - when **not** greenfield: explicit tasks for moves/config/reporter/**`import '@testchimp/playwright/runtime'` on every `*.spec.{js,ts}`** in the mapped SmartTests tree per [`importing-existing-tests.md`](./importing-existing-tests.md) and the user’s **parallel-folder vs retrofit** choice from Phase 1
  - when **greenfield**: marked **skipped** or **N/A** with a one-line note
- Mocking (Playwright `page.route` + optional AIMock)
  - `### Mocking Plan` in `plans/knowledge/ai-test-instructions.md` records **`http_mocking`** and **`aimock`** per [`mocking_strategy.md`](./mocking_strategy.md)
  - **`page.route`** stance documented (or deferred/N/A); **AIMock** only if user opted in—then dependencies and wiring per [`mocking_strategy.md`](./mocking_strategy.md); `<SmartTests root>/assets/goldens` when AIMock is in scope; LLM traffic can be aimed at AIMock via agreed env/config; brief local vs CI notes
  - if AIMock **deferred** or **not applicable**: explicitly recorded with reason
- TrueCoverage Infra
  - enablement locked under `### TrueCoverage Plan` (**Yes now** / **Later** / explicit opt-out)
  - if **Yes now**: next-step pointer to **`/testchimp instrument`** recorded (full `truecoverage-instrument-progress.md` / `plans/events/` wiring may wait for that command unless user explicitly requested init-time wiring)
  - if init-time wiring was explicitly requested: `plans/knowledge/truecoverage-instrument-progress.md` exists with planned vs done; for each event type **actually instrumented**, a matching `plans/events/<title>.event.md` exists per [`instrument-truecoverage.md`](./instrument-truecoverage.md)
- Environment provision strategy
  - depends on the decision, and `ai-test-instructions` contains the user agreed-upon decision AFTER it has been discussed
  - for **Local - Test Authoring**, `ai-test-instructions` includes a single runnable “local up” command/script **and** explicit “wait until healthy” criteria (so agents can reliably provision and wait before testing)
- CI setup
  - CI action authored

After the plan is written, ask the user to explicitly approve or request edits. Only after approval proceed to Phase 3. Phase 3 executes **Key Area 2** import/alignment tasks (moves, config fixes, reporter/runtime wiring) **only** after approval, when the plan included them.

### Phase 2 completion gate (before Phase 3 — execution)

Do **not** start Phase 3 until **all** are satisfied:

- [ ] **`plans/knowledge/ai-test-instructions.md`** contains the **six-area** init checklist with **`status`** + notes per item (or equivalent traceability).
- [ ] **Acceptance criteria** from Phase 2 are present for each area (what “done” means in Phase 3), or the area is **`N/A`** + justification.
- [ ] **User explicitly approved** the plan (chat or documented).

---

## Phase 3 - Execution phase (execute key areas in order)
Why this phase (quick education):
- Executing item-by-item ensures each success check is actually met (so CI/TrueCoverage failures happen for the right reason, not because a prerequisite was skipped).
- It also produces a clear progress narrative for you: what was completed and what remains deferred.

Work item-by-item from the agreed checklist and update `plans/knowledge/ai-test-instructions.md` after each completion, skip, or deferral.

If the approved plan included **moving** specs into the mapped SmartTests folder or **upgrading** an existing Playwright tree to TestChimp structure, perform those steps here (action **K**) in line with [`importing-existing-tests.md`](./importing-existing-tests.md).

Use the following action-item playbooks as implementation references.

### PR strategy (before you push)

Init touches a lot of surface area. **By default**, prefer **separate PRs** for the heavier slices so review and rollback stay manageable: **TrueCoverage infra**, **CI**, **mocking**, and **import/alignment** (each as its own PR when large).

**Ask the user explicitly:** do they want **one combined PR** or **separate PRs**? Execute and branch/push accordingly; do not assume a single mega-PR.

Execute the **6** key areas in this order and treat them as grouped action-item blocks:
- **Basic TestChimp integration + test harness:** actions A–F (markers, deps, config, MCP, scaffold layout per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — `setup`, `e2e` or `web/e2e` + `mobile/e2e`, `api/`, fixture barrels — see [`fixture-usage.md`](./fixture-usage.md))
- **Existing suite import / alignment (when planned):** action K—skip when greenfield / N/A
- **Mocking:** action J ([`mocking_strategy.md`](./mocking_strategy.md))
- **TrueCoverage Infra:** action I
- **Environment provision strategy:** action G
- **CI setup:** action H

After each key area group is completed, verify that its success check is met and update the action item statuses in `plans/knowledge/ai-test-instructions.md`.
After marking a key area as `done`, communicate the success milestone to the user in chat.

### Action item A - Plans and tests roots (TestChimp integrations)

**How TestChimp uses the repo (agent-relevant model):**

- **Plans root**: scenario/story markdown synced from TestChimp; agents read these to drive test authoring.
- **Tests root**: SmartTests + Playwright harness; all automation authored here.

Search for marker files:

- `.testchimp-plans` => plans root
- `.testchimp-tests` => SmartTests root

If markers are missing:

1. Ask the user to connect the repo in TestChimp → Project Settings → Integrations → Git.
2. Map **both** plans and tests folders (each mapping corresponds to one root that will get a marker).
3. From the TestChimp platform, **raise the sync PR(s)** for each mapped folder so the scaffold and **empty marker files** (`.testchimp-plans`, `.testchimp-tests`) are created on the remote.
4. Ask the user to **merge those PRs** (or ensure they are merged) and then **update the local workspace** (`git pull` / equivalent) so the merged changes—including the markers—are present locally. Without merge + local pull, markers will still be missing on disk.

Platform path note: MCP APIs use platform-rooted paths (`plans/...` or `tests/...`) even if repo folder names differ.

**`project_type` in `.testchimp-tests`:** Read the marker file. **Empty** → **web**. **`mobile`** or legacy **`ios`/`android`** → mobile scaffold. **`multi-platform`** → both configs + `web/` + `mobile/` + `api/`. Full tree: [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md). Record detected type in **`plans/knowledge/ai-test-instructions.md`** when useful.

Success check (Basic TestChimp integration - markers): both `.testchimp-plans` and `.testchimp-tests` marker files exist.

### Action item B - Dependencies (Node / Playwright)

**Web (default):** SmartTests require **`@playwright/test`** / **`playwright`** at **`>= 1.59.0`** (**`SKILL.md`** Preamble **Playwright toolchain check** — verify install root and semver before relying on the runner).

**Mobile:** Install **`mobilewright`**, **`@mobilewright/test`**, and **`@testchimp/playwright`**. Keep **`mobilewright`** and **`@mobilewright/test`** on the **same** version ([`mobilewright-smarttests.md`](./mobilewright-smarttests.md)).

Run installs from the directory containing `.testchimp-tests` (or the monorepo package root that owns test deps, if tests are nested):

```bash
npm install @testchimp/playwright
npm install -D @testchimp/cli@latest
```

**Mobile — additionally:**

```bash
npm install mobilewright
npm install @mobilewright/test
```

Use **`@latest`** for the dev dependency so installs track the current default npm release. The MCP entry should use **`npx`** with **`["-y", "@testchimp/cli@latest", "mcp"]`** in **`args`** (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)); that ensures **`npx`** resolves the latest published client when the MCP server starts.

### Action item C - Environment variables

Local (agent runtime / MCP config):

- set `TESTCHIMP_API_KEY` and `TESTCHIMP_PROJECT_ID` in MCP server `env` (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)),
- keep config project-scoped, not global.

CI:

- set `TESTCHIMP_API_KEY` in the git provider secrets,
- ensure Playwright runner executes from the tests root.

### Action item D - Playwright config

**Web:**

- Keep `playwright.config.js` directly in the SmartTests root (folder with `.testchimp-tests`).
- Enable `@testchimp/playwright`, retain-on-failure trace, screenshots on failure.
- Use [`../assets/template_playwright.config.js`](../assets/template_playwright.config.js) as baseline.

**Mobile:**

- Use **`mobilewright.config.ts`** in the SmartTests root. Start from [`../assets/template_android_mobilewright.config.ts`](../assets/template_android_mobilewright.config.ts) or [`../assets/template_ios_mobilewright.config.ts`](../assets/template_ios_mobilewright.config.ts) matching **`project_type`**. Set **`bundleId`** and **`installApps`** to real artifact paths (APK / IPA / local simulator build — see Mobilewright docs).
- For CI with **mobile-use**, set **`MOBILE_USE_API_KEY`**; document that in **`ai-test-instructions.md`** ([`environment-management.md`](./environment-management.md)).

### Action item E - MCP install (project-scoped; all hosts)

Register **`@testchimp/cli`** in the **project** MCP config (not global user config). Follow the **[Workstation gate](#workstation-gate-always-first)** — create **`.cursor/mcp.json`**, **`.mcp.json`**, or the host equivalent from [`../assets/sample-mcp.json`](../assets/sample-mcp.json) when missing; merge the **`testchimp`** server when the file exists without it.

- Use **`command`:** **`npx`** and **`args`:** **`["-y", "@testchimp/cli@latest", "mcp"]`** so each run resolves the latest npm release and starts the MCP server.
- Put **`TESTCHIMP_API_KEY`** and **`TESTCHIMP_PROJECT_ID`** in the server **`env`** block (placeholders until the user pastes real values from TestChimp → **Project Settings** → **Key management**). Export the **same API key** in the **shell** when running **`npx playwright …`**. **Do not** put these secrets in **`.env-QA`** — that file is for **test execution** env (e.g. **`BASE_URL`**).
- After changing MCP config, the user should **reload MCP or restart the IDE** so the new **`npx`** arguments apply.
- Success check (Basic TestChimp integration): invoke `get-eaas-config` via the MCP client and ensure it does **not** return `401 Unauthorized` (and returns a non-empty config payload). Then best-effort **`report-agent-action`** for workflow **`init`** as in the [Workstation gate](#workstation-gate-always-first) (do not block on report failure).

After install, MCP tools can be used for:

- requirement coverage,
- execution history,
- environment provisioning and endpoint resolution,
- TrueCoverage analytics.

### Action item F - Test harness setup (`setup`, `e2e`, `api`, `fixtures`)

**Web** target structure inside SmartTests root:

- `setup`: global setup / project dependencies (see template [`template_playwright.config.js`](../assets/template_playwright.config.js)),
- `e2e`: UI-focused tests,
- `api`: API-focused tests (optional project),
- **Fixture barrels** (per scaffold): **`fixtures/index.js`** (web-only), **`api/fixtures/index.js`**, **`mobile/fixtures/index.js`** (`installTestChimp(..., { uiFixture: 'screen' })`), **`web/fixtures/index.js`** (multi-platform). Each wraps **`mergeTests`** with **`installTestChimp`**. See [`fixture-usage.md`](./fixture-usage.md), [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md).

**Mobile / multi-platform:** **`@mobilewright/test`** in **`mobile/fixtures`**; **`mobilewright.config.ts`** with **`use.platform`** on UI projects. Native RUM per [`instrument-truecoverage.md`](./instrument-truecoverage.md) unless opted out.

Platform OOBE / backfill may create **`fixtures/index.js`**; if it is missing locally, merge the platform sync PR or run the documented backfill before marking **done**. Full **domain fixture** and **seed endpoint** implementation usually lands during **`/testchimp test`** when scenarios require it.

During init, **discover** whether test-only seed/teardown/read routes already exist (see [`seeding-endpoints.md`](./seeding-endpoints.md)) and **record** findings in `plans/knowledge/ai-test-instructions.md` for later test authoring. Do **not** block init on authoring every endpoint or domain fixture module.

Success check (Test harness): SmartTests root matches the chosen scaffold ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)); required fixture barrel(s) exist after platform sync / backfill; no `world-states` path required.

### Action item K - Import / align existing Playwright suite (when planned)

Read `plans/knowledge/ai-test-instructions.md` for Key Area 2 decisions and follow [`references/importing-existing-tests.md`](./importing-existing-tests.md).

- If Phase 2 marked this area **skipped** / **N/A** (greenfield), mark action K **skipped** and do not move files.
- Otherwise: perform the **approved** moves, config path fixes, `@testchimp/playwright` reporter + deps, and scaffold folders / fixture barrels as listed in the init plan—**only** after user approval.
- **Every** executable **`*.spec.{js,ts}`** / SmartTest under the mapped tree must import **`test` and `expect` only** from **`fixtures/index.js`** (relative path from the spec file)—never the root **`test`** from **`@playwright/test`** or **`@mobilewright/test`** in spec files. TestChimp runtime hooks (**`markScreenState`**, ExploreChimp when enabled; TrueCoverage test identity on **web** and automation URLs on **mobile** when wired) live on the merged `test` via **`installTestChimp`** in that master file; see [`importing-existing-tests.md`](./importing-existing-tests.md#required-fixtures-first-imports-in-spec-files).

Success check (Import strategy):

- SmartTests root matches the agreed strategy (**parallel-folder** migration state or **retrofit** complete to the extent planned); `npx playwright test` from the mapped folder is the canonical command; platform path expectations in [`importing-existing-tests.md`](./importing-existing-tests.md) are satisfied.
- **Every** in-scope **`*.spec.{js,ts}`** imports **`{ test, expect }`** from the correct relative **`fixtures/index.js`** (verify with a repo search before marking **done**). Legacy per-spec **`import '@testchimp/playwright/runtime'`** is optional once **`installTestChimp(mergeTests(...))`** is applied in **`fixtures/index.js`**.

### Action item J - Mocking (Playwright `page.route` + optional AIMock)

Read `plans/knowledge/ai-test-instructions.md` under `### Mocking Plan` and follow [`references/mocking_strategy.md`](./mocking_strategy.md).

- Document or implement **`page.route`** / **`context.route`** patterns (helpers or fixtures) as agreed—**do not** install MSW by default.
- **Only if the user opted into AIMock** in Phase 1 (and the plan says **enabled**): install **AIMock** per [upstream documentation](https://github.com/CopilotKit/aimock) (package / CLI as appropriate for the repo).
- Add **`<SmartTests root>/assets/goldens`** when AIMock record/replay is in scope; align AIMock config with that path.
- Refactor **OpenAI-compatible base URL** (and related client config) so tests can point LLM traffic at the AIMock listener when AIMock is enabled (commonly `OPENAI_BASE_URL` or the project’s existing env name — document which).
- When AIMock is enabled: ensure it can run **during test execution** locally (e.g. global setup, compose sidecar, or documented `npx` command) and note what CI should do (e.g. official AIMock GitHub Action or equivalent — follow vendor docs).
- Summarize **what was wired and where** for the user.

If **AIMock** is **deferred** or **not applicable**: mark AIMock portions skipped; still ensure `### Mocking Plan` reflects **`http_mocking`** and **`aimock`** outcomes.

Success check (Mocking):

- `### Mocking Plan` reflects **`http_mocking`** and **`aimock`**; if AIMock enabled, goldens path + env wiring exist and are documented for local runs; CI path noted when CI is in scope (final CI wiring may complete in action H).

### Action item I - TrueCoverage setup

Execute **[Key Area 4 — TrueCoverage](#key-area-4-truecoverage-infra-rum-journey-events)** in Phase 1–3 and follow [`instrument-truecoverage.md`](./instrument-truecoverage.md). Read / update `### TrueCoverage Plan` in `ai-test-instructions.md`.

When the user must pick timing (no **explicit opt-out** yet), persist one of—meanings align with Key Area 4 **Decision policy**:

- **Yes now**: Lock enablement under `### TrueCoverage Plan`, then **end init’s TrueCoverage work** with a clear **next step: `/testchimp instrument`** (and setup docs if RUM deps are absent). Do **not** require full emit instrumentation inside init.
- **Later**: record **deferred** under `### TrueCoverage Plan`; point user to `/testchimp setup truecoverage` / `/testchimp instrument` for follow-up.
- **No**: **only** as **persisted explicit opt-out** under `### TrueCoverage Plan` with a short rationale.

Success check (TrueCoverage Infra):

- Enablement choice is persisted (not silent/undecided).
- If **Yes now**: user was told to run **`/testchimp instrument`** next (unless they explicitly asked for init-time wiring and it was completed—then `truecoverage-instrument-progress.md` + instrumented `plans/events/*.event.md` as before).
- If **Later** or **explicit opt-out**: plan file reflects that choice.

### Action item G - Environment strategy

Load [`references/environment-management.md`](./environment-management.md).

Choose where tests run:

- **PR pre-merge (recommended)**:
  - branch-specific preview URL with shared backend, or
  - full isolated ephemeral environment (often preferred for backend changes).
- **Discouraged fallback (explicit choice only):**
  - persistent stage environment using `BASE_URL` in env files (typically `.env-QA` under the tests root).

For ephemeral strategy with Bunnyshell, instruct user to configure TestChimp -> Project Settings -> Integrations -> Bunnyshell.
If using custom PR environments, configure Branch Management URL template/overrides.

Success check (Environment provision strategy):
- depends on the decision, and `ai-test-instructions` contains the user agreed-upon decision AFTER it has been discussed
- if persistent env: agent knows the persistent URL to use in tests, and can access it
- if persistent backend + preview frontend PR isolated (local or preview-url): agent can spin up preview-url / local correctly
- if fully isolated ephemeral envs: `get-eaas-config` returns non-empty result and agent can spin up an environment successfully (using TestChimp MCP)

### Action item H - CI behavior

- Run from tests root with required env vars.
- Pass PR/stage URL via `BASE_URL`.
- If **AIMock** was enabled in action J, align CI with the documented AIMock approach (e.g. GitHub Action or `npx` per [`mocking_strategy.md`](./mocking_strategy.md) / vendor docs).
- If using PR-triggered runs, exclude TestChimp plan sync PRs with title `TestChimp Platform Sync [Plans]`.

Success check (CI setup):
- CI action authored (and wired to the selected environment strategy for `BASE_URL` / provisioning).

---

## Detailed execution reference (do not skip)

Use this section when an action item needs deeper decisions. Keep the phased workflow above as the control flow, and use these details as implementation depth.

### Plans/tests integration model details

How TestChimp expects repository wiring:

| Integration type in TestChimp | Workflow role | Typical repo contents |
|------------------------------|---------------|-----------------------|
| **Plans** | Source of truth for scenarios/stories synced from platform; agents read this before writing tests | `.md` stories/scenarios with `#TS-...` ids |
| **Tests** | SmartTests + Playwright harness where humans and agents author automation | `*.spec.ts`, `playwright.config.js`, fixtures, pages |

Critical behavior:

1. Product/API vocabulary is always **plans/tests** (platform paths), even if repo folders are named differently.
2. Marker files define canonical roots:
   - `.testchimp-plans` at plans root
   - `.testchimp-tests` at SmartTests root
3. If one marker exists but the other does not, instruct the user to map the missing integration and complete the platform sync PR (merge) + local pull for that folder.
4. If both markers are missing, ask the user to map both folders in TestChimp, ensure **sync PRs from the platform exist and are merged for each mapped folder**, and that the **local workspace is updated** to include those merges.
5. If mappings are wrong, sync/coverage behavior is incomplete; pause implementation until mapping is corrected.

### TrueCoverage decision memory details

**Policy** (opt-in default, explicit opt-out, defer ≠ opt-out, `/testchimp test` behavior): single source — **[Key Area 4](#key-area-4-truecoverage-infra-rum-journey-events)** **Decision policy** bullet and [`instrument-truecoverage.md`](./instrument-truecoverage.md) → *Project decision*. Do not restate here.

**Operational only:**

- **Explicit opt-out in file** → skip new RUM unless the user reverses.
- **Enabled / wired** → do not re-prompt unless the user asks to revisit.
- **Deferred** → init may skip wiring that run; record **deferred during init** clearly. Downstream flows still treat TrueCoverage as **in scope** unless the file has **explicit opt-out** (see Key Area 4 / `instrument-truecoverage.md`).

### Environment strategy decision details

When selecting execution target, make this explicit in `plans/knowledge/ai-test-instructions.md`:

- **Persistent backend + local/preview frontend**: preferred fast path for frontend-only changes.
- **Full-stack remote managed ephemeral env**: preferred when backend/data behavior changes in the PR and deterministic isolation is required for pre-PR-merge testing.
- **Full-stack local ephemeral env**: A slight variation could be loading the entire stack locally - if that is feasible (for simple backends). Can use testcontainers for 
- **Discouraged fallback**: persistent stage testing via `BASE_URL` in env config (only if the team explicitly chooses post-merge-only E2E for initial simplicity).

If user chooses ephemeral and Bunnyshell is not configured, stop and ask user to configure TestChimp -> Project Settings -> Integrations -> Bunnyshell (or use Branch Management if they have bespoke PR environment URLs).

Remember the environment strategy choice made - in the ai-test-instructions.md file.

### Test setup endpoints (seed / teardown / read)

Follow [`seeding-endpoints.md`](./seeding-endpoints.md) for discovery, proxying real workflows, and guardrails.

For harness setup, determine one of these paths:

1. **Existing** seed/teardown/read endpoints → integrate them into the setup project with explicit scope (what each route does, env guards).
2. **Missing** endpoints → plan creation with the user: auth, prod safety, payload shape, idempotency (including **read-before-write** when helpful), teardown semantics, and **read** surfaces for post-UI assertions.

Aim for idempotent seed/teardown operations so retries are safe and fixture-driven setup stays deterministic.

### CI guardrails

When enabling PR-triggered execution:

- run from SmartTests root (folder with `.testchimp-tests`),
- pass resolved target URL via `BASE_URL`,
- exclude plan-sync-only PRs titled exactly `TestChimp Platform Sync [Plans]`.

### Phase 3 completion gate (before declaring init complete)

After implementation, **before** treating init as finished, walk the **six key areas** and record outcomes in **`plans/knowledge/ai-test-instructions.md`** (append **“Init Phase 3 completion”** or tick inline next to each area). Same rule as other gates: **done** + one-line summary **or** **`N/A`** + one-line justification — **no silent skips**.

- [ ] **Key Area 1** — Basic integration / markers / harness layout / MCP not 401.
- [ ] **Key Area 2** — Import strategy executed or **skipped**/`N/A` per plan (with justification).
- [ ] **Key Area 3** — Mocking stance applied (`page.route` / AIMock per plan).
- [ ] **Key Area 4** — TrueCoverage per plan (progress tracker + `plans/events/` when instrumenting).
- [ ] **Key Area 5** — Environment local-up + health contract documented as agreed.
- [ ] **Key Area 6** — CI workflow (or **`N/A`** + justification if truly no CI this cycle).

Then reconcile with **End state and completion rules** below.

---

## End state and completion rules

Init is complete when the action checklist is fully resolved (done, skipped, or deferred with explicit user agreement) and the following are documented:

- repo connected to TestChimp,
- plans/tests mappings in place,
- CI run strategy chosen and documented,
- seed/teardown/**read** and harness strategy established (per [`seeding-endpoints.md`](./seeding-endpoints.md) when authoring endpoints),
- mocking approach recorded under `### Mocking Plan` (`http_mocking` + `aimock`, or explicitly deferred / N/A),
- existing-suite import strategy recorded (or greenfield / N/A),
- environment strategy recorded,
- TrueCoverage decision recorded,
- deferred items explicitly listed.

Persist final state in `plans/knowledge/ai-test-instructions.md` including an **Environment strategy** subsection.

---

## Post-init guidance for the user

- On demand: run `/testchimp test` when a PR is ready for test authoring and execution.
- Ongoing: run `/testchimp evolve` periodically or on CI triggers to close requirement and TrueCoverage gaps; keep a record under `<MAPPED_PLANS_ROOT>/knowledge/evolve_plans/` per [`upkeep.md`](./upkeep.md).
# /testchimp init

Initialize the repo for TestChimp using a phased workflow. This document is for **AI agents** and must be run as **Phase 0 (optional smoke) -> Phase 1 (Requirement gather) -> Phase 2 (Plan) -> Phase 3 (Execution)**. Do not jump directly into implementing every setup task.

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
```

Keep this file **project-level only** (avoid workstation-specific progress like “installed MCP client on my laptop”).

### Two scopes: workstation vs project

Init mixes **two independent scopes**. Agents must not collapse them into a single “are we done?” signal.

| Scope | What it covers | How to tell if it is already done |
|--------|----------------|-------------------------------------|
| **Workstation** (per machine) | Host MCP registration: `npx` resolves **`testchimp-mcp-client`** (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)), **`.cursor/mcp.json`** (or host equivalent) contains a **`testchimp`** server entry whose **`args`** invoke the client, and **`env.TESTCHIMP_API_KEY`** is set to a **real** project key (not empty, not a placeholder). Optionally shell `TESTCHIMP_API_KEY` for Playwright / ai-wright. | **Check local config every time** — never infer from git. |
| **Project** (repo / team) | Shared decisions: environment strategy, TrueCoverage, mocking, import/CI plans, action items — persisted under **`plans/knowledge/ai-test-instructions.md`**. | If that file **exists and is substantively populated** (sections filled, not just a stub), treat **project-level** decisions as already captured unless the user wants to change them. |

**Critical:** A teammate who clones the repo after project init may see a complete **`ai-test-instructions.md`** and still have **no** MCP client or key on **their** laptop. **`/testchimp init` must always run the workstation checks and fixes** in that situation, even when project-level markdown is already done.

---

## Workstation gate (always first)

Run this **before** optional smoke (Phase 0) or project requirement gathering (Phase 1–3). On **every** `/testchimp init`, complete:

1. **Resolve MCP config** — From the SmartTests root (folder with `.testchimp-tests`), walk **up** the directory tree for **`.cursor/mcp.json`** until you find one whose **`mcpServers`** defines the TestChimp client (typically **`testchimp`**) — same resolution rules as **`SKILL.md`** Preamble check **#3**.
2. **Verify client + key** — Apply **`SKILL.md`** Preamble checks **#3** (`TESTCHIMP_API_KEY` resolvable and usable) and **#4** (MCP client version / `args` for **`testchimp-mcp-client`**). If the server entry is missing or wrong: update the host MCP config using the **`npx`** + **`testchimp-mcp-client@latest`** pattern from [`../assets/sample-mcp.json`](../assets/sample-mcp.json), then re-check (e.g. MCP tool call such as **`get_eaas_config`** must not return **401**).
3. **Never skip** this block because **`ai-test-instructions.md`** exists or looks complete.

Only after the workstation gate passes should you use **`ai-test-instructions.md`** to decide how much **project-level** Phase 1–3 work remains.

---

## Phase 0 - Quick smoke (optional but must be asked first)

### 0.1 Ask first

Complete the **[Workstation gate](#workstation-gate-always-first)** first. Then ask the user whether they want a quick smoke pass before full infra setup.

Use this explanation:

- Full init sets up enterprise QA infrastructure: TrueCoverage instrumentation, test-only **seed / teardown / read** endpoint discovery (full wiring often lands during **`/testchimp test`**), and branch-aware execution (including ephemeral environments) so E2E tests are done before PR merge with lower flakiness. Explain that TestChimp enables runtime intelligent steps for more reliable tests.
- This can be a larger cognitive investment, so quick smoke can provide immediate value first.

### 0.2 If user chooses quick smoke

Complete the **Playwright toolchain check** (**`SKILL.md`** Preamble check **#4**) first so **`npm install`** has been run at the correct package root and **`@playwright/test` ≥ 1.59.0**. Smoke authoring should also prefer **browser- or Playwright-driven validation** of flows (not only static inference) when the environment allows.

Collaborate with the user to collect:

- target URL to test,
- test authentication approach (credentials/session/token; never store secrets in git),
- a small set of critical verification flows.

Then:

1. Use browser/Playwright-driven exploration to validate key flows.
2. Author **2-3 SmartTests** under the SmartTests root (directory containing `.testchimp-tests`).
3. Ensure tests demonstrate natural-language smart steps with a few `ai.act` and `ai.verify` usages where they make sense (optionally `ai.extract`).
4. Follow patterns in [`write-smarttests.md`](./write-smarttests.md) and [`ai-wright-usage.md`](./ai-wright-usage.md).

Important prerequisite:

- If `.testchimp-tests` is missing, resolve plans/tests mapping first (see [Action item A - folder mappings and markers](#action-item-a---plans-and-tests-roots-testchimp-integrations)) before writing smoke tests.

### 0.3 After quick smoke

Prompt again: continue with full init setup?

- If **no**: record what was completed and what remains deferred in `plans/knowledge/ai-test-instructions.md`, then stop. Ask user to run `/testchimp init` when needed.
- If **yes**: continue to Phase 1.

Quick smoke by itself does **not** mean full init is complete. So do not write the init done marker file.

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
- If either marker file is missing: ask the user to complete the minimum needed TestChimp Git integration + sync so marker files exist.
- If the MCP server entry is missing or invalid after the Workstation gate: the agent should update the host MCP config automatically (using the `npx` + `testchimp-mcp-client@latest` pattern from `assets/sample-mcp.json`), then re-check that the server runs.
- Only if `TESTCHIMP_API_KEY` value is not already available to write/use (e.g. not present in shell env or existing MCP `env`): ask the user to enter that in the mcp.json env block (or confirm where it is already provided) so the MCP validation call can succeed. Ensure the MCP can be called - by using get_eaas_config - expectation is for it to not return 401.

### Key Area 2 — Existing Playwright suite / import strategy

Why this area (quick education):

- Many repos are **not** greenfield: they already have Playwright specs, or specs live **outside** the mapped SmartTests folder. TestChimp needs an explicit **migration strategy** so Phase 2 plans the right moves and Phase 3 executes them **after approval**—see [`importing-existing-tests.md`](./importing-existing-tests.md).

Agent discovery (report findings first):

- Treat the folder containing `.testchimp-tests` as the **SmartTests root**.
- Scan for **`*.spec.{js,ts}`** only (not `*.test.*` — TestChimp uses **`*.spec.*`**), excluding **`setup/**`** and treating scaffold-only setup files as non-“suite” (e.g. `global.setup.spec.*` under `setup/` does not count as an existing e2e suite).
- Under that root, check **`playwright.config.*`** for **`playwright-testchimp/reporter`** in `reporter` — if present, call out **prior SmartTests/TestChimp wiring** in findings.
- Classify: **greenfield** (no specs outside `setup/` beyond scaffold) vs **has existing Playwright** vs **dual-folder** (mapped SmartTests folder is empty/new but **`*.spec.{js,ts}`** exist elsewhere in the repo).

User choices (required when not greenfield, or when dual-folder / misaligned config):

- **Parallel SmartTests folder (gradual migration):** keep the mapped SmartTests root and **move specs and helpers over time** from a legacy Playwright folder; both may coexist until migration completes.
- **Retrofit in place:** adopt **`.testchimp-tests`**, `playwright.config.*`, **`playwright-testchimp` reporter**, and **`import 'playwright-testchimp/runtime'`** inside the **existing** tree that already holds specs (see **Migration strategies** in [`importing-existing-tests.md`](./importing-existing-tests.md)).
- If legacy specs live **outside** the mapped folder: the plan must include **moving** them into the mapped folder on an agreed schedule **or** changing Git mapping—**plan in Phase 2**, **execute in Phase 3** after approval. Do **not** move files silently in Phase 1.
- **Runtime import (mandatory for imported specs):** Any **`*.spec.{js,ts}`** that is part of the SmartTests suite after import must include **`import 'playwright-testchimp/runtime'`** at the top of the file—required for TrueCoverage (test-side), **`ai-wright`** steps, and reporter integration. See [Required: runtime import in every spec file](./importing-existing-tests.md#required-runtime-import-in-every-spec-file) in [`importing-existing-tests.md`](./importing-existing-tests.md).

**Greenfield:** state N/A briefly; no import tasks beyond normal harness scaffold in Phase 2/3.

### Key Area 3 — Mocking (Playwright `page.route` + optional AIMock)

Why this area is placed here (quick education):

- **HTTP/API** mocking uses Playwright’s native **`page.route`** by default (no MSW install as a TestChimp default). **LLM** mocking via **AIMock** is **optional** and must be **explicitly chosen** by the user during init—see [`mocking_strategy.md`](./mocking_strategy.md).

Agent discovery (report findings first):

- Whether specs or helpers already use **`page.route`** / **`context.route`** for HTTP interception.
- Whether **AIMock** (`@copilotkit/aimock` / `aimock` CLI per [upstream docs](https://github.com/CopilotKit/aimock)) or similar is already present.
- How **LLM / OpenAI-compatible** calls are resolved (hardcoded URL vs `OPENAI_BASE_URL` / SDK defaults) in frontend, backend, or shared packages.
- Whether **`<SmartTests root>/assets/goldens`** exists (or another agreed path for AIMock fixtures).

**Required user question (AIMock):** Ask whether the user wants **AIMock** set up during this init so LLM interactions in the stack are **mocked during tests** (record/replay when feasible). Tell them they can **defer** and ask to set it up when needed; also state that **AIMock is highly recommended** because it **removes ongoing LLM usage costs during test executions**. Record the choice (**yes / later / not applicable**—e.g. no LLM in scope).

Authoritative reference: [`mocking_strategy.md`](./mocking_strategy.md).

Agent stance (preferred behavior):

- **Phase 1:** Summarize findings and lock **`http_mocking`** and **`aimock`** under `### Mocking Plan` per [`mocking_strategy.md`](./mocking_strategy.md). Do **not** install or wire AIMock unless the user opts in (**yes**) or the plan explicitly schedules it; if **later**, record **deferred** with reason.
- **Phase 3:** Document or add **`page.route`** patterns as agreed. **Only if AIMock was enabled:** install AIMock, create `assets/goldens` when needed, refactor OpenAI-compatible URLs into **config/env** for tests, and document local + CI runs—per [`mocking_strategy.md`](./mocking_strategy.md) and vendor AIMock docs.

### Key Area 4 — TrueCoverage Infra (RUM + journey events)
Why this area (quick education):
- TrueCoverage is extremely useful because it turns **production behavior** into **real coverage gaps**: what users actually do (features people engage with, where they spend time, where they drop off, and top-of-funnel vs later behavior, funnel flows etc.).
- Those signals are exposed through data APIs that are consumed via MCP by AI agents to identify critical gaps and to drive coverage improvements, and exploratory testing for UX issue identification, in a tight feedback loop.
- We still start with a minimal, consistent event slice so the initial setup is fast and stable, but the data remains actionable (not just noisy).
- Agent discovery (report findings first):
  - Check `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` for whether TrueCoverage is **enabled now**, **deferred**, or **disabled** (and for any prior instrumentation decisions).
  - Check whether **TrueCoverage RUM is already wired in the app codebase** (report as a finding either way):
    - **Dependency:** e.g. `testchimp-rum-js` listed in a frontend / app `package.json` (and lockfile where present), not only under the SmartTests package.
    - **Usage:** imports or calls from `testchimp-rum-js` and/or **`testchimp.init`** / **`testchimp.emit`** (or a thin wrapper module that delegates to them) in application source.
    - If both are present, **call this out explicitly** in discovery findings (e.g. “RUM library installed and referenced for emits—init can focus on gaps vs `truecoverage-instrument-progress`, not greenfield wiring”). Optionally ask the user whether to **plan additional events** to instrument (expand `plans/knowledge/truecoverage-instrument-progress.md` and follow the `plans/events/` vs `plans/knowledge/` rules) versus only documenting what already exists.
  - Check `plans/knowledge/truecoverage-instrument-progress.md` (if present) for planned vs done events; optionally list existing `plans/events/*.event.md` files (these document **instrumented** event types only—see below).
- If TrueCoverage is **enabled now** (or the user opts in during init), init must:
  - set up **basic wiring** and instrument a **small initial event slice** (and create `plans/events/*.event.md` only for events actually instrumented), and
  - generate `plans/knowledge/truecoverage-instrument-progress.md` so the rest can be completed incrementally via `/testchimp instrument` (and/or during `/testchimp audit`). See [`truecoverage.md`](./truecoverage.md).
- If TrueCoverage decision state is missing OR the user wants to change it:
  - Decide TrueCoverage timing explicitly: set up **now**, **later** (defer with snooze file), or **no**.
  - **Authoritative references (agents must follow these for wiring and limits):**
    - Project TrueCoverage playbook: [`references/truecoverage.md`](./truecoverage.md) (setup, progress tracker, MCP analytics, event docs).
    - Browser RUM library (API, `init`/`emit`, configuration, batching, event constraints): **[testchimp-rum-js on GitHub](https://github.com/testchimphq/testchimp-rum-js)** — read the README for **`testchimp.init`**, optional `config` tuning (sampling-like limits), and **`emit()`** rules before writing wrapper code.
  - If setting up now: confirm the user should provide **`projectId`** and **`apiKey`** to the **app runtime** (the RUM SDK expects them in `testchimp.init({ projectId, apiKey, environment, ... })` per the library README). Use the app’s project environment files as appropriate; do **not** put these in `.env-QA` under the SmartTests root (those are for test execution vars like `BASE_URL`). The platform labels match TestChimp: `TESTCHIMP_PROJECT_ID` / `TESTCHIMP_API_KEY` in env often map into `init()`—see [`truecoverage.md`](./truecoverage.md).
  - If setting up now, the agent should take a stance and propose a minimal instrumentation slice:
    - Helper wrapper location: pick (or create) a single app-runtime module dedicated to TrueCoverage emits - in the webapp-under-tests' frontend code (NOT inside the tests root). Prefer an existing telemetry/analytics module if one exists; otherwise create a dedicated file. Call **`testchimp.init()` once** (see GitHub README), then **`emit()`** from the wrapper for journey events.
    - **Sampling / volume:** RUM volume is controlled by the library’s **`config`** object on `init()` (e.g. `maxEventsPerSession`, `maxRepeatsPerEvent`, `eventSendInterval`, `maxBufferSize`, `captureEnabled`)—see **[testchimp-rum-js README](https://github.com/testchimphq/testchimp-rum-js)** and the **Configuration / sampling** subsection in [`truecoverage.md`](./truecoverage.md). For the first slice, prefer **conservative** limits; reuse any existing tuning in the repo/env when present; only introduce new limits when none exist.
    - Basic events to instrument (minimal, stable set):
      - **Semantic journey completion milestones** (good examples: `add-to-cart`, `checkout-completed` / `checkout`, `order-confirmed`; bad examples: “click button”, “click next”)
      - at least one **high-signal error variant** for a key journey step (good examples: `checkout-failed`, `checkout-validation-error`; avoid generic “ui_error” noise)
      - keep event names consistent with your app’s existing analytics vocabulary if you already have one; otherwise use kebab-case semantic steps
      - only add technical noise (page_view/route changes, raw API success/failure) if you cannot identify any user-journey milestones in the product
    - Event plan locking (folder contract):
      - **`plans/knowledge/`** — maintain the **full TrueCoverage plan**: planned vs not-yet-instrumented events, route/page breakdown, and rollout progress. Required: `plans/knowledge/truecoverage-instrument-progress.md`; summarize decisions and vocabulary under `### TrueCoverage Plan` in `plans/knowledge/ai-test-instructions.md` so Phase 3 doesn’t drift.
      - **`plans/events/`** — **only** `*.event.md` files (one per **instrumented** event type, frontmatter per [`truecoverage.md`](./truecoverage.md)). Do **not** put “planned but not wired” events here; those stay in the knowledge progress tracker until `/testchimp instrument` lands them.
      - wire the helper wrapper so it emits the identified minimal **instrumented** events (SmartTests should exercise the paths that trigger those emits).
    - Full plan + progress tracking (required during init when TrueCoverage is enabled): create/update `plans/knowledge/truecoverage-instrument-progress.md` (details in [`truecoverage.md`](./truecoverage.md)).

### Key Area 5 — Environment provision strategy (persistent vs ephemeral / EaaS)
Why this area (quick education):
- The key benefit of **ephemeral, pre–PR-merge environments** is **shift-left QA**: tests run against the exact PR-specific code/data stack, not stale staging/main.
- For agentic testing, isolated envs are crucial for **accurate reasoning** because agents can validate against the PR’s real behavior (deterministic inputs, fewer “it changed after merge” surprises).
- This also makes failures more explainable: when an isolated environment is used, the test environment context matches the PR diff.
- Persistent vs ephemeral still changes how CI is structured and how `BASE_URL` is resolved per PR, and ephemeral setups require additional provisioning steps (EaaS/Bunnyshell or another ephemeral mechanism).
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

**Note:** Detailed **seed/teardown/read** endpoints and **`fixtures/`** ([`fixture-usage.md`](./fixture-usage.md)) are authored during **`/testchimp test`** when scenarios require them—not a separate init gate.

Acceptance criteria (success checks):
- Basic TestChimp integration
  - invoke an MCP command (e.g. `get_eaas_config`) to ensure it is not returning `401 Unauthorized`
  - there are 2 folders with the `.testchimp-plans` and `.testchimp-tests` marker files
  - Playwright harness layout per template (`setup` / `e2e` / `api` projects as applicable; optional `fixtures/` per [`fixture-usage.md`](./fixture-usage.md))
- Existing Playwright suite / import strategy
  - when **not** greenfield: explicit tasks for moves/config/reporter/**`import 'playwright-testchimp/runtime'` on every `*.spec.{js,ts}`** in the mapped SmartTests tree per [`importing-existing-tests.md`](./importing-existing-tests.md) and the user’s **parallel-folder vs retrofit** choice from Phase 1
  - when **greenfield**: marked **skipped** or **N/A** with a one-line note
- Mocking (Playwright `page.route` + optional AIMock)
  - `### Mocking Plan` in `plans/knowledge/ai-test-instructions.md` records **`http_mocking`** and **`aimock`** per [`mocking_strategy.md`](./mocking_strategy.md)
  - **`page.route`** stance documented (or deferred/N/A); **AIMock** only if user opted in—then dependencies and wiring per [`mocking_strategy.md`](./mocking_strategy.md); `<SmartTests root>/assets/goldens` when AIMock is in scope; LLM traffic can be aimed at AIMock via agreed env/config; brief local vs CI notes
  - if AIMock **deferred** or **not applicable**: explicitly recorded with reason
- TrueCoverage Infra
  - `plans/knowledge/truecoverage-instrument-progress.md` exists with planned vs done (and planned-not-yet-instrumented events live there, not under `plans/events/`)
  - for each event type **actually instrumented** during init, a matching `plans/events/<title>.event.md` exists; emit helper wrapper defined with configuration setup
- Environment provision strategy
  - depends on the decision, and `ai-test-instructions` contains the user agreed-upon decision AFTER it has been discussed
  - for **Local - Test Authoring**, `ai-test-instructions` includes a single runnable “local up” command/script **and** explicit “wait until healthy” criteria (so agents can reliably provision and wait before testing)
- CI setup
  - CI action authored

After the plan is written, ask the user to explicitly approve or request edits. Only after approval proceed to Phase 3. Phase 3 executes **Key Area 2** import/alignment tasks (moves, config fixes, reporter/runtime wiring) **only** after approval, when the plan included them.

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
- **Basic TestChimp integration + test harness:** actions A–F (markers, deps, config, MCP, Playwright layout including `setup` / `e2e` / `api` and optional `fixtures/`—see [`fixture-usage.md`](./fixture-usage.md))
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

1. ask user to connect repo in TestChimp -> Project Settings -> Integrations -> Git,
2. map both plans and tests folders,
3. sync/raise PR from TestChimp platform so scaffold and markers are created.

Platform path note: MCP APIs use platform-rooted paths (`plans/...` or `tests/...`) even if repo folder names differ.

Success check (Basic TestChimp integration - markers): both `.testchimp-plans` and `.testchimp-tests` marker files exist.

### Action item B - Dependencies (Node / Playwright)

TestChimp SmartTests require **`@playwright/test`** / **`playwright`** at **`>= 1.59.0`** (see **`required_playwright_test_version`** in **`SKILL.md`** frontmatter and the **Playwright toolchain check** in **Preamble checks** — agents must verify install root, **`npm install`**, and semver **before** relying on Playwright).

Run installs from the directory containing `.testchimp-tests` (or the monorepo package root that owns Playwright deps, if tests are nested):

```bash
npm install playwright-testchimp
npm install -D testchimp-mcp-client@latest
```

Use **`@latest`** for the dev dependency so installs track the current default npm release. The **Cursor MCP** entry should use **`npx`** with **`testchimp-mcp-client@latest`** in **`args`** (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)); that ensures **`npx`** resolves the latest published client when the MCP server starts.

### Action item C - Environment variables

Local (agent runtime / MCP config):

- set `TESTCHIMP_API_KEY` in MCP server `env`,
- keep config project-scoped, not global.

CI:

- set `TESTCHIMP_API_KEY` in the git provider secrets,
- ensure Playwright runner executes from the tests root.

### Action item D - Playwright config

- Keep `playwright.config.js` directly in the SmartTests root (`.testchimp-tests` directory).
- Enable `playwright-testchimp`, retain-on-failure trace, screenshots on failure.
- Use [`../assets/template_playwright.config.js`](../assets/template_playwright.config.js) as baseline.

### Action item E - MCP install (Cursor)

Register **`testchimp-mcp-client`** in MCP config with **`TESTCHIMP_API_KEY`**.

- Use **`command`:** **`npx`** and **`args`:** **`["-y", "testchimp-mcp-client@latest"]`** so each run resolves the latest npm release (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)).
- Put **`TESTCHIMP_API_KEY`** in the server **`env`** block (project-scoped key). Export the **same** key in the **shell** when running **`npx playwright …`**. **Do not** put **`TESTCHIMP_API_KEY`** in **`.env-QA`** — that file is for **test execution** env (e.g. **`BASE_URL`**). On **401** from APIs or MCP, obtain a key at TestChimp → **Project Settings** → **Key management**.
- After changing MCP config, the user should **reload MCP or restart the IDE** so the new **`npx`** arguments apply.
- Success check (Basic TestChimp integration): invoke `get_eaas_config` via the MCP client and ensure it does **not** return `401 Unauthorized` (and returns a non-empty config payload).

After install, MCP tools can be used for:

- requirement coverage,
- execution history,
- environment provisioning and endpoint resolution,
- TrueCoverage analytics.

### Action item F - Test harness setup (`setup`, `e2e`, `api`, `fixtures`)

Target structure inside SmartTests root:

- `setup`: global setup / project dependencies (see template [`template_playwright.config.js`](../assets/template_playwright.config.js)),
- `e2e`: UI-focused tests,
- `api`: API-focused tests (optional project),
- `fixtures`: optional; **`mergeTests`** master + domain modules per [`fixture-usage.md`](./fixture-usage.md). Full **fixture** and **seed endpoint** implementation usually lands during **`/testchimp test`** when scenarios require it.

During init, **discover** whether test-only seed/teardown/read routes already exist (see [`seeding-endpoints.md`](./seeding-endpoints.md)) and **record** findings in `plans/knowledge/ai-test-instructions.md` for later test authoring. Do **not** block init on authoring every endpoint or fixture.

Success check (Test harness): SmartTests root matches the template’s project layout (`setup` project, main test project, `testIgnore` for `setup/**`); optional empty **`fixtures/index`** stub is fine; no `world-states` path required.

### Action item K - Import / align existing Playwright suite (when planned)

Read `plans/knowledge/ai-test-instructions.md` for Key Area 2 decisions and follow [`references/importing-existing-tests.md`](./importing-existing-tests.md).

- If Phase 2 marked this area **skipped** / **N/A** (greenfield), mark action K **skipped** and do not move files.
- Otherwise: perform the **approved** moves, config path fixes, `playwright-testchimp` reporter + deps, and `fixtures/` layout as listed in the init plan—**only** after user approval of the plan.
- **Every** `*.spec.{js,ts}` under the mapped SmartTests root that runs as a test must include **`import 'playwright-testchimp/runtime'`** (add to any file that is missing it). This enables TrueCoverage (test-side), **`ai-wright`** steps, and full reporter/runtime integration—see [`importing-existing-tests.md`](./importing-existing-tests.md#required-runtime-import-in-every-spec-file).

Success check (Import strategy):

- SmartTests root matches the agreed strategy (**parallel-folder** migration state or **retrofit** complete to the extent planned); `npx playwright test` from the mapped folder is the canonical command; platform path expectations in [`importing-existing-tests.md`](./importing-existing-tests.md) are satisfied.
- **Every** in-scope **`*.spec.{js,ts}`** includes **`import 'playwright-testchimp/runtime'`** (verify with a repo search under the SmartTests root before marking **done**).

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

### Action item I - TrueCoverage opt-in

Read `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan`.

If decision is missing or the user requests a change, explain value and ask:

- **Yes now**: install `testchimp-rum-js` (in the application package), implement a single emit helper wrapper, configure runtime env vars (`TESTCHIMP_PROJECT_ID` + `TESTCHIMP_API_KEY` via app project environment files, not `.env-QA` under the tests root), set up sampling, identify a minimal set of basic events, wire those **instrumented** events through the emit helper, align reporter config, and persist the decision + notes under `### TrueCoverage Plan` in `plans/knowledge/ai-test-instructions.md`.

  Additionally, during init you must generate the instrumentation tracker:
  - scan the frontend to identify core routes/pages and the semantic events planned for each area
  - create `plans/knowledge/truecoverage-instrument-progress.md` to track **planned vs done** (including events not yet instrumented)
  - mark any existing emits as **done**
  - add `plans/events/<title>.event.md` **only** for event types **actually wired** in init; planned-but-not-instrumented events stay in the knowledge progress tracker until `/testchimp instrument` lands them
- **Later**: persist as deferred under `### TrueCoverage Plan` and direct user to `/testchimp setup truecoverage`.
- **No**: persist as disabled under `### TrueCoverage Plan`.

Success check (TrueCoverage Infra):
- if `enabled=true`, `plans/knowledge/truecoverage-instrument-progress.md` exists, the emit helper wrapper is defined with configuration setup (env wiring + sampling + basic event emits), and `plans/events/*.event.md` exists for each event type instrumented in init (planned-only events appear only under `plans/knowledge/` until instrumented).

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
- if fully isolated ephemeral envs: `get_eaas_config` returns non-empty result and agent can spin up an environment successfully (using TestChimp MCP)

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
3. If one marker exists but the other does not, instruct the user to map the missing integration and sync from TestChimp.
4. If both markers are missing, ask user to map both folders in TestChimp and raise platform sync PRs for both.
5. If mappings are wrong, sync/coverage behavior is incomplete; pause implementation until mapping is corrected.

### TrueCoverage decision memory details

Read `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` before prompting.

- If enabled: do not reprompt unless user asks to revisit.
- If disabled: skip instrumentation unless user changes decision.
- If deferred: skip unless user asks to set up now.

If user chooses setup now, include:

- `testchimp-rum-js` installation in application package,
- one shared emit helper,
- request args wiring (`TESTCHIMP_API_KEY`, project id, environment tags),
- alignment with reporter and event documentation flow.

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
- Ongoing: run `/testchimp audit` periodically or on CI triggers to close requirement and TrueCoverage gaps.
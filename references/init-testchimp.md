# /testchimp init

Initialize the repo for TestChimp using a phased workflow. This document is for **AI agents** and must be run as **Phase 0 (optional smoke) -> Phase 1 (Requirement gather) -> Phase 2 (Plan) -> Phase 3 (Execution)**. Do not jump directly into implementing every setup task.

---

## Purpose

`/testchimp init` often includes long-running and branching work: EaaS decisions, seeding strategy, harness setup, CI wiring, importing existing tests, and TrueCoverage setup. To keep this reliable, agents must:

1. collaborate with the user on a concrete action plan first,
2. persist decisions and item status in `plans/knowledge/ai-test-instructions.md`,
3. execute each action item methodically and update progress after each item.

### Source of truth: `plans/knowledge/ai-test-instructions.md`

Project-level decisions must be persisted in `plans/knowledge/ai-test-instructions.md` so teammates and agents share the same choices across workstations.

At minimum, `/testchimp init` should ensure this file contains the following sections (author or update as needed):

```md
## Environment Provision Strategy

### Local - Test Authoring

### CI - Test Execution

---

### TestChimp Init Progress

#### Completed

#### Pending

#### Deferred

### TrueCoverage Plan

### World-States Plan
```

Keep this file **project-level only** (avoid workstation-specific progress like “installed MCP client on my laptop”).

---

## Phase 0 - Quick smoke (optional but must be asked first)

### 0.1 Ask first

At the very start of init, ask the user whether they want a quick smoke pass before full infra setup.

Use this explanation:

- Full init sets up enterprise QA infrastructure: TrueCoverage instrumentation, World-state scripts, seed/teardown endpoints setup, and branch-aware execution (including ephemeral environments) so E2E tests are done before PR merge with lower flakiness. Explain that TestChimp enables runtime intelligent steps for more reliable tests.
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
- Deterministic `world-states` and idempotent seeding reduce “works on my machine” flakiness by ensuring author-time and execution-time start from the same posture (so agents can reason about which entities exist in which states).
- For pre–PR-merge testing, isolated environments are necessary so agents validate against the exact PR-specific code/data they’re changing (otherwise they may author based on stale staging/main behavior).
- Environment strategy affects both CI behavior and the final `BASE_URL` resolution; setting it wrong usually breaks tests in CI, and choosing the wrong isolation level makes agent decisions inaccurate.

Do not start implementing world-state/seed/truecoverage/CI until you have the user’s deliberate answers (or explicit acceptance of the agent’s proposed defaults) below.

**Do not** write or update `plans/knowledge/ai-test-instructions.md` (other than `## Init requirements`) until the user has answered in this conversation.

### Key Area 1 — Basic TestChimp integration
- Agent discovery (report findings first):
  - Locate marker files on disk:
    - `.testchimp-plans` => plans root mapped
    - `.testchimp-tests` => SmartTests root mapped
  - Locate host MCP config (commonly `.cursor/mcp.json`) and check whether a `testchimp-mcp-client` server entry exists with `env.TESTCHIMP_API_KEY`.
- If either marker file is missing: ask the user to complete the minimum needed TestChimp Git integration + sync so marker files exist.
- If the MCP server entry is missing: the agent should update the host MCP config automatically (using the `npx` + `testchimp-mcp-client@latest` pattern from `assets/sample-mcp.json`), then re-check that the server runs.
- Only if `TESTCHIMP_API_KEY` value is not already available to write/use (e.g. not present in shell env or existing MCP `env`): ask the user to enter that in the mcp.json env block (or confirm where it is already provided) so the MCP validation call can succeed. Ensure the MCP can be called - by using get_eaas_config - expectation is for it to not return 401.

### Key Area 2 — World-States Infra (seeding endpoints + base world-states)
- Agent discovery (report findings first):
  - Under the SmartTests root, check for `setup/world-states/` and any `*.world.js` scripts. This is likely going to be empty for projects not configured in TestChimp.
  - Scan for existing test-data reset/seed/teardown endpoints (look for candidate reset/seed handlers or idempotent reset entrypoints in the backend). If they are present, then identify them, and include in the plan as identified seed endpoints.
  - The core idea is - by the end of the init plan phase, agent will have identified a few (~1-2) core world-states to write and seed endpoints to implement.

Why this area (quick education):
- `world-states` let tests and agents load a pre-defined application posture at author-time and execution-time, which dramatically cuts flakiness caused by state drift.

Agent stance (preferred behavior):
- If seed/reset endpoints and/or world-state scripts are missing, do NOT ask the user “what endpoints should we write?”
- Instead, inspect the backend/domain model to recommend a minimal, idempotent seed/reset setup:
  - infer candidate entity names from DB schema/ORM models/migrations and existing domain types
  - pick a small “base” set of core entities that unblocks the most common flows (just enough to author and run a first small test suite)
  - recommend a default endpoint naming scheme (for example `POST /qa/testdata/reset` or `POST /testdata/reset`) and ensure it is safe to run (non-production-only guards)
  - include an idempotency plan (so retries don’t corrupt state) - prefer endpoints to be authored as idempotent operations.
  - recommend the minimal base world-state script name (for example `world-states/base.world.js`) that matches the seeded posture

Only ask the user when clarification/tweaks are required:
- confirm or tweak the recommended base entity list (add/remove domain-specific entities)
- confirm endpoint guard approach if the repo’s non-production guard mechanism is unclear

### Key Area 3 — TrueCoverage Infra (RUM + journey events)
Why this area (quick education):
- TrueCoverage is extremely useful because it turns **production behavior** into **real coverage gaps**: what users actually do (features people engage with, where they spend time, where they drop off, and top-of-funnel vs later behavior, funnel flows etc.).
- Those signals are exposed through data APIs that are consumed via MCP by AI agents to identify critical gaps and to drive coverage improvements, and exploratory testing for UX issue identification, in a tight feedback loop.
- We still start with a minimal, consistent event slice so the initial setup is fast and stable, but the data remains actionable (not just noisy).
- Agent discovery (report findings first):
  - Check `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` for whether TrueCoverage is **enabled now**, **deferred**, or **disabled** (and for any prior instrumentation decisions).
  - Check whether `plans/events/` already exists and has emitted event plan content (if present).
- If TrueCoverage is **enabled now** (or the user opts in during init), init must:
  - set up **basic wiring** and instrument a **small initial event slice** (and create `plans/events/*.event.md` only for events actually instrumented), and
  - generate `plans/knowledge/truecoverage-instrument-progress.md` so the rest can be completed incrementally via `/testchimp instrument` (and/or during `/testchimp audit`). See [`truecoverage.md`](./truecoverage.md).
- If TrueCoverage decision state is missing OR the user wants to change it:
  - Decide TrueCoverage timing explicitly: set up **now**, **later** (defer with snooze file), or **no**.
  - If setting up now: confirm user should provide `TESTCHIMP_PROJECT_ID` and `TESTCHIMP_API_KEY` to the **app runtime** (usually via the app’s project environment files; not the `.env-QA` files under the tests root).
  - If setting up now, the agent should take a stance and propose a minimal instrumentation slice:
    - Helper wrapper location: pick (or create) a single app-runtime module dedicated to TrueCoverage emits (NOT inside the tests root). Prefer an existing telemetry/analytics module if one exists; otherwise create a dedicated file (example pattern: `src/lib/truecoverage/emit.ts`).
    - Sampling: use conservative sampling for the first slice, reusing any existing sampling config found in the repo/env; only introduce new sampling when the repo has no prior configuration.
    - Basic events to instrument (minimal, stable set):
      - **Semantic journey completion milestones** (good examples: `add-to-cart`, `checkout-completed` / `checkout`, `order-confirmed`; bad examples: “click button”, “click next”)
      - at least one **high-signal error variant** for a key journey step (good examples: `checkout-failed`, `checkout-validation-error`; avoid generic “ui_error” noise)
      - keep event names consistent with your app’s existing analytics vocabulary if you already have one; otherwise use kebab-case semantic steps
      - only add technical noise (page_view/route changes, raw API success/failure) if you cannot identify any user-journey milestones in the product
    - Event plan locking:
      - write a minimal event plan in `plans/events/` that documents event names, required payload fields, and when the wrapper emits them
      - wire the helper wrapper so it emits the identified minimal events during SmartTests execution
    - Sampling + event names should be summarized in `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` so Phase 3 doesn’t drift.
    - Full plan + progress tracking (required during init when TrueCoverage is enabled): create `plans/knowledge/truecoverage-instrument-progress.md` (details in [`truecoverage.md`](./truecoverage.md)).

### Key Area 4 — Environment provision strategy (persistent vs ephemeral / EaaS)
Why this area (quick education):
- The key benefit of **ephemeral, pre–PR-merge environments** is **shift-left QA**: tests run against the exact PR-specific code/data stack, not stale staging/main.
- For agentic testing, isolated envs are crucial for **accurate reasoning** because agents can load controlled `world-states` against the PR’s real behavior (deterministic inputs, fewer “it changed after merge” surprises).
- This also makes failures more explainable: when an isolated environment is used, the test environment context matches the PR diff.
- Persistent vs ephemeral still changes how CI is structured and how `BASE_URL` is resolved per PR, and ephemeral setups require additional provisioning steps (EaaS/Bunnyshell or another ephemeral mechanism).
- Agent discovery (report findings first):
  - Inspect local CI/workflows and env files to see whether a `BASE_URL` (or a preview URL convention) already exists.
  - If ephemeral env tooling is present in the repo, note it as a candidate path.
- Local environment provisioning contract (must be explicit for later agents):
  - During init, persist in `plans/knowledge/ai-test-instructions.md` under `## Environment Provision Strategy` → `### Local - Test Authoring`:
    - a **single agent-runnable command** (or script entrypoint) to bring the stack up locally (prefer Docker Compose; if multiple prerequisites exist, prefer a single wrapper script entrypoint like `scripts/qa/local-up.sh`)
    - an explicit **wait-for-healthy** definition (health endpoints, compose healthchecks, ports, etc.) so later `/testchimp test` can do: provision → wait healthy → proceed
    - the resulting URLs and how they map to test variables (`BASE_URL`, `BACKEND_URL`, any `*_SERVICE_BACKEND_URL` used by world-states)
  - If the stack is too complex to run locally, record that and use EaaS for author-time instead (with a “provision and wait” MCP tool preference).
- Where will automated E2E run for PRs? (pick what matches; user can combine)
  - Preview/deploy preview URL + shared backend (typical frontend PRs), and/or
  - Ephemeral full-stack environments per branch/PR (backend or data isolation), and/or
  - Discouraged fallback: persistent stage (`BASE_URL` in `.env-*`) with little or no PR-time E2E.
- If ephemeral: are you using (or planning) Bunnyshell with TestChimp? (yes / no / not sure). If the repo discovery/MCP EaaS hints are missing, ask the connection question; otherwise report what you found.
- If PR previews matter: do you rely on TestChimp Branch Management URL template/overrides for PR-specific `BASE_URL`, or fixed env files only?

### Key Area 5 — CI setup
- Agent discovery (report findings first):
  - Check whether `.github/workflows/` (or equivalent) already has Playwright/TestChimp-related CI.
- If discovery finds existing Playwright/TestChimp CI: report what it looks like and ask whether to reuse/adjust it.
- Otherwise: ask what CI system to use (GitHub Actions / others), whether it runs on PRs vs main, and whether it should start with shared/persistent envs or provision ephemeral envs per run.

---

## Phase 2 - Plan phase (draft the 5-area execution checklist)
Why this phase (quick education):
- The plan prevents the agent from drifting across infra choices by forcing a small, explicit checklist with acceptance criteria.
- It also ensures decisions land in `plans/knowledge/ai-test-instructions.md` so Phase 3 execution stays consistent.

Create a shared action list with status and notes in `plans/knowledge/ai-test-instructions.md` under an init-specific section (for example: `## Init action items`).

Each action item must include:
- `status`: `pending | in_progress | done | skipped | deferred`
- concise notes (decisions, blockers, links, trade-offs)

Your plan MUST include exactly these 5 key areas in this order (each starting with `pending`), and for each include the acceptance criteria:

1. Basic TestChimp integration
2. World-States Infra
3. TrueCoverage Infra
4. Environment provision strategy
5. CI setup

Acceptance criteria (success checks):
- Basic TestChimp integration
  - invoke an MCP command (e.g. `get_eaas_config`) to ensure it is not returning `401 Unauthorized`
  - there are 2 folders with the `.testchimp-plans` and `.testchimp-tests` marker files
- World-States Infra
  - `world-states/` folder not empty
- TrueCoverage Infra
  - `plans/events/` folder not empty
  - emit helper wrapper defined with configuration setup
- Environment provision strategy
  - depends on the decision, and `ai-test-instructions` contains the user agreed-upon decision AFTER it has been discussed
  - for **Local - Test Authoring**, `ai-test-instructions` includes a single runnable “local up” command/script **and** explicit “wait until healthy” criteria (so agents can reliably provision and wait before testing)
- CI setup
  - CI action authored

After the plan is written, ask the user to explicitly approve or request edits. Only after approval proceed to Phase 3.

---

## Phase 3 - Execution phase (execute key areas in order)
Why this phase (quick education):
- Executing item-by-item ensures each success check is actually met (so CI/TrueCoverage failures happen for the right reason, not because a prerequisite was skipped).
- It also produces a clear progress narrative for you: what was completed and what remains deferred.

Work item-by-item from the agreed checklist and update `plans/knowledge/ai-test-instructions.md` after each completion, skip, or deferral.

Use the following action-item playbooks as implementation references.

Execute the 5 key areas in this order and treat them as grouped action-item blocks:
- Basic TestChimp integration: actions A–E
- World-States Infra: action F
- TrueCoverage Infra: action I (run before environment/Ci actions)
- Environment provision strategy: action G
- CI setup: action H

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

### Action item F - Test harness setup (`setup`, `e2e`, `api`)

Target structure inside SmartTests root:

- `setup`: pre-test seeding/teardown orchestration,
- `e2e`: UI-focused tests (may call APIs as needed),
- `api`: API-focused tests.

If seed/teardown endpoints exist, plan and wire them in setup project.
If they do not exist, plan endpoint creation with user (seed endpoint authoring planning in the full init path):

- auth model,
- production-safety constraints (non-production-only guards),
- data model to seed (agent-recommended minimal entities for the base world-state, inferred from DB schema/ORM models/migrations; user confirms/tweaks add/remove domain-specific entities),
- teardown behavior (safe to rerun),
- idempotency strategy (how retries behave).

Seed/teardown endpoints should be idempotent.

Base world-states posture (minimal is enough):
- create `world-states/` under the SmartTests root,
- add at least one minimal `*.world.js` base world-state script that corresponds to the seeded data,
- ensure the harness loads the base posture consistently at author time and execution time (e.g. `ensureWorldState` before browser steps when supported by your current setup wiring).

Success check (World-States Infra): `world-states/` folder not empty.

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
- If using PR-triggered runs, exclude TestChimp plan sync PRs with title `TestChimp Platform Sync [Plans]`.

Success check (CI setup):
- CI action authored (and wired to the selected environment strategy for `BASE_URL` / provisioning).

### Action item I - TrueCoverage opt-in

Read `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan`.

If decision is missing or the user requests a change, explain value and ask:

- **Yes now**: install `testchimp-rum-js` (in the application package), implement a single emit helper wrapper, configure runtime env vars (`TESTCHIMP_PROJECT_ID` + `TESTCHIMP_API_KEY` via app project environment files, not `.env-QA` under the tests root), set up sampling, identify a minimal set of basic events and write them to `plans/events/`, wire those events through the emit helper during SmartTests, align reporter config, and persist the decision + notes under `### TrueCoverage Plan`.

  Additionally, during init you must generate the instrumentation tracker:
  - scan the frontend to identify core routes/pages and the semantic events planned for each area
  - create `plans/knowledge/truecoverage-instrument-progress.md` to track **planned vs done**
  - mark any existing emits as **done**
  - keep `plans/events/*.event.md` creation limited to the small slice that was actually wired up in init; planned events remain only in the progress tracker until `/testchimp instrument` lands them
- **Later**: persist as deferred under `### TrueCoverage Plan` and direct user to `/testchimp setup truecoverage`.
- **No**: persist as disabled under `### TrueCoverage Plan`.

Success check (TrueCoverage Infra):
- if `enabled=true`, `plans/events/` is not empty and the emit helper wrapper is defined with configuration setup (env wiring + sampling + basic event emits).

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

### Seed/teardown endpoint planning details

For harness setup, always determine one of the two paths:

1. Existing seed/teardown endpoints -> integrate them into setup project with explicit seed scope.
2. Missing endpoints -> plan endpoint creation with user (auth, prod safety, payload shape, idempotency, teardown semantics).

Aim for idempotent seed/teardown operations so retries are safe and world-state can be restored deterministically.

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
- seed/teardown and harness strategy established,
- environment strategy recorded,
- TrueCoverage decision recorded,
- deferred items explicitly listed.

Persist final state in `plans/knowledge/ai-test-instructions.md` including an **Environment strategy** subsection.

---

## Post-init guidance for the user

- On demand: run `/testchimp test` when a PR is ready for test authoring and execution.
- Ongoing: run `/testchimp audit` periodically or on CI triggers to close requirement and TrueCoverage gaps.
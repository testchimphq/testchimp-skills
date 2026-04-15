# /testchimp init

Initialize the repo for TestChimp using a phased workflow. This document is for **AI agents** and must be run as **Phase 0 (optional smoke) -> Phase 1 (plan) -> Phase 2 (execute)**. Do not jump directly into implementing every setup task.

---

## Purpose

`/testchimp init` often includes long-running and branching work: EaaS decisions, seeding strategy, harness setup, CI wiring, importing existing tests, and TrueCoverage setup. To keep this reliable, agents must:

1. collaborate with the user on a concrete action plan first,
2. persist decisions and item status in `plans/knowledge/ai-test-instructions.md`,
3. execute each action item methodically and update progress after each item.

---

## Phase 0 - Quick smoke (optional but must be asked first)

### 0.1 Ask first

At the very start of init, ask the user whether they want a quick smoke pass before full infra setup.

Use this explanation:

- Full init sets up enterprise QA infrastructure: requirement traceability, TrueCoverage instrumentation, deterministic world-state strategy, seed/teardown setup, and branch-aware execution (including ephemeral environments) so E2E tests are done before PR merge with lower flakiness. Explain that TestChimp enables runtime intelligent steps for more reliable tests.
- This can be a larger cognitive investment, so quick smoke can provide immediate value first.

### 0.2 If user chooses quick smoke

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

## Phase 1 - Build the init plan (collaborative)

Before heavy implementation, create a shared action list with status and notes. Persist it in `plans/knowledge/ai-test-instructions.md` under an init-specific section (for example: `## Init action items`).

Each action item should include:

- `status`: `pending | in_progress | done | skipped | deferred`
- concise notes (decisions, blockers, links, trade-offs)

Plan item categories to include:

- plans/tests folder mapping and marker validation,
- dependencies, Playwright reporter, and MCP install,
- environment variable strategy (local + CI),
- TrueCoverage decision and setup timing,
- environment strategy (persistent vs ephemeral, branch management vs Bunnyshell),
- test harness setup (`setup`, `e2e`, `api` projects),
- seed/teardown endpoint strategy and idempotency plan,
- CI trigger behavior and exclusions,
- import of existing tests (if applicable).

Do not start broad implementation until the user confirms or adjusts this plan.

---

## Phase 2 - Execute the plan action items

Work item-by-item from the agreed checklist and update `plans/knowledge/ai-test-instructions.md` after each completion, skip, or deferral.

Use the following action-item playbooks as implementation references.

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

### Action item B - Dependencies (Node / Playwright)

TestChimp SmartTests require Playwright `1.59.0+`.

Run installs from the directory containing `.testchimp-tests`:

```bash
npm install playwright-testchimp
npm install -D testchimp-mcp-client
```

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

Register `testchimp-mcp-client` in MCP config with `TESTCHIMP_API_KEY`.

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
If they do not exist, plan endpoint creation with user:

- auth model,
- production-safety constraints,
- data model to seed,
- teardown behavior.

Seed/teardown endpoints should be idempotent.

### Action item G - Environment strategy

Load [`references/environment-management.md`](./environment-management.md).

Choose where tests run:

- **PR pre-merge (recommended)**:
  - branch-specific preview URL with shared backend, or
  - full isolated ephemeral environment (often preferred for backend changes).
- **Post-merge main**:
  - persistent stage environment using `BASE_URL` in env files.

For ephemeral strategy with Bunnyshell, instruct user to configure TestChimp -> Project Settings -> Integrations -> Bunnyshell.
If using custom PR environments, configure Branch Management URL template/overrides.

### Action item H - CI behavior

- Run from tests root with required env vars.
- Pass PR/stage URL via `BASE_URL`.
- If using PR-triggered runs, exclude TestChimp plan sync PRs with title `TestChimp Platform Sync [Plans]`.

### Action item I - TrueCoverage opt-in

Check `<SKILL_DIR>/bin/.truecoverage_setup`.

If missing or decision needs refresh, explain value and ask:

- **Yes now**: install `testchimp-rum-js`, add single emit helper, wire env vars, align reporter config, write `enabled=true`.
- **Later**: write `enabled=later` and direct user to `/testchimp setup truecoverage`.
- **No**: write `enabled=false`.

If already `enabled=true`, skip reprompt unless user requests change.

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

Read `<SKILL_DIR>/bin/.truecoverage_setup` before prompting.

- `enabled=true`: do not reprompt unless user asks to revisit.
- `enabled=false`: skip instrumentation unless user changes decision.
- `enabled=later`: apply a 3-day snooze before reprompting. If snooze has not elapsed, continue without reprompt.
- missing file: ask and create state file.

If user chooses setup now, include:

- `testchimp-rum-js` installation in application package,
- one shared emit helper,
- env wiring (`TESTCHIMP_API_KEY`, project id, environment tags),
- alignment with reporter and event documentation flow.

### Environment strategy decision details

When selecting execution target, make this explicit in `plans/knowledge/ai-test-instructions.md`:

- **Persistent backend + local/preview frontend**: preferred fast path for frontend-only changes.
- **Full-stack ephemeral env**: preferred when backend/data behavior changes and deterministic isolation is required.
- **Post-merge stage testing**: set persistent `BASE_URL` in environment config for deployment-stage testing.

If user chooses ephemeral and Bunnyshell is not configured, stop and ask user to configure TestChimp -> Project Settings -> Integrations -> Bunnyshell (or use Branch Management if they have bespoke PR environment URLs).

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

Write the init marker file only at this point:

- `<skill-dir>/bin/.init-has-run`

Do **not** write `.init-has-run` if only quick smoke was completed and full init was deferred.

---

## Post-init guidance for the user

- On demand: run `/testchimp test` when a PR is ready for test authoring and execution.
- Ongoing: run `/testchimp audit` periodically or on CI triggers to close requirement and TrueCoverage gaps.
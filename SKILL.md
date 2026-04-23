---
name: testchimp
description: Integrate repositories with TestChimp for QA orchestration — SmartTests (Playwright with Natural Language Steps), markdown test plans (read/author via MCP or CLI), coverage, and TestChimp tools (`@testchimp/cli`). Use when the user mentions TestChimp, /testchimp commands (init, test, plan, evolve), SmartTests, agent-driven test or plan authoring, or updating this skill from Git.
compatibility: Requires Node.js; @playwright/test and playwright >= 1.59.0 (see Preamble checks); TESTCHIMP_API_KEY for MCP, CLI, and ai-wright. Network access for TestChimp APIs when using MCP, CLI, or AI steps.
version: 0.2.3
required_cli_version: "0.1.1"
---

# TestChimp

TestChimp is a **QA workflow orchestration layer for AI agents**. It provides:

- **Setup QA infra** - sets up opinionated, enterprise-grade QA infra including CI setup, test-only seed / teardown / read endpoints, mocking strategy (Playwright **`page.route`** for HTTP/API; optional **AIMock** for LLM), TrueCoverage instrumentation, per-PR environment provisioning. **Fixtures** (Playwright `mergeTests`, `<tests_root>/fixtures/`) and the endpoints they call are introduced during **`/testchimp test`** as needed—see [`references/fixture-usage.md`](references/fixture-usage.md).
- **Requirement traceability** via structured comments in tests (e.g. `// @Scenario: #TS-101 Title`) linking SmartTests to scenarios. One test may include **multiple** `// @Scenario:` lines when it covers several scenarios; the first must be the first statement in the test body—see [`references/write-smarttests.md`](references/write-smarttests.md).
- **Markdown test plans** in a mapped `plans/` folder (YAML frontmatter, `stories/` / `scenarios/` / `knowledge/`) — how to read and author them in [`references/test-planning.md`](references/test-planning.md).
- **Intelligent Playwright steps** (`ai.act` / `ai.verify` / `ai.extract` with `ai-wright`) for more stable execution-time intelligent behavior in tests.
- **Execution reporting** via `@testchimp/playwright` so test execution details feed to TestChimp servers to enable coverage insights.
- **Fixtures + seed/read APIs** - Playwright fixtures under **`<tests_root>/fixtures/`** (master `mergeTests` entry + domain files) call **seed**, **teardown**, and **read** endpoints per [`references/seeding-endpoints.md`](references/seeding-endpoints.md). Patterns and `testInfo` scoping: [`references/fixture-usage.md`](references/fixture-usage.md).
- **TrueCoverage** - feedback loop for test coverage aligned with real user behaviour insights from production.

## Preamble (run first)

Run this once at the start of any TestChimp flow. It will:
- Flag if your **installed skill is outdated** (git-based; canonical)
- Verify `TESTCHIMP_API_KEY` is **present** in a nearby MCP config (without printing it)

```bash
_TC_PRE=$(
  ~/.cursor/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || ~/.claude/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || .cursor/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || .claude/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || true
)
[ -n "$_TC_PRE" ] && echo "$_TC_PRE" || true
```

If the preamble script cannot be run (or prints nothing), the agent MUST manually validate:

- **Skill update check**: compare local `SKILL.md` `version:` vs `origin/main` (or GitHub `main`) and offer `/testchimp update` if newer exists.
- **`TESTCHIMP_API_KEY`**: confirm it exists (non-blank, non-placeholder) in the MCP config discovered via SmartTests-root walk-up; do not print it.


## Preamble checks (run first)

Before executing a TestChimp flow:

1. **Skill update check** — rely on the `version` in this file's frontmatter. Read the current version from the local `SKILL.md`, then fetch the remote `SKILL.md` from the published repo (`https://github.com/testchimphq/testchimp-skills`, see **Updating this skill from Git** below) and compare frontmatter versions. If the remote version is newer, tell the user an update is available and ask whether to update now (`/testchimp update`). If the user agrees to update the version, proceed with the update - as noted in the below section.

2. **Decision memory check (project scope only)** — locate `/plans/knowledge/ai-test-instructions.md`. If it is missing or empty, tell the user that **project-level** init decisions are not yet persisted and recommend running `/testchimp init` to capture them (usually **once per repo**, then maintained as the team changes strategy). If it exists and is substantively populated, treat it as the source of truth for **project** decisions (environment strategy, TrueCoverage choices, Mocking Plan when present). **Do not** infer **workstation** readiness from this file: each developer still needs local MCP registration and **`TESTCHIMP_API_KEY`** in **`mcp.json`** (see **`/testchimp init`** → [Workstation gate](references/init-testchimp.md#workstation-gate-always-first) in [`references/init-testchimp.md`](references/init-testchimp.md)).

3. **`TESTCHIMP_API_KEY` prerequisite (BLOCKING)** — before starting **any** Playwright processes (headed or headless) or authoring AI steps:
   - **Resolve the key source via SmartTests-root walk-up**:
     - Find the **SmartTests root** (the folder containing `.testchimp-tests`) per **[Marker files](#marker-files)** under *How TestChimp works*.
     - Starting from that folder, walk **upwards** (parent → parent → …) looking for the **host’s project MCP config file** (e.g. Cursor often uses **`.cursor/mcp.json`**; Claude Code, VS Code, and others use their own documented paths — **`.cursor` is an example, not universal**).
     - Continue walking upwards until you find a config whose `mcpServers` contains a `testchimp` entry (i.e. the MCP server config that actually defines the TestChimp client).
     - Use `mcpServers.testchimp.env.TESTCHIMP_API_KEY` from that file as the key source. (This supports monorepos / nested workspaces where the nearest `.cursor` is not the one that defines TestChimp.)
   - If no suitable MCP config is found on the walk-up, or none of them contain a `testchimp` MCP server, or `TESTCHIMP_API_KEY` is missing/blank/placeholder, **stop** and tell the user to populate it, then **reload MCP / restart the IDE** so the MCP server process restarts with the env applied.
   - When present, **read it and export it into the Playwright run environment** (agent-run shells often do not inherit IDE/MCP env). This ensures `ai-wright` and `@testchimp/playwright` can authenticate.
   - **Never print the key** in logs or chat output.

4. **TestChimp CLI / MCP client compatibility check** — read **`required_cli_version`** from this file's frontmatter (semver). Run **`npm view @testchimp/cli version`** and treat the result as **registry latest**. Find the project's MCP server config (host-specific path; see preamble **#3**) and locate the server entry whose **`args`** include **`@testchimp/cli`** (often the server name **`testchimp`**), typically **`["-y", "@testchimp/cli@latest", "mcp"]`**.
   - If **`args`** use **`@testchimp/cli@latest`** or **`@testchimp/cli`** with **no** `@` version suffix, treat the **effective** runtime version as **registry latest** (because **`npx -y`** will resolve **`@latest`** on each run).
   - If **`args`** use an explicit **`@testchimp/cli@x.y.z`**, parse **x.y.z** as the configured version.
   - **Pass** if the effective configured version is **>=** **`required_cli_version`** (semver). **Pass** if registry latest is **>=** **`required_cli_version`** when using **`@latest`** or an unpinned package name.
   - **Corrective action** when the pinned semver or registry latest is **below** **`required_cli_version`:** Update **`args`** to **`["-y", "@testchimp/cli@latest", "mcp"]`** (see [`assets/sample-mcp.json`](assets/sample-mcp.json)), **or** pin to at least **`required_cli_version`**. Preserve **`env.TESTCHIMP_API_KEY`**. Tell the user to **reload MCP / restart the IDE** so the new command line applies.
   - If no MCP config is present yet, **do not block** the flow; point to [`assets/sample-mcp.json`](assets/sample-mcp.json) during **`/testchimp init`**.

5. **Playwright toolchain check** — TestChimp requires Playwright 1.59.0+. **Before** authoring SmartTests, running **`npx playwright test`**, or doing browser-driven exploration for **`/testchimp init`** smoke, ensure the repo actually has a compliant install:
   - Resolve the **install root**: from the **SmartTests root** (see **[Marker files](#marker-files)**), walk up until you find the **`package.json`** that declares **`@playwright/test`** (often a parent such as `ui/` in a monorepo). That directory is where **`npm install`** / **`npm ci`** must succeed for Playwright to be runnable.
   - If **`node_modules`** is missing or **`npx playwright --version`** fails, **run the repo’s install** (`npm install`, `npm ci`, or documented workspace install) **at that install root** first. **Do not** treat missing **`node_modules`** as “optional”; without install, Playwright-based steps cannot be validated.
   - **Verify** the resolved **`@playwright/test`** version is **>=** 1.59.0, and that **`playwright`** (browser package) matches **`@playwright/test`** (same line as [`references/write-smarttests.md`](references/write-smarttests.md)). Use e.g. `npm ls @playwright/test --prefix <install-root>` or `npx playwright --version` with **cwd** at the install root.
   - **Corrective action** if below minimum or version mismatch: bump **`@playwright/test`** and **`playwright`** together, reinstall, then **`npx playwright install`** for browsers if needed. If the environment cannot run install commands, **tell the user** to install dependencies and re-run; **do not** silently author tests that were never executed against a real runner.

6. **Headed authoring default (interactive)** — when the agent is **authoring** or **debugging** SmartTests for `/testchimp test`, default to **headed** runs so the user can watch and optionally intervene:
   - Prefer `npx playwright test --headed --debug` during authoring/debug sessions.
   - Use headless runs once the test is stable (or when the user explicitly asks for headless/CI mode).

7. **Explicit key-missing flag (always)** — if Playwright output, MCP calls, or TestChimp reporter logs indicate `TESTCHIMP_API_KEY` is missing, the agent must **immediately call it out** as a blocker and point back to the resolved `mcp.json` `env` block as the required configuration, per step 3.

## How TestChimp works

1. Create a project in TestChimp and connect the Git repo. Map 2 folders in the repo to the project created in TestChimp platform **`tests`** (SmartTests) and **`plans`** (test plans). Those can be mapped after logging in to TestChimp -> Select Project -> Project Settings -> Integrations -> GitHub.
2. Run SmartTests with Playwright; install **`@testchimp/playwright`** as documented in [`references/write-smarttests.md`](references/write-smarttests.md). This also pulls in `ai-wright` for enabling execution time intelligent steps.
3. Local and CI calls to TestChimp APIs are authenticated via **`TESTCHIMP_API_KEY`** env var (note that this is a project specific key - so it should be used scoped per project).

### Marker files

TestChimp adds **empty marker files** after mapping: **`.testchimp-tests`** at the **SmartTests root** (platform **tests**) and **`.testchimp-plans`** at the **plans root** (platform **plans**). On-disk folder names may differ (e.g. `ui_tests`, `plans`).

**Finding them:** Markers are **dotfiles**; workspace Glob may omit them, so **an empty Glob search does not prove they are missing**. From the repo (or workspace) root, use the terminal—e.g. **`find . -name '.testchimp-*'`**, or **`ls -a`** in a candidate folder next to `package.json` or `plans/`.

**Using SmartTests root:** The directory that contains **`.testchimp-tests`** is the SmartTests root—use it for the MCP key walk-up (Preamble **#3**), Playwright install resolution (**#5**), and every **`npx playwright …`** run (Agent guardrails).

**If markers are missing after mapping:** Confirm **sync PRs from the TestChimp platform were raised and merged for each mapped folder** and the **local workspace was updated** (e.g. `git pull`)—see [`references/init-testchimp.md`](references/init-testchimp.md) (Key Area 1 and Action item A).

## Agent guardrails (must follow)

1. **Scenario and story IDs — never invent (but do create real ones when missing).**
   - **Never invent / assume fake IDs**: Do **not** guess or fabricate **`#TS-…`** / **`US-…`** ids, and do **not** write `// @Scenario: #TS-…` comments before those entities exist in TestChimp.
   - **Correct behavior when coverage is missing**: If the PR introduces behavior and there are **no relevant stories/scenarios**, the correct solution is to **plan the creation** of the missing user stories and test scenarios (via MCP/CLI) so the platform generates **real IDs**.
   - **Timing rule (critical)**: The agent must **only call** `create-user-story` / `create-test-scenario` (or equivalent CLI/MCP upserts) **in the Execute phase**, **after** the user has explicitly approved the Plan. The Plan must list exactly which stories/scenarios will be created/updated, but must not mutate the platform pre-approval.
   - **After IDs exist**: Add link comments in SmartTests using the **actual IDs returned by the platform** (or present in committed plan markdown). See [`references/test-planning.md`](references/test-planning.md).

2. **Run Playwright only from the mapped SmartTests root** (see **[Marker files](#marker-files)**). **`cd` there**, then run Playwright via **`npx`** (e.g. `npx playwright test …`). Do not run tests from the repo root unless that root **is** the mapped folder.

3. **`TESTCHIMP_API_KEY` — where it lives.** Set the project API key in the **shell environment** for local runs and in the MCP server **`env`** block in **`mcp.json`** (see [`assets/sample-mcp.json`](assets/sample-mcp.json)). **Do not** put **`TESTCHIMP_API_KEY`** in **`.env-QA`** (or other **`.env-*`**) files — those are for **test execution** variables (e.g. **`BASE_URL`**, auth fixtures, feature flags). For **ai-wright** / AI steps, instruct users to set **`TESTCHIMP_API_KEY`** in the environment only — **do not** document or suggest **personal access token (PAT)** or alternate user-auth env pairs for agents.

4. **HTTP 401 from TestChimp APIs or MCP.** If a run or MCP call returns **401 Unauthorized**, stop and ask the user to configure **`TESTCHIMP_API_KEY`**. Tell them how to obtain a key: sign in to **TestChimp** → **Project Settings** → **Key management**, where project API keys are listed. Remind them to set the same key in the shell (and in **`mcp.json`** **`env`** for MCP).

5. **Gitignore generated report folders.** Playwright (and reporters) can create generated artifacts (HTML reports, traces, screenshots, videos, raw results). These must **not** be committed. Ensure the repo’s **`.gitignore`** includes common Playwright output folders such as:
   - `playwright-report/`
   - `test-results/`
   - `blob-report/`
   - any other repo-specific generated report/output directory configured by the test runner or CI

## MCP client and CLI (agents)

Install **`@testchimp/cli@latest`** (see [`references/init-testchimp.md`](references/init-testchimp.md)) and register the MCP server using **`npx`** with **`@testchimp/cli@latest`** and the **`mcp`** subcommand in **`args`**.

**CLI (shell / CI):** Same package exposes the **`testchimp`** binary for calling the same HTTP APIs with flags or **`--json-input`**. See [`references/cli.md`](references/cli.md) for env resolution, stdout/stderr, and when to prefer CLI vs MCP.

**Reference config:** [`assets/sample-mcp.json`](assets/sample-mcp.json) — shows **`command`**, **`args`** (`-y` + **`@testchimp/cli@latest`** + **`mcp`**), and **`env`** with **`TESTCHIMP_API_KEY`**. Replace the placeholder with the **project-scoped** API key from TestChimp; **do not commit** real keys.

**Minimum versions:** This skill declares **`required_cli_version`** in frontmatter. Agents must run the **TestChimp CLI / MCP client compatibility check** and **Playwright toolchain check** in **Preamble checks**.

Environment vars (MCP **`env`** block):

- `TESTCHIMP_API_KEY` (required) — same project key as in the shell for Playwright / ai-wright; not stored in **`.env-QA`**.

If MCP or API calls return **401**, see **Agent guardrails** → HTTP 401.

The MCP server exposes tools grouped by area:

- **Coverage & execution** — `get-requirement-coverage`, `get-execution-history`
- **Planning (user stories & scenarios)** — `create-user-story`, `create-test-scenario`, `update-user-story`, `update-test-scenario`
- **Environments & EaaS** — `get-eaas-config`, `get-branch-specific-endpoint-config`, `provision-ephemeral-environment-and-wait`, `provision-ephemeral-environment`, `get-ephemeral-environment-status`, `destroy-ephemeral-environment`
- **Ephemeral deploy diagnostics (BunnyShell)** — `list-bunnyshell-environment-events`, `list-bunnyshell-workflow-jobs`, `get-bunnyshell-workflow-job-logs`
- **TrueCoverage analytics** — `list-rum-environments`, `get-truecoverage-events`, `get-truecoverage-event-details`, `get-truecoverage-child-event-tree`, `get-truecoverage-event-transition`, `get-truecoverage-event-time-series`, `get-truecoverage-session-metadata-keys`, `get-truecoverage-event-metadata-keys`

Use the repo, plans, and those tools to decide what to test and how to run them.

## Command routing

| User says | Read |
|-----------|------|
| `/testchimp init` | [`references/init-testchimp.md`](references/init-testchimp.md) — opening message → phased workflow (requirement gather → plan → execute). **Between phases:** complete each **phase completion gate** in the reference; every line **done** or **`N/A`** + one-line justification (persist in `plans/knowledge/ai-test-instructions.md` where noted). |
| `/testchimp test` | [`references/testing-process.md`](references/testing-process.md) — Plan → Setup → Execute → Cleanup. **Between phases:** complete each **phase completion gate**; every line **done** or **`N/A`** + one-line justification (record on the **branch plan** file). |
| `/testchimp plan` | [`references/test-planning.md`](references/test-planning.md) |
| `/testchimp evolve` | [`references/evolve-coverage.md`](references/evolve-coverage.md) — Analyze → Plan → Execute; same **done / `N/A` + justify** gating on phase gates and completion checklists. |
| `/testchimp setup truecoverage` / setup-truecoverage | [`references/truecoverage.md`](references/truecoverage.md) |
| `/testchimp instrument` | [`references/truecoverage.md`](references/truecoverage.md) |
| `/testchimp update` | [Read below for updating the skill] |

### `/testchimp init` — opening message (deliver first)

When the user runs **`/testchimp init`**, the **first substantive message to the user** must set expectations: what init delivers, what they do after init, what the agent does during ongoing QA, and how **`/testchimp evolve`** fits in. **Then** continue with Preamble checks, the [Workstation gate](references/init-testchimp.md#workstation-gate-always-first), and the rest of [`references/init-testchimp.md`](references/init-testchimp.md).

**Include the following substance** (adapt wording slightly for tone; keep meaning):

- **During init**, TestChimp sets up **complete QA infrastructure** for the project: seeding endpoints, test environment management, CI setup, fixtures maintainance, mocks, TrueCoverage instrumentation (for coverage gaps aligned with real user behaviours in production), and test scaffolds with proper TestChimp integration.
- **After init**, the user mainly runs **`/testchimp test`** when they finish a PR and want it tested.
- **Ongoing**, the agent runs the full QA workflow (say in first person when addressing the user: *I will run the complete QA workflow* — author tests for relevant scenarios, author missing test plans for the PR, adjust QA infrastructure as needed - adding seed endpoints, TrueCoverage instrumentations, fixture updates, find coverage gaps and address them).
- **Periodically**, run **`/testchimp evolve`** "I will" (similar to above say in first-person) analyze requirement coverage gaps and TrueCoverage insights - by communicating with TestChimp platform, and address them systematically - to continuously improve your test coverage, including QA infra updates such as writing up seed / probe endpoints, fixtures, mocks, to mimic real world situations as observed, and writing up tests to cover under-tested areas.

**Always** share this doc link for a short overview of what TestChimp enables: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

(Full step order is in [`references/init-testchimp.md`](references/init-testchimp.md#opening-message-required-first-user-facing-step).)

If the user asks semantically similar requests ("Setup TestChimp", "Write Tests for the PR", "Analyze requirement coverage" etc.) — open the matching reference file above. Legacy **`/testchimp audit`** is the same flow as **`/testchimp evolve`** ([`references/evolve-coverage.md`](references/evolve-coverage.md)).

TrueCoverage planning source of truth:

- `plans/knowledge/truecoverage-instrument-progress.md` tracks **planned vs done** TrueCoverage instrumentation. Agents should consult it during `/testchimp init`, `/testchimp instrument`, and `/testchimp evolve`.

## Updating this skill from Git

This skill is published at **`https://github.com/testchimphq/testchimp-skills`** (branch **`main`**). Prefer installing with **`git clone … <skills-parent>/testchimp`** so **`.git`** remains and updates are trivial.

1. Find **`SKILL_DIR`**: the directory containing this **`SKILL.md`** and (when git-installed) **`.git`**. Typical paths include `~/.claude/skills/testchimp`, `~/.cursor/skills/testchimp`, `~/.kiro/skills/testchimp`, `~/.agents/skills/testchimp`, or the same names under **`.claude/skills`**, **`.cursor/skills`**, **`.kiro/skills`**, **`.agents/skills`**, **`.github/skills`** inside a project.
2. If **`.git`** exists in **`SKILL_DIR`**:

   ```bash
   git -C "$SKILL_DIR" pull origin main
   ```

   (or `git fetch origin && git merge origin/main`).

3. If **`.git`** is missing, reinstall with **`git clone`** per **[README.md](README.md)** (or the copy-only fallback there).
4. Tell the user to **restart** the IDE or agent host if the skill does not reload automatically.

## Coverage scope note

`get-requirement-coverage` supports platform-rooted paths under both **`tests/...`** and **`plans/...`**.
When a `plans/...` folder is provided, coverage resolves SmartTests linked to scenarios in that plan scope.
`scope.folderPath` should be provided using **platform paths** (rooted at `tests` or `plans`), even when the mapped repo folders use different names (for example, if mapped repo folder for `tests` in the repo is `ui_tests` then to ask for coverage for `ui_tests/checkout`, the scope you request should be for `tests/checkout`).

## Progressive disclosure

Per the [Agent Skills specification](https://agentskills.io/specification), this skill keeps **`SKILL.md`** as the entrypoint. **Load a reference file only when** the task matches that flow (`/init`, `/test`, `/plan`, `/evolve`, TrueCoverage setup/instrument). During `/testchimp init`, run the **workstation gate** (MCP + API key) first — see [Workstation gate](references/init-testchimp.md#workstation-gate-always-first) in [`references/init-testchimp.md`](references/init-testchimp.md) — then go directly into the phased init workflow (requirement gather, collaborative plan, execute item-by-item with **project-level** progress in `plans/knowledge/ai-test-instructions.md`). When classifying **greenfield vs existing Playwright**, dual-folder mappings, import strategy, or CI alignment for SmartTests, load [`references/importing-existing-tests.md`](references/importing-existing-tests.md). During **`/testchimp test`**, if the user specifies an **area**, **story/scenario**, or other **focus instructions**, prioritize that scope; otherwise derive context from **PR changes / recent commits** and cross-reference test plans per [`references/testing-process.md`](references/testing-process.md). For **Playwright `page.route`** (HTTP/API), **optional AIMock** (LLM), goldens layout, and test doubles, load [`references/mocking_strategy.md`](references/mocking_strategy.md). Plan **reading and authoring** (including MCP create/update flows) use [`references/test-planning.md`](references/test-planning.md). When planning or implementing **seed**, **teardown**, or **read** test endpoints, **fixtures**, or **backend state assertions** after UI flows, load [`references/seeding-endpoints.md`](references/seeding-endpoints.md) (includes **restart/reprovision** the app-under-test after seed or backend changes) and [`references/fixture-usage.md`](references/fixture-usage.md). During `/testchimp test`, load [`references/api-testing.md`](references/api-testing.md) when a scenario is designated for API automation and [`references/write-smarttests.md`](references/write-smarttests.md) for UI SmartTests. Load [`references/environment-management.md`](references/environment-management.md) when choosing or provisioning test environments, EaaS (Bunnyshell), or branch-scoped `BASE_URL` resolution. During **`/testchimp evolve`**, load [`references/evolve-coverage.md`](references/evolve-coverage.md) — structured **Analyze → Plan → Execute** with phase gates and persisted plans at `<MAPPED_PLANS_ROOT>/knowledge/evolve_plans/plan_<YYYY-MM-DD>_<nn>.md`. Use [`references/truecoverage.md`](references/truecoverage.md) for **`testchimp.emit`** metadata (including dot-scoped entity keys) so instrumentation captures how real users slice the product for later fixture and test work. Load [`references/truecoverage.md`](references/truecoverage.md) when RUM instrumentation, TrueCoverage planning, or TrueCoverage MCP tools are in scope. Deep **`ai-wright`** API detail lives in [`references/ai-wright-usage.md`](references/ai-wright-usage.md) — pull it in when authoring or debugging AI steps.

### `/testchimp test` plan persistence (branch scope)

`/testchimp test` may be run multiple times while developing a branch. To make reruns deterministic, the Plan phase must be persisted and reused as a **per-branch** markdown spec under the mapped plans root:

- Always locate the mapped plans root (`<MAPPED_PLANS_ROOT>`) via the `.testchimp-plans` marker file.
- Always create/update the branch plan file at:
  - `<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`
- Define `<branch_slug>` as a **filename-safe** form of the current git branch name:
  - Resolve branch name via `git branch --show-current` (fallback `git rev-parse --abbrev-ref HEAD`, then `git rev-parse --short HEAD` for detached HEAD)
  - Lowercase; replace any non `[a-z0-9]` sequences (including `/`) with `_`; trim leading/trailing `_`
- Always include YAML frontmatter with:
  - `LastRunOnCommit: <commit_sha>`
- Always maintain an explicit **done/not-done checklist** of action items so the agent can resume from the file on subsequent runs.

See [`references/testing-process.md`](references/testing-process.md) for the full `/testchimp test` workflow (**Analyze → Plan → Execute**) including non-negotiables, required plan sections, and the checklist gating mechanism.

Environment provisioning contract:

- During `/testchimp init`, persist the **chosen** environment provisioning strategy under `plans/knowledge/ai-test-instructions.md` → `## Environment Provision Strategy`.\n  - If **Local - Test Authoring** is the chosen path, persist a single **local environment up** command/script and explicit **wait-for-healthy** criteria (so the agent can reliably bring the stack up locally, wait until it’s ready, then run seeds/tests).\n  - If **EaaS (Bunnyshell)** or **Branch Management** is chosen, persist the provisioning + wait approach (and how `BASE_URL`/`BACKEND_URL` are resolved).
- During `/testchimp test`, the agent must consult that decision file and bring the environment up (and wait until healthy) before executing any test cases (including fixture-driven seed/teardown where tests use shared setup).

**Backend / seed changes: restart or reprovision the app-under-test.** When authoring or changing tests, **fixtures**, or **backend** code that affects what the app-under-test runs (including **seed/teardown/read** routes, **config or flags** that enable test-only behavior, or any service your tests target per `ai-test-instructions.md`), **do not assume a running stack already includes those changes**. Follow the **Environment Provision Strategy** recorded in `plans/knowledge/ai-test-instructions.md`:

- **Local provisioning** — **Tear down and bring the stack back up** (or restart only the affected services) so the running processes load the new code. Prefer the project’s documented **local up** / **wait-for-healthy** flow; killing the existing env and starting fresh is acceptable when that matches how the team runs the stack.
- **Cloud / SaaS / EaaS (ephemeral environments)** — Provisioning often builds from the **current Git branch at `HEAD`**. **Commit and push** (or otherwise ensure the remote branch contains) seed-endpoint and backend changes **before** reprovisioning or re-running provision, so the cloud environment does not deploy stale code. If the project uses branch-specific or staging URLs, confirm the same source-of-truth rules documented in `ai-test-instructions.md`.

See also [`references/seeding-endpoints.md`](references/seeding-endpoints.md) (after changing seed routes) and [`references/environment-management.md`](references/environment-management.md) (local vs EaaS).

## References (this skill)

| Path | Purpose |
|------|---------|
| [`references/init-testchimp.md`](references/init-testchimp.md) | Phased init: requirement gather, collaborative plan, action-item execution |
| [`references/importing-existing-tests.md`](references/importing-existing-tests.md) | Greenfield vs existing Playwright, migration strategies, mapped-folder layout, CI |
| [`references/testing-process.md`](references/testing-process.md) | `/testchimp test` strict workflow: Analyze → Plan → Execute with checklist gates |
| [`references/write-smarttests.md`](references/write-smarttests.md) | SmartTest authoring (UI tests with smart steps) details used by the execution phase |
| [`references/api-testing.md`](references/api-testing.md) | API test authoring workflow from captured browser network flows |
| [`references/test-planning.md`](references/test-planning.md) | Plan folder layout, frontmatter, `/testchimp plan`, MCP plan authoring |
| [`references/evolve-coverage.md`](references/evolve-coverage.md) | `/testchimp evolve`: Analyze → Plan → Execute, phase gates, persisted `knowledge/evolve_plans/` |
| [`references/truecoverage.md`](references/truecoverage.md) | TrueCoverage RUM setup, `plans/events/*.event.md`, MCP analytics |
| [`references/ai-wright-usage.md`](references/ai-wright-usage.md) | `ai-wright` install, env, API depth |
| [`references/environment-management.md`](references/environment-management.md) | Persistent vs ephemeral envs, Bunnyshell, Branch Management, MCP `get-branch-specific-endpoint-config` |
| [`references/cli.md`](references/cli.md) | `@testchimp/cli`: shell usage, `--json-input`, key export for CLI, stdout/stderr |
| [`references/mocking_strategy.md`](references/mocking_strategy.md) | `page.route` vs optional AIMock, `<tests_root>/assets/goldens`, init plan/execute split |
| [`references/seeding-endpoints.md`](references/seeding-endpoints.md) | Test-only seed, teardown, and read endpoints; discovery, proxy pattern, idempotency |
| [`references/fixture-usage.md`](references/fixture-usage.md) | `mergeTests`, `<tests_root>/fixtures/`, `testInfo`, agent probe specs |
| [`assets/template_playwright.config.js`](assets/template_playwright.config.js) | Sample Playwright config (copy into SmartTests root) |
| [`assets/sample-mcp.json`](assets/sample-mcp.json) | Sample MCP config: `npx`, `@testchimp/cli@latest`, `mcp`, `TESTCHIMP_API_KEY` |


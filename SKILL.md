---
name: testchimp
description: Integrate repositories with TestChimp for QA orchestration — SmartTests (Playwright with Natural Language Steps), markdown test plans (read/author via MCP), coverage, and MCP tools. Use when the user mentions TestChimp, /testchimp commands (init, test, plan, audit), SmartTests, agent-driven test or plan authoring, or updating this skill from Git.
compatibility: Requires Node.js; @playwright/test and playwright >= required_playwright_test_version (see Preamble checks); TESTCHIMP_API_KEY for MCP and ai-wright. Network access for TestChimp APIs when using MCP or AI steps.
version: 0.1.5
required_mcp_client_version: "0.0.4"
---

# TestChimp

TestChimp is a **QA workflow orchestration layer for AI agents**. It provides:

- **Setup QA infra** - sets up opinionated, enterprise-grade QA infra including CI setup, seeding endpoints, world-state scripts, per-PR environment provisioning.
- **Requirement traceability** via structured comments in tests (e.g. `// @Scenario: #TS-101 Title`) linking SmartTests to scenarios.
- **Markdown test plans** in a mapped `plans/` folder (YAML frontmatter, `stories/` / `scenarios/` / `knowledge/`) — how to read and author them in [`references/test-planning.md`](references/test-planning.md).
- **Intelligent Playwright steps** (`ai.act` / `ai.verify` / `ai.extract` with `ai-wright`) for more stable execution-time intelligent behavior in tests.
- **Execution reporting** via `playwright-testchimp` so test execution details feed to TestChimp servers to enable coverage insights.
- **World-States** - reusable world-state scripts utilizing seed endpoints to bring environments to known pre-defined states. Useful for agents to test in a known state, and refer them in test scripts to ensure execution happens in same world-state.
- **TrueCoverage** - feedback loop for test coverage aligned with real user behaviour in production.


## Preamble checks (run first)

Before executing a TestChimp flow:

1. **Skill update check** — rely on the `version` in this file's frontmatter. Read the current version from the local `SKILL.md`, then fetch the remote `SKILL.md` from the published repo (`https://github.com/testchimphq/testchimp-skills`, see **Updating this skill from Git** below) and compare frontmatter versions. If the remote version is newer, tell the user an update is available and ask whether to update now (`/testchimp update`). If the user agrees to update the version, proceed with the update - as noted in the below section.

2. **Decision memory check** — locate `/plans/knowledge/ai-test-instructions.md`. If it is missing or empty, tell the user that project-level init decisions are not yet persisted and recommend running `/testchimp init` (it typically needs to run only once per repo/project). If it exists, treat it as the source of truth for project decisions (environment strategy, TrueCoverage choices, world-state strategy).

3. **MCP client compatibility check** — read **`required_mcp_client_version`** from this file's frontmatter (semver). Run **`npm view testchimp-mcp-client version`** and treat the result as **registry latest**. Find the project's MCP server config (for example **`.cursor/mcp.json`**, or the host's documented MCP config path) and locate the server entry whose **`args`** include **`testchimp-mcp-client`** (often the server name **`testchimp`**).
   - If **`args`** use **`testchimp-mcp-client@latest`** or **`testchimp-mcp-client`** with **no** `@` version suffix, treat the **effective** runtime version as **registry latest** (because **`npx -y`** will resolve **`@latest`** on each run).
   - If **`args`** use an explicit **`testchimp-mcp-client@x.y.z`**, parse **x.y.z** as the configured version.
   - **Pass** if the effective configured version is **>=** **`required_mcp_client_version`** (semver). **Pass** if registry latest is **>=** **`required_mcp_client_version`** when using **`@latest`** or an unpinned package name.
   - **Corrective action** when the pinned semver or registry latest is **below** **`required_mcp_client_version`:** Update **`args`** so the package specifier is **`testchimp-mcp-client@latest`** (see [`assets/sample-mcp.json`](assets/sample-mcp.json)), **or** pin to at least **`required_mcp_client_version`**. Preserve **`env.TESTCHIMP_API_KEY`**. Tell the user to **reload MCP / restart the IDE** so the new command line applies. If registry latest is still below **`required_mcp_client_version`**, tell the user the skill expects a newer published client once it is available.
   - If no MCP config is present yet, **do not block** the flow; point to [`assets/sample-mcp.json`](assets/sample-mcp.json) during **`/testchimp init`**.

4. **Playwright toolchain check** — TestChimp requires Playwright 1.59.0+. **Before** authoring SmartTests, running **`npx playwright test`**, or doing browser-driven exploration for **`/testchimp init`** smoke, ensure the repo actually has a compliant install:
   - Resolve the **install root**: from the SmartTests directory (the one containing **`.testchimp-tests`**), walk up until you find the **`package.json`** that declares **`@playwright/test`** (often a parent such as `ui/` in a monorepo). That directory is where **`npm install`** / **`npm ci`** must succeed for Playwright to be runnable.
   - If **`node_modules`** is missing or **`npx playwright --version`** fails, **run the repo’s install** (`npm install`, `npm ci`, or documented workspace install) **at that install root** first. **Do not** treat missing **`node_modules`** as “optional”; without install, Playwright-based steps cannot be validated.
   - **Verify** the resolved **`@playwright/test`** version is **>=** 1.59.0, and that **`playwright`** (browser package) matches **`@playwright/test`** (same line as [`references/write-smarttests.md`](references/write-smarttests.md)). Use e.g. `npm ls @playwright/test --prefix <install-root>` or `npx playwright --version` with **cwd** at the install root.
   - **Corrective action** if below minimum or version mismatch: bump **`@playwright/test`** and **`playwright`** together, reinstall, then **`npx playwright install`** for browsers if needed. If the environment cannot run install commands, **tell the user** to install dependencies and re-run; **do not** silently author tests that were never executed against a real runner.

## How TestChimp works

1. Create a project in TestChimp and connect the Git repo. Map 2 folders in the repo to the project created in TestChimp platform **`tests`** (SmartTests) and **`plans`** (test plans). Those can be mapped after logging in to TestChimp -> Select Project -> Project Settings -> Integrations -> GitHub.
2. TestChimp creates **folder marker files** (empty): `.testchimp-tests` under tests root, `.testchimp-plans` under plans root so paths are recognizable - so you can identify the mapped folders using those markers.
3. Run SmartTests with Playwright; install **`playwright-testchimp`** as documented in [`references/write-smarttests.md`](references/write-smarttests.md). This also pulls in `ai-wright` for enabling execution time intelligent steps.
4. Local and CI calls to TestChimp APIs are authenticated via **`TESTCHIMP_API_KEY`** env var (note that this is a project specific key - so it should be used scoped per project).

## Agent guardrails (must follow)

1. **Scenario and story IDs — never invent.** Do **not** guess or fabricate **`#TS-…`** / **`US-…`** ids or write `// @Scenario: #TS-…` comments before those entities exist in TestChimp. **First** create user stories and test scenarios via the planning flow and MCP tools (**`create_user_story`**, **`create_test_scenario`**, etc.; see [`references/test-planning.md`](references/test-planning.md)), or use ids **returned** by the platform / present in committed plan markdown. **Then** add link comments in SmartTests so stable ids match the system.

2. **Run Playwright only from the mapped SmartTests folder.** Find the repo directory that contains **`.testchimp-tests`** (the folder mapped to platform **tests** — the on-disk name may be `tests`, `ui_tests`, or anything). **`cd` to that folder**, then run Playwright via **`npx`** (e.g. `npx playwright test …`). Do not run tests from the repo root unless that root **is** the mapped folder.

3. **`TESTCHIMP_API_KEY` — where it lives.** Set the project API key in the **shell environment** for local runs and in the MCP server **`env`** block in **`mcp.json`** (see [`assets/sample-mcp.json`](assets/sample-mcp.json)). **Do not** put **`TESTCHIMP_API_KEY`** in **`.env-QA`** (or other **`.env-*`**) files — those are for **test execution** variables (e.g. **`BASE_URL`**, auth fixtures, feature flags). For **ai-wright** / AI steps, instruct users to set **`TESTCHIMP_API_KEY`** in the environment only — **do not** document or suggest **personal access token (PAT)** or alternate user-auth env pairs for agents.

4. **HTTP 401 from TestChimp APIs or MCP.** If a run or MCP call returns **401 Unauthorized**, stop and ask the user to configure **`TESTCHIMP_API_KEY`**. Tell them how to obtain a key: sign in to **TestChimp** → **Project Settings** → **Key management**, where project API keys are listed. Remind them to set the same key in the shell (and in **`mcp.json`** **`env`** for MCP).

## MCP client (agents)

Install **`testchimp-mcp-client@latest`** (see [`references/init-testchimp.md`](references/init-testchimp.md)) and register it in the host MCP config using **`npx`** with **`testchimp-mcp-client@latest`** in **`args`** so each **`npx`** invocation resolves the **latest** published client from npm.

**Reference config:** [`assets/sample-mcp.json`](assets/sample-mcp.json) — shows **`command`**, **`args`** (`-y` + **`testchimp-mcp-client@latest`**), and **`env`** with **`TESTCHIMP_API_KEY`**. Replace the placeholder with the **project-scoped** API key from TestChimp; **do not commit** real keys. Optionally add **`TESTCHIMP_BACKEND_URL`** in **`env`** only when pointing at a non-default backend (for example staging).

**Minimum versions:** This skill declares **`required_mcp_client_version`**  in frontmatter. Agents must run the **MCP client compatibility check** and **Playwright toolchain check** in **Preamble checks**.

Environment vars (MCP **`env`** block):

- `TESTCHIMP_API_KEY` (required) — same project key as in the shell for Playwright / ai-wright; not stored in **`.env-QA`**.

If MCP or API calls return **401**, see **Agent guardrails** → HTTP 401.

The MCP server exposes tools grouped by area:

- **Coverage & execution** — `get_requirement_coverage`, `get_execution_history`
- **Planning (user stories & scenarios)** — `create_user_story`, `create_test_scenario`, `update_user_story`, `update_test_scenario`
- **Environments & EaaS** — `get_eaas_config`, `get_branch_specific_endpoint_config`, `provision_ephemeral_environment_and_wait`, `provision_ephemeral_environment`, `get_ephemeral_environment_status`, `destroy_ephemeral_environment`
- **Ephemeral deploy diagnostics (BunnyShell)** — `list_bunnyshell_environment_events`, `list_bunnyshell_workflow_jobs`, `get_bunnyshell_workflow_job_logs`
- **TrueCoverage analytics** — `list_rum_environments`, `get_truecoverage_events`, `get_truecoverage_event_details`, `get_truecoverage_child_event_tree`, `get_truecoverage_event_transition`, `get_truecoverage_event_time_series`, `get_truecoverage_session_metadata_keys`, `get_truecoverage_event_metadata_keys`

Use the repo, plans, and those tools to decide what to test and how to run them.

## Command routing

| User says | Read |
|-----------|------|
| `/testchimp init` | [`references/init-testchimp.md`](references/init-testchimp.md) (phased workflow: optional quick smoke -> plan -> execute) |
| `/testchimp test` | [`references/testing-process.md`](references/testing-process.md) |
| `/testchimp plan` | [`references/test-planning.md`](references/test-planning.md) |
| `/testchimp audit` | [`references/audit-coverage.md`](references/audit-coverage.md) |
| `/testchimp setup truecoverage` / setup-truecoverage | [`references/truecoverage.md`](references/truecoverage.md) |
| `/testchimp instrument` | [`references/truecoverage.md`](references/truecoverage.md) |
| `/testchimp update` | [Read below for updating the skill] |

If the user asks semantically similar requests ("Setup TestChimp", "Write Tests for the PR", "Analyze requirement coverage" etc.) — open the matching reference file above.

TrueCoverage planning source of truth:

- `plans/knowledge/truecoverage-instrument-progress.md` tracks **planned vs done** TrueCoverage instrumentation. Agents should consult it during `/testchimp init`, `/testchimp instrument`, and `/testchimp audit`.

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

`get_requirement_coverage` supports platform-rooted paths under both **`tests/...`** and **`plans/...`**.
When a `plans/...` folder is provided, coverage resolves SmartTests linked to scenarios in that plan scope.
`scope.folderPath` should be provided using **platform paths** (rooted at `tests` or `plans`), even when the mapped repo folders use different names (for example, if mapped repo folder for `tests` in the repo is `ui_tests` then to ask for coverage for `ui_tests/checkout`, the scope you request should be for `tests/checkout`).

## Progressive disclosure

Per the [Agent Skills specification](https://agentskills.io/specification), this skill keeps **`SKILL.md`** as the entrypoint. **Load a reference file only when** the task matches that flow (`/init`, `/test`, `/plan`, `/audit`, TrueCoverage setup/instrument). During `/testchimp init`, follow the phased init workflow (optional quick smoke first, then collaborative plan, then execute item-by-item with progress persisted in `plans/knowledge/ai-test-instructions.md`). Plan **reading and authoring** (including MCP create/update flows) use [`references/test-planning.md`](references/test-planning.md). During `/testchimp test`, load [`references/api-testing.md`](references/api-testing.md) when a scenario is designated for API automation and [`references/write-smarttests.md`](references/write-smarttests.md) for UI SmartTests. Load [`references/environment-management.md`](references/environment-management.md) when choosing or provisioning test environments, EaaS (Bunnyshell), or branch-scoped `BASE_URL` resolution. Load [`references/truecoverage.md`](references/truecoverage.md) when RUM instrumentation, TrueCoverage planning, or TrueCoverage MCP tools are in scope. Deep **`ai-wright`** API detail lives in [`references/ai-wright-usage.md`](references/ai-wright-usage.md) — pull it in when authoring or debugging AI steps.

Environment provisioning contract:

- During `/testchimp init`, persist the **chosen** environment provisioning strategy under `plans/knowledge/ai-test-instructions.md` → `## Environment Provision Strategy`.\n  - If **Local - Test Authoring** is the chosen path, persist a single **local environment up** command/script and explicit **wait-for-healthy** criteria (so the agent can reliably bring the stack up locally, wait until it’s ready, then run seeds/tests).\n  - If **EaaS (Bunnyshell)** or **Branch Management** is chosen, persist the provisioning + wait approach (and how `BASE_URL`/`BACKEND_URL` are resolved).
- During `/testchimp test`, the agent must consult that decision file and bring the environment up (and wait until healthy) before executing any test cases (including world-state seeding/teardown between cases).

## References (this skill)

| Path | Purpose |
|------|---------|
| [`references/init-testchimp.md`](references/init-testchimp.md) | Phased init: optional quick smoke, collaborative plan, action-item execution |
| [`references/testing-process.md`](references/testing-process.md) | `/testchimp test` phased workflow: plan, setup, execute, cleanup |
| [`references/write-smarttests.md`](references/write-smarttests.md) | SmartTest authoring (UI tests with smart steps) details used by the execution phase |
| [`references/api-testing.md`](references/api-testing.md) | API test authoring workflow from captured browser network flows |
| [`references/test-planning.md`](references/test-planning.md) | Plan folder layout, frontmatter, `/testchimp plan`, MCP plan authoring |
| [`references/audit-coverage.md`](references/audit-coverage.md) | Coverage and execution audit playbook |
| [`references/truecoverage.md`](references/truecoverage.md) | TrueCoverage RUM setup, `plans/events/*.event.md`, MCP analytics |
| [`references/ai-wright-usage.md`](references/ai-wright-usage.md) | `ai-wright` install, env, API depth |
| [`references/environment-management.md`](references/environment-management.md) | Persistent vs ephemeral envs, Bunnyshell, Branch Management, MCP `get_branch_specific_endpoint_config` |
| [`assets/template_playwright.config.js`](assets/template_playwright.config.js) | Sample Playwright config (copy into SmartTests root) |
| [`assets/sample-mcp.json`](assets/sample-mcp.json) | Sample Cursor-style MCP config: `npx`, `testchimp-mcp-client@latest`, `TESTCHIMP_API_KEY` |


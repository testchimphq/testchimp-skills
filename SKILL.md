---
name: testchimp
description: Integrate repositories with TestChimp for QA orchestration — SmartTests (Playwright with Natural Language Steps), markdown test plans (read/author via MCP), coverage, and MCP tools. Use when the user mentions TestChimp, /testchimp commands (init, test, plan, audit), SmartTests, agent-driven test or plan authoring, or updating this skill from Git.
compatibility: Requires Node.js for Playwright tooling; TESTCHIMP_API_KEY for MCP and ai-wright. Network access for TestChimp APIs when using MCP or AI steps.
version: 0.1.2
---

# TestChimp

TestChimp is a **QA workflow orchestration layer for AI agents**. It provides:

- **Requirement traceability** via structured comments in tests (e.g. `// @Scenario: #TS-101 Title`) linking SmartTests to scenarios.
- **Markdown test plans** in a mapped `plans/` folder (YAML frontmatter, `stories/` / `scenarios/` / `knowledge/`) — how to read and author them in [`references/test-planning.md`](references/test-planning.md).
- **Intelligent Playwright steps** (`ai.act` / `ai.verify` / `ai.extract` with `ai-wright`) for more stable execution-time intelligent behavior in tests.
- **Execution reporting** via `playwright-testchimp` so test execution details feed to TestChimp servers to enable coverage insights.

## Preamble checks (run first)

Before executing a TestChimp flow:

1. **Skill update check** — rely on the `version` in this file's frontmatter. Read the current version from the local `SKILL.md`, then fetch the remote `SKILL.md` from the published repo (`https://github.com/testchimphq/testchimp-skills`, see **Updating this skill from Git** below) and compare frontmatter versions. If the remote version is newer, tell the user an update is available and ask whether to update now (`/testchimp update`). If the user agrees to update the version, proceed with the update - as noted in the below section.

2. **Decision memory check** — locate `TESTCHIMP_SKILL_DIR/bin/.init-has-run`. If missing, tell user that it seems init hasn't run, and ask whether to run now (highly recommend) - and if agreed do (follow flow for `/testchimp init`).

## How TestChimp works

1. Create a project in TestChimp and connect the Git repo. Map 2 folders in the repo to the project created in TestChimp platform **`tests`** (SmartTests) and **`plans`** (test plans). Those can be mapped after logging in to TestChimp -> Select Project -> Project Settings -> Integrations -> GitHub.
2. TestChimp creates **folder marker files** (empty): `.testchimp-tests` under tests root, `.testchimp-plans` under plans root so paths are recognizable - so you can identify the mapped folders using those markers.
3. Run SmartTests with Playwright; install **`playwright-testchimp`** as documented in [`references/write-smarttests.md`](references/write-smarttests.md). This also pulls in `ai-wright` for enabling execution time intelligent steps.
4. Local and CI calls to TestChimp APIs are authenticated via **`TESTCHIMP_API_KEY`** env var (note that this is a project specific key - so it should be used scoped per project).

## MCP client (agents)

Install **`testchimp-mcp-client`** and configure below environment vars:

- `TESTCHIMP_API_KEY` (required)

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

Per the [Agent Skills specification](https://agentskills.io/specification), this skill keeps **`SKILL.md`** as the entrypoint. **Load a reference file only when** the task matches that flow (`/init`, `/test`, `/plan`, `/audit`, TrueCoverage setup/instrument). During `/testchimp init`, follow the phased init workflow (optional quick smoke first, then collaborative plan, then execute item-by-item with progress persisted in `plans/knowledge/ai-test-instructions.md`). Plan **reading and authoring** (including MCP create/update flows) use [`references/test-planning.md`](references/test-planning.md). During `/testchimp test`, load [`references/api-testing.md`](references/api-testing.md) when a scenario is designated for API automation and [`references/write-smarttests.md`](references/write-smarttests.md) for UI SmartTests. Load [`references/environment-management.md`](references/environment-management.md) when choosing or provisioning test environments, EaaS (Bunnyshell), or branch-scoped `BASE_URL` resolution. Load [`references/truecoverage.md`](references/truecoverage.md) when `.truecoverage_setup`, RUM instrumentation, or TrueCoverage MCP tools are in scope. Deep **`ai-wright`** API detail lives in [`references/ai-wright-usage.md`](references/ai-wright-usage.md) — pull it in when authoring or debugging AI steps.

## References (this skill)

| Path | Purpose |
|------|---------|
| [`references/init-testchimp.md`](references/init-testchimp.md) | Phased init: optional quick smoke, collaborative plan, action-item execution |
| [`references/testing-process.md`](references/testing-process.md) | `/testchimp test` phased workflow: plan, setup, execute, cleanup |
| [`references/write-smarttests.md`](references/write-smarttests.md) | SmartTest authoring (UI tests with smart steps) details used by the execution phase |
| [`references/api-testing.md`](references/api-testing.md) | API test authoring workflow from captured browser network flows |
| [`references/test-planning.md`](references/test-planning.md) | Plan folder layout, frontmatter, `/testchimp plan`, MCP plan authoring |
| [`references/audit-coverage.md`](references/audit-coverage.md) | Coverage and execution audit playbook |
| [`references/truecoverage.md`](references/truecoverage.md) | TrueCoverage RUM setup, `.truecoverage_setup`, `plans/events/`, MCP analytics |
| [`references/ai-wright-usage.md`](references/ai-wright-usage.md) | `ai-wright` install, env, API depth |
| [`references/environment-management.md`](references/environment-management.md) | Persistent vs ephemeral envs, Bunnyshell, Branch Management, MCP `get_branch_specific_endpoint_config` |
| [`assets/template_playwright.config.js`](assets/template_playwright.config.js) | Sample Playwright config (copy into SmartTests root) |


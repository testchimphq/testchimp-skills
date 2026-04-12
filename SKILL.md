---
name: testchimp
description: Integrate repositories with TestChimp for QA orchestration — SmartTests (Playwright with Natural Language Steps), markdown test plans (read/author via MCP), coverage, and MCP tools. Use when the user mentions TestChimp, /testchimp commands (init, test, plan, audit), SmartTests, agent-driven test or plan authoring, or updating this skill from Git.
compatibility: Requires Node.js for Playwright tooling; TESTCHIMP_API_KEY for MCP and ai-wright. Network access for TestChimp APIs when using MCP or AI steps.
---

# TestChimp

TestChimp is a **QA workflow orchestration layer for AI agents**. It provides:

- **Requirement traceability** via structured comments in tests (e.g. `// @Scenario: #TS-101 Title`) linking SmartTests to scenarios.
- **Markdown test plans** in a mapped `plans/` folder (YAML frontmatter, `stories/` / `scenarios/` / `knowledge/`) — how to read and author them in [`references/test-planning.md`](references/test-planning.md).
- **Intelligent Playwright steps** (`ai.act` / `ai.verify` / `ai.extract` with `ai-wright`) for more stable execution-time intelligent behavior in tests.
- **Execution reporting** via `playwright-testchimp-reporter` so test execution details feed to TestChimp servers to enable coverage insights.

## How it works

1. Create a project in TestChimp and connect the Git repo. Map 2 folders in the repo to the project created in TestChimp platform **`tests`** (SmartTests) and **`plans`** (test plans). Those can be mapped after logging in to TestChimp -> Select Project -> Project Settings -> Integrations -> GitHub.
2. Use **folder marker files** (empty): `.testchimp-tests` under tests root, `.testchimp-plans` under plans root so paths are recognizable.
3. Run SmartTests with Playwright; install **`playwright-testchimp-reporter`** and add **`ai-wright`** + reporter **runtime** imports in specs as documented in [`references/write-smarttests.md`](references/write-smarttests.md).
4. Authenticate integration with env var **`TESTCHIMP_API_KEY`**.

## MCP client (agents)

Install **`testchimp-mcp-client`** and configure below environment vars:

- `TESTCHIMP_API_KEY` (required)

The MCP server exposes tools: `get_requirement_coverage`, `get_execution_history`, `create_user_story`, `create_test_scenario`, `update_user_story`, `update_test_scenario`. Use the repo, plans, and those tools to decide what to test;

## Command routing

| User says | Read |
|-----------|------|
| `/testchimp init` | [`references/init-testchimp.md`](references/init-testchimp.md) |
| `/testchimp test` | [`references/write-smarttests.md`](references/write-smarttests.md) |
| `/testchimp plan` | [`references/test-planning.md`](references/test-planning.md) |
| `/testchimp audit` | [`references/audit-coverage.md`](references/audit-coverage.md) |

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

Per the [Agent Skills specification](https://agentskills.io/specification), this skill keeps **`SKILL.md`** as the entrypoint. **Load a reference file only when** the task matches that flow (`/init`, `/test`, `/plan`, `/audit`). Plan **reading and authoring** (including MCP create/update flows) use [`references/test-planning.md`](references/test-planning.md). Deep **`ai-wright`** API detail lives in [`references/ai-wright-usage.md`](references/ai-wright-usage.md) — pull it in when authoring or debugging AI steps.

## References (this skill)

| Path | Purpose |
|------|---------|
| [`references/init-testchimp.md`](references/init-testchimp.md) | Bootstrap repo, markers, CI, MCP |
| [`references/write-smarttests.md`](references/write-smarttests.md) | Authoring SmartTests, MCP shapes, examples |
| [`references/test-planning.md`](references/test-planning.md) | Plan folder layout, frontmatter, `/testchimp plan`, MCP plan authoring |
| [`references/audit-coverage.md`](references/audit-coverage.md) | Coverage and execution audit playbook |
| [`references/ai-wright-usage.md`](references/ai-wright-usage.md) | `ai-wright` install, env, API depth |
| [`assets/template_playwright.config.js`](assets/template_playwright.config.js) | Sample Playwright config (copy into SmartTests root) |

When copying the template into an app repo, copy **only** `assets/template_playwright.config.js` (or its contents) into the directory that contains **`.testchimp-tests`** — do not require the app to vendor the whole skill tree.

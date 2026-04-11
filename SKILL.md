---
name: testchimp
description: Integrate repositories with TestChimp for QA orchestration — SmartTests (Playwright with Natural Language Steps), markdown test plans, coverage, and MCP tools. Use when the user mentions TestChimp, @testchimp commands, SmartTests, or agent-driven test authoring.
---

# TestChimp

TestChimp is a **QA workflow orchestration layer for AI agents**. It provides:

- **Requirement traceability** via structured comments in tests (e.g. `// @Scenario: #TS-101 Title`) linking SmartTests to scenarios.
- **Markdown test plans** in a mapped `plans/` folder (synced from the TestChimp app).
- **Intelligent Playwright steps** (`ai.act` / `ai.verify` / `ai.extract` with `ai-wright`) for more stable execution-time intelligent behavior in tests.
- **Execution reporting** via `playwright-testchimp-reporter` so test execution details feed to TestChimp servers to enable coverage insights.

## How it works

1. Create a project in TestChimp and connect the Git repo. Map 2 folders in the repo to the project created in TestChimp platform **`tests`** (SmartTests) and **`plans`** (test plans). Those can be mapped after logging in to TestChimp -> Select Project -> Project Settings -> Integrations -> GitHub.
2. Use **folder marker files** (empty): `.testchimp-tests` under tests root, `.testchimp-plans` under plans root so paths are recognizable.
3. Run SmartTests with Playwright; install **`playwright-testchimp-reporter`** and add **`ai-wright`** + reporter **runtime** imports in specs as documented in `write-smarttests.md`.
4. Authenticate integration with env var **`TESTCHIMP_API_KEY`**.

## MCP client (agents)

Install **`testchimp-mcp-client`** and configure below environment vars:

- `TESTCHIMP_API_KEY` (required)

The MCP server exposes tools: `get_requirement_coverage`, `get_execution_history`, `get_test_advice`.

## Command routing

| User says | Open |
|-----------|------|
| `@testchimp /init` | `init-testchimp.md` |
| `@testchimp /test` | `write-smarttests.md` |
| `@testchimp /audit` | `audit-coverage.md` |

If the user asks semantically similar requests ("Setup TestChimp", "Write Tests for the PR", "Analyze requirement coverage" etc.) - use the proper skills referring the sub documents.

## Coverage scope note

`get_requirement_coverage` supports platform-rooted paths under both **`tests/...`** and **`plans/...`**.
When a `plans/...` folder is provided, coverage resolves SmartTests linked to scenarios in that plan scope.
`scope.folderPath` should be provided using **platform paths** (rooted at `tests` or `plans`), even when the mapped repo folders use different names (for example, if mapped repo folder for `tests` in the repo is `ui_tests` then to ask for coverage for `ui_tests/checkout`, the scope you request should be for `tests/checkout`).

## References

- `init-testchimp.md` — bootstrap repo + CI + MCP setup
- `write-smarttests.md` — authoring SmartTests.
- `audit-coverage.md` — coverage gaps and execution history
- `template_playwright.config.js` — sample Playwright config with TestChimp reporter installed.

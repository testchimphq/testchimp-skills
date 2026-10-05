# Installing TestChimp for an AI agent

TestChimp works through an MCP server plus this agent skill. No local build is needed.

Install the MCP server at project level (Cursor: `.cursor/mcp.json`; Claude Code: `.mcp.json` in the app repo), not in user-level config. TestChimp API keys are scoped to a single project.

**Use one option, not both.** IDE plugins may register the hosted server at user level for all workspaces. To add a manual server at project scope with Claude Code, use `claude mcp add --scope project` when configuring the server manually (plugin installs register at user level by default).

## Option A: hosted MCP server (recommended)
- URL: `https://mcp.testchimp.io/mcp`
- Auth: OAuth 2.1. The client opens a browser sign-in on first use, where you pick the TestChimp project; no API key is stored in config.
- Plugin installs: the `.mcp.json`, `.cursor-plugin/plugin.json`, `gemini-extension.json`, and `.codex-plugin/plugin.json` files in this repo register the hosted server. They bind to one TestChimp project per user across all workspaces. To use different projects per workspace, configure the stdio server below at project level instead.

```json
{
  "mcpServers": {
    "testchimp": {
      "type": "http",
      "url": "https://mcp.testchimp.io/mcp"
    }
  }
}
```

## Option B: local stdio server
Requires Node.js 18+ and a TestChimp project API key (TestChimp app: Project Settings, API key).

```json
{
  "mcpServers": {
    "testchimp": {
      "command": "npx",
      "args": ["-y", "@testchimp/cli@latest", "mcp"],
      "env": {
        "TESTCHIMP_API_KEY": "<your project API key>",
        "TESTCHIMP_USER_ID": "<your user ID>",
        "TESTCHIMP_PROJECT_ID": "<your project ID>"
      }
    }
  }
}
```

`TESTCHIMP_USER_ID` is optional but needed for get-my-tasks, list-tests-awaiting-verification, and run attribution.

## Skill
Install the workflow skill so the agent knows when and how to use the tools:

```bash
npx skills add testchimphq/testchimp-skills
```

## Verify
Ask the agent: "Use TestChimp to show the QA posture for this project." It should call `get-qa-posture`.

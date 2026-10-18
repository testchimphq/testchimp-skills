# Installing TestChimp for an AI agent

TestChimp works through an MCP server plus this agent skill. No local build is needed.

**Claude Code:** install the plugin, then sign in once. The plugin registers the hosted server at user level.

```
/plugin marketplace add testchimphq/testchimp-skills
/plugin install testchimp@testchimp
```

Restart the Claude Code session so the plugin loads. Then `/mcp` → **plugin:testchimp:testchimp** → **Authenticate**. On the consent screen, pick this repository's TestChimp project and leave **Use this connection as my QA bot** unticked (that box is for Grok Bot). One person runs `/testchimp project init`; everyone else runs `/testchimp init`.

## Option A: hosted MCP server (recommended)

- URL: `https://mcp.testchimp.io/mcp`
- Auth: OAuth 2.1. The client opens a browser sign-in on first use, where you pick the TestChimp project; no API key is stored in config.
- Plugin installs: the `.mcp.json`, `.cursor-plugin/plugin.json`, `gemini-extension.json`, and `.codex-plugin/plugin.json` files in this repo register that same global URL. The token is scoped to the project picked at consent. To work on a different project's repo, re-authenticate through the host's MCP UI and pick that project.

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

Requires Node.js 18+ and a TestChimp project API key (TestChimp app: Project Settings, API key). Use this only when you are not using the plugin.

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

Claude Code plugin users already have the skill; they do not need this extra install.

## Verify

Ask the agent: "Use TestChimp to show the QA posture for this project." It should call `get-qa-posture`.

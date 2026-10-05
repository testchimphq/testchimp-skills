# Installing TestChimp for an AI agent

TestChimp works through an MCP server plus this agent skill. No local build is needed.

## Option A: hosted MCP server (recommended)
- URL: `https://mcp.testchimp.io/mcp` (Streamable HTTP)
- Auth: OAuth 2.1. The client opens a browser sign-in on first use; no API key is stored in config.

```json
{ "mcpServers": { "testchimp": { "url": "https://mcp.testchimp.io/mcp" } } }
```

## Option B: local stdio server
Requires Node.js 18+ and a TestChimp project API key (TestChimp app: Project Settings, API key).

```json
{
  "mcpServers": {
    "testchimp": {
      "command": "npx",
      "args": ["-y", "@testchimp/cli@latest", "mcp"],
      "env": { "TESTCHIMP_API_KEY": "<your project API key>" }
    }
  }
}
```

## Skill
Install the workflow skill so the agent knows when and how to use the tools:

```bash
npx skills add testchimphq/testchimp-skills
```

## Verify
Ask the agent: "Use TestChimp to show the QA posture for this project." It should call `get-qa-posture`.

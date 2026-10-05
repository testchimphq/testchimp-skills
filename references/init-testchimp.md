# /testchimp init

**Per developer / workstation** — register local MCP, verify CLI connectivity, and wire a **local test environment** for authoring. Runs even when **`/testchimp project init`** is incomplete; offer to continue remaining project-setup gaps via [`project-init-testchimp.md`](./project-init-testchimp.md).

**Project-level setup** (folder mapping, CI, shared test env, imports) → **`/testchimp project init`** ([`project-init-testchimp.md`](./project-init-testchimp.md)).

---

## Opening message (required)

When **`/testchimp init`** starts, tell the user:

- This flow sets up **their machine** (MCP client, API key, local stack / env) so they can run TestChimp workflows from their coding agent.
- **One-time project setup** (if not done) is **`/testchimp project init`** — ChimpHands or a lead dev runs it once per repo.
- After both are done, they mainly run **`/testchimp test`** on PRs; periodically **`/testchimp upkeep`** / **`/testchimp evolve`**.

Include: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Workstation gate (always first)

1. **Project MCP file** — if TestChimp MCP tools are already available in the session (e.g. plugin-provided server) or a working TestChimp entry already exists (manual `npx` + `env`, TestChimp Studio's `.testchimp/mcp.json`, or a remote `url`), keep it. Otherwise offer the setups below; **manual is the default** unless the user picks another:
   - **Manual (default):** create or merge from [`../assets/sample-mcp.json`](../assets/sample-mcp.json) (`.cursor/mcp.json`, `.mcp.json`, or Codex `config.toml`). Real **`TESTCHIMP_API_KEY`** + **`TESTCHIMP_PROJECT_ID`** (and **`TESTCHIMP_USER_ID`** when known — needed for get-my-tasks / list-tests-awaiting-verification and run attribution); reload MCP after edits.
   - **TestChimp Studio:** map the folder in Studio; it writes `.testchimp/mcp.json` with the key. Nothing to paste.
   - **Remote MCP (OAuth):** see [Remote MCP (OAuth) setup](#remote-mcp-oauth-setup). Nothing to paste.
   - **Never configure both** a manual and a remote TestChimp server in the same project MCP file.
2. **CLI connectivity** — **`get-eaas-config`** `{}` (auth gate). Empty config is OK.
3. **Runner key** — confirm **Preamble checks #4** resolves **`TESTCHIMP_API_KEY`** for runners (for remote MCP this is the `save-creds` step below).
4. **Optional gaps** — call **`get-project-init-status`**. If `overall_complete` is false, summarize missing required items and ask whether to run **`/testchimp project init`** now or defer.

Do **not** infer workstation setup from git — check local config every time.

### Remote MCP (OAuth) setup

Additive option: the IDE talks to TestChimp's hosted MCP server and signs in with OAuth, so no key goes into IDE config. Existing manual and Studio setups are unaffected.

1. Get the project id (TestChimp → Project Settings, or `get-project-init-status` once connected) and write the **project-level** MCP file for the user's host from [`../assets/sample-mcp.remote.json`](../assets/sample-mcp.remote.json), replacing `<project-id>`:
   - **Cursor:** `.cursor/mcp.json` — `{"mcpServers": {"testchimp": {"url": "https://mcp.testchimp.io/mcp?projectId=<project-id>"}}}`
   - **Claude Code:** `.mcp.json` — `{"mcpServers": {"testchimp": {"type": "http", "url": "https://mcp.testchimp.io/mcp?projectId=<project-id>"}}}`
   - **VS Code / Copilot:** `.vscode/mcp.json` — `{"servers": {"testchimp": {"type": "http", "url": "https://mcp.testchimp.io/mcp?projectId=<project-id>"}}}`
   - **Codex:** `.codex/config.toml` (trusted projects only) — `[mcp_servers.testchimp]` with `url = "https://mcp.testchimp.io/mcp?projectId=<project-id>"`, then `codex mcp login testchimp`.

   The `projectId` is not a secret, so this file can be committed; each repo names its own project, and one sign-in covers every project the user belongs to. Staging / enterprise: use that deployment's MCP host.
2. Ask the user to reload MCP and complete the browser sign-in (approve the consent page).
3. **Claude Code with the TestChimp plugin:** the plugin's own TestChimp server uses the plain URL, so both would load. Ask the user to turn the plugin's server off for this repo in `/mcp`.
4. Save the runner key once: call **`get-project-credentials`**, then pipe only the key: `printf '%s' "<projectApiKey>" | testchimp workspace save-creds --folder <git root> --project-id <projectId> --project-name "<projectName>" --backend-url <backendUrl> --ingress-url <ingressUrl>`. This writes the gitignored `.testchimp/mcp.json` (Studio's format) that **Preamble checks #4** reads. Never print the key.

---

## Local test environment

Follow **`connect-to-test-env.policy.md`** when present; else (legacy only) read **`plans/knowledge/ai-test-instructions.md` → Environment Provision Strategy → Local - Test Authoring** if that file already exists.

- Bring up the documented local stack (compose script, wait-for-healthy).
- Export **`BASE_URL`** / **`BACKEND_URL`** as documented.
- Run a minimal smoke (existing `@smoke` or one SmartTest) when feasible; record durable bring-up learnings in **`connect-to-test-env.policy.md`** (upsert-policy). Append FAQ Q/A only if **`ai-test-instructions.md` already exists**.

TrueCoverage is **not** part of thin init — use **`/testchimp setup truecoverage`** or **`/testchimp instrument`** when needed ([`instrument-truecoverage.md`](./instrument-truecoverage.md)).

---

## Completion

Thin init is **done** when:

- MCP works (`get-eaas-config` succeeds) and runners have the API key (**Preamble checks #4**; remote MCP: `.testchimp/mcp.json` saved).
- Local test env strategy is documented or verified on this machine.
- User knows how to run **`/testchimp test`** and where project-level status lives (`get-project-init-status`).

Best-effort **`report-agent-action`** with `workflowId: init` after connectivity check.

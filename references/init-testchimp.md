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

1. **Check for existing TestChimp server**:
   - First check if testchimp tools are already available (plugin-provided server).
   - If not, scan for a project MCP file with a testchimp server entry (`.cursor/mcp.json`, `.mcp.json`, or Codex `config.toml`).
   - If a working testchimp server exists (remote OAuth URL or stdio with valid config), **skip MCP setup** and proceed to step 2.
   - If no server exists, offer the user a choice:
     * **Hosted server** (recommended): uses `https://mcp.testchimp.io/mcp` with OAuth (no API key in config).
     * **Local stdio server**: uses `npx -y @testchimp/cli@latest mcp` with `TESTCHIMP_API_KEY` and `TESTCHIMP_USER_ID` in env.
   - Write the chosen server configuration to the project MCP file (prefer `.cursor/mcp.json` or `.mcp.json`).
   - For stdio: copy from [`../assets/sample-mcp.json`](../assets/sample-mcp.json) with real **`TESTCHIMP_API_KEY`**, **`TESTCHIMP_USER_ID`**, and **`TESTCHIMP_PROJECT_ID`**.
   - For remote: copy from [`../assets/.mcp.json`](../.mcp.json) (just the URL, OAuth handles auth).
   - **Never configure both servers** in the same project.
   - After adding or updating config, tell the user to reload MCP in their client.

2. **CLI connectivity** — **`get-eaas-config`** `{}` (auth gate). Empty config is OK.
3. **Optional gaps** — call **`get-project-init-status`**. If `overall_complete` is false, summarize missing required items and ask whether to run **`/testchimp project init`** now or defer.

Do **not** infer workstation setup from git — check local config every time.

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

- MCP + API key work (`get-eaas-config` succeeds).
- Local test env strategy is documented or verified on this machine.
- User knows how to run **`/testchimp test`** and where project-level status lives (`get-project-init-status`).

Best-effort **`report-agent-action`** with `workflowId: init` after connectivity check.

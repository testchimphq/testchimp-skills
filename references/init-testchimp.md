# /testchimp init

**Per developer / workstation** — confirm the TestChimp MCP connection, save a runner API key, and wire a **local test environment** for authoring. Runs even when **`/testchimp project init`** is incomplete; offer to continue remaining project-setup gaps via [`project-init-testchimp.md`](./project-init-testchimp.md).

**Project-level setup** (folder mapping, CI, shared test env, imports) → **`/testchimp project init`** ([`project-init-testchimp.md`](./project-init-testchimp.md)). One person runs that once per project. Every other teammate then runs only **`/testchimp init`**.

---

## Opening message (required)

When **`/testchimp init`** starts, tell the user:

- This flow sets up **their machine** (MCP sign-in, runner API key, local stack / env) so they can run TestChimp workflows from their coding agent.
- **One-time project setup** (if not done) is **`/testchimp project init`** — ChimpHands or a lead dev runs it once per repo.
- After both are done, they mainly run **`/testchimp test`** on PRs; periodically **`/testchimp upkeep`** / **`/testchimp evolve`**.

Include: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Workstation gate (always first)

**Claude Code plugin (preferred when installed):** the plugin already registered `https://mcp.testchimp.io/mcp`. Do **not** write a second TestChimp server into the project's `.mcp.json`. One global URL, one sign-in. The project is the one the user picked on the OAuth consent screen.

1. **MCP connection**
   - If TestChimp MCP tools are already available in the session (plugin server, Studio `.testchimp/mcp.json`, a working remote `url`, or stdio `npx` + `env`), keep that connection.
   - If tools are missing, return **401**, or the server shows as needing authentication: tell the user to run **`/mcp`**, choose **`plugin:testchimp:testchimp`** (or the TestChimp server), then **Authenticate**. On the consent page they pick the TestChimp project for **this** repo. Then stop and wait — do not invent a project-level MCP file.
   - If the plugin is not installed and no TestChimp server exists, offer the setups below; **plugin / remote OAuth is the default** when the user is in Claude Code, otherwise **manual** is the default unless they pick another:
     - **Remote MCP (OAuth):** see [Remote MCP (OAuth) setup](#remote-mcp-oauth-setup). Nothing to paste.
     - **Manual:** create or merge from [`../assets/sample-mcp.json`](../assets/sample-mcp.json) (`.cursor/mcp.json`, `.mcp.json`, or Codex `config.toml`). Real **`TESTCHIMP_API_KEY`** + **`TESTCHIMP_PROJECT_ID`** (and **`TESTCHIMP_USER_ID`** when known — needed for get-my-tasks / list-tests-awaiting-verification and run attribution); reload MCP after edits.
     - **TestChimp Studio:** map the folder in Studio; it writes `.testchimp/mcp.json` with the key. Nothing to paste.
     - **Never configure both** a manual and a remote TestChimp server in the same project MCP file.
2. **Identify the signed-in project** — call **`get-project-credentials`** (or **`get-project-init-status`** if credentials are unavailable). Tell the user the **`projectName`** / **`projectId`** the connection is scoped to. That is the project picked at OAuth consent (or named by a stdio API key).
3. **Detect a project mismatch (blocking)** — the plugin MCP is user-level and one OAuth token is bound to one project. If this repo belongs to a different project, every tool call will hit the wrong one. Compare:
   - gitignored **`<repo>/.testchimp/mcp.json`** `env.TESTCHIMP_PROJECT_ID` (when the file exists)
   - **`get-git-folder-mapping`**: `repository` / `repository_full_name` against this repo's remotes (`git remote -v`, `owner/repo`)
   - On-disk **`.testchimp-plans`** / **`.testchimp-tests`** markers that already map this tree, while the signed-in project's folder mapping points at a different repo
   If any of those disagree with the signed-in `projectId`, **stop**. Tell the user this session is signed in to **project A** while this repo is bound to **project B**. They must re-authenticate: **`/mcp`** → TestChimp → **Authenticate** (or **Clear authentication** then **Authenticate**), and pick **this** repo's project on the consent dropdown. Do not write a `?projectId=` URL or a second server. After they sign in again, re-run this gate.
4. **CLI connectivity** — **`get-eaas-config`** `{}` (auth gate). Empty config is OK.
5. **Runner key** — confirm **Preamble checks #4** resolves **`TESTCHIMP_API_KEY`** for runners (for plugin / remote MCP this is the `save-creds` step below).
6. **Optional gaps** — call **`get-project-init-status`**. If `overall_complete` is false, summarize missing required items and ask whether to run **`/testchimp project init`** now or defer.

Do **not** infer workstation setup from git — check local config every time.

### Remote MCP (OAuth) setup

Additive option when the Claude Code plugin is **not** already providing the server: the IDE talks to TestChimp's hosted MCP at the **global** URL and signs in with OAuth, so no key goes into IDE config. The user picks the project on the consent screen. Existing manual and Studio setups are unaffected.

1. Write the **project-level** MCP file for the user's host from [`../assets/sample-mcp.remote.json`](../assets/sample-mcp.remote.json) — always the plain URL, **no** `?projectId=`:
   - **Cursor:** `.cursor/mcp.json` — `{"mcpServers": {"testchimp": {"url": "https://mcp.testchimp.io/mcp"}}}`
   - **Claude Code (no plugin):** `.mcp.json` — `{"mcpServers": {"testchimp": {"type": "http", "url": "https://mcp.testchimp.io/mcp"}}}`
   - **VS Code / Copilot:** `.vscode/mcp.json` — `{"servers": {"testchimp": {"type": "http", "url": "https://mcp.testchimp.io/mcp"}}}`
   - **Codex:** `.codex/config.toml` (trusted projects only) — `[mcp_servers.testchimp]` with `url = "https://mcp.testchimp.io/mcp"`, then `codex mcp login testchimp`.

   Staging / enterprise: use that deployment's MCP host. **Claude Code with the TestChimp plugin:** skip this write. The plugin already registered the same URL; a second entry would load a duplicate server.
2. Ask the user to reload MCP and complete the browser sign-in. On the consent page they pick the TestChimp project for this repo.
3. If tools come back for the wrong project, follow the **mismatch** step in the workstation gate (`/mcp` → re-authenticate, pick the correct project).
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

- MCP works (`get-eaas-config` succeeds) against **this** repo's TestChimp project, and runners have the API key (**Preamble checks #4**; plugin / remote MCP: `.testchimp/mcp.json` saved).
- Local test env strategy is documented or verified on this machine.
- User knows how to run **`/testchimp test`** and where project-level status lives (`get-project-init-status`).

Best-effort **`report-agent-action`** with `workflowId: init` after connectivity check.

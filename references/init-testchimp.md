# /testchimp init

**Per developer / workstation** — confirm the TestChimp MCP connection, save a runner API key, and wire a **local test environment** for authoring. Runs even when project init is incomplete; offer to continue remaining project-setup gaps via [`project-init-testchimp.md`](./project-init-testchimp.md).

**Claude Code plugin command:** **`/testchimp init`**. The `/` menu alias is **`/testchimp:init`**. Do **not** tell users to run `/testchimp:testchimp init`. Other hosts: **`/testchimp init`**.

**Project-level setup** (folder mapping, CI, shared test env, imports) → **`/testchimp project-init`** / **`/testchimp:project-init`** / **`/testchimp project init`** ([`project-init-testchimp.md`](./project-init-testchimp.md)). One person runs that once per project. Every other teammate then runs only init.

---

## Opening message (required)

When init starts, tell the user:

- This flow sets up **their machine** (MCP sign-in, runner API key, local stack / env) so they can run TestChimp workflows from their coding agent.
- **One-time project setup** (if not done) is **`/testchimp project-init`** (Claude Code menu **`/testchimp:project-init`**) — ChimpHands or a lead dev runs it once per repo.
- After both are done, they mainly run **`/testchimp test`** on PRs; periodically **`/testchimp upkeep`** / **`/testchimp evolve`**.
- If the user declines a tool call, continue to the next step. Do not stall.

Include: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Workstation gate (always first)

**Plugin / extension already installed:** the host already registered `https://mcp.testchimp.io/mcp`. Do **not** write a second TestChimp server into the project's MCP file. One global URL, one sign-in. The project is the one the user picked on the OAuth consent screen.

**Host MCP sign-in** (when tools are missing or need re-auth):
- **Claude Code:** **`/mcp`** → **`plugin:testchimp:testchimp`** (or the TestChimp server) → **Authenticate**.
- **Cursor / Gemini CLI / Codex / Kiro / others:** the host’s MCP panel for the TestChimp server → Authenticate / reconnect.
- On the consent page they pick the TestChimp project for **this** repo and leave **Use this connection as my QA bot** **unticked** (that box is for Grok Bot). Then stop and wait — do not invent a project-level MCP file.

1. **MCP connection**
   - If TestChimp MCP tools are already available in the session (plugin server, Studio `.testchimp/mcp.json`, a working remote `url`, or stdio `npx` + `env`), keep that connection.
   - If tools are missing, return **401**, or the server shows as needing authentication: tell the user to complete **Host MCP sign-in** above.
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
   If any of those disagree with the signed-in `projectId`, **stop**. Tell the user this session is signed in to **project A** while this repo is bound to **project B**. They must re-authenticate via **Host MCP sign-in** above (clear authentication first if the host offers it), and pick **this** repo's project on the consent dropdown. Do not write a `?projectId=` URL or a second server. After they sign in again, re-run this gate.
4. **CLI connectivity** — **`get-eaas-config`** `{}` (auth gate). Empty config is OK. Do **not** use `ephemeral-environment action=CONFIG`.
5. **Runner key** — confirm **Preamble checks #4** resolves **`TESTCHIMP_API_KEY`** for runners. If the key is missing, follow [Save the runner key](#save-the-runner-key).
6. **Optional gaps** — call **`get-project-init-status`**. Read snake_case keys; if a key is missing, accept the camelCase twin (`overallComplete` for `overall_complete`, and the same for the item keys — [Reading init status](./project-init-testchimp.md#progress-tracking-platform)). If overall is not complete, summarize missing required items and ask whether to run **`/testchimp project-init`** / **`/testchimp:project-init`** now or defer.

Do **not** infer workstation setup from git — check local config every time.

### Remote MCP (OAuth) setup

Additive option when the Claude Code plugin is **not** already providing the server: the IDE talks to TestChimp's hosted MCP at the **global** URL and signs in with OAuth, so no key goes into IDE config. The user picks the project on the consent screen. Existing manual and Studio setups are unaffected.

1. Write the **project-level** MCP file for the user's host from [`../assets/sample-mcp.remote.json`](../assets/sample-mcp.remote.json) — always the plain URL, **no** `?projectId=`:
   - **Cursor:** `.cursor/mcp.json` — `{"mcpServers": {"testchimp": {"url": "https://mcp.testchimp.io/mcp"}}}`
   - **Claude Code (no plugin):** `.mcp.json` — `{"mcpServers": {"testchimp": {"type": "http", "url": "https://mcp.testchimp.io/mcp"}}}`
   - **VS Code / Copilot:** `.vscode/mcp.json` — `{"servers": {"testchimp": {"type": "http", "url": "https://mcp.testchimp.io/mcp"}}}`
   - **Codex:** `.codex/config.toml` (trusted projects only) — `[mcp_servers.testchimp]` with `url = "https://mcp.testchimp.io/mcp"`, then `codex mcp login testchimp`.

   Staging / enterprise: use that deployment's MCP host. **Claude Code with the TestChimp plugin:** skip this write. The plugin already registered the same URL; a second entry would load a duplicate server.
2. Ask the user to reload MCP and complete the browser sign-in. On the consent page they pick the TestChimp project for this repo and leave **Use this connection as my QA bot** unticked.
3. If tools come back for the wrong project, follow the **mismatch** step in the workstation gate (Host MCP sign-in, pick the correct project).
4. Save the runner key once — [Save the runner key](#save-the-runner-key).

---

## Save the runner key

Local Playwright / CLI / k6 need a project API key in gitignored **`<git root>/.testchimp/mcp.json`**. Never put the key in a shell command, and never echo or print it. Never run `testchimp workspace save-creds <key>` (no key on the command line). If the **`get-project-credentials`** tool description still mentions `testchimp workspace save-creds`, **ignore that line**.

**Already saved — do not rewrite:** If **`<git root>/.testchimp/mcp.json`** already has a non-placeholder **`TESTCHIMP_API_KEY`** and a **`TESTCHIMP_PROJECT_ID`** that matches the signed-in project (`get-project-credentials`), **leave the file**. Do not rewrite it to add `schemaVersion` / `enabled`. Missing those fields is fine — TestChimp Studio and older skill writes omit them. The preamble and CLI read `mcpServers.testchimp.env` either way.

### Hosted or plugin MCP (`https://mcp.testchimp.io/mcp`)

`save-workspace-creds` is **not** listed on the hosted / plugin server (it cannot write the laptop). That is expected on current prod, before CLI **0.1.93**. Do not stall waiting for the tool. Do this instead:

1. Call **`get-project-credentials`** (returns `projectId`, `projectName`, `projectApiKey`, `backendUrl`, `ingressUrl`).
2. Read **`<git root>/.testchimp/mcp.json`** if it exists. If it already has a real key and matching project id, **stop** (see **Already saved** above). Otherwise keep any other **`mcpServers`** entries and any extra `env` keys on `testchimp` (`TESTCHIMP_USER_ID`, existing backend/ingress); only replace or add the **`testchimp`** server.
3. Write the file with the **file-write tool** (not Bash / not a command that contains the key). **2-space JSON** and a **trailing newline**. Directory mode **0700**, file mode **0600** when the host can set them.

   If this session has **no file-write tool**, call **`save-workspace-creds`** `{ "folder": "<git root>" }` when that tool is listed. If neither Write nor `save-workspace-creds` is available, tell the user to create the file in their editor from the shape below (they paste the key; you never echo it) and continue.

   Production (`backendUrl` is `https://featureservice.testchimp.io` or omitted) — **omit** `TESTCHIMP_BACKEND_URL`:

   ```json
   {
     "schemaVersion": 1,
     "mcpServers": {
       "testchimp": {
         "command": "npx",
         "args": ["-y", "@testchimp/cli@latest", "mcp"],
         "env": {
           "TESTCHIMP_API_KEY": "<projectApiKey>",
           "TESTCHIMP_PROJECT_ID": "<projectId>",
           "TESTCHIMP_INGRESS_URL": "https://ingress.testchimp.io"
         },
         "enabled": true
       }
     }
   }
   ```

   Non-prod: set **`TESTCHIMP_BACKEND_URL`** to `backendUrl` with **no trailing slash**, and **`TESTCHIMP_INGRESS_URL`** to the matching `ingressUrl` from `get-project-credentials`.
4. **Permissions (Unix / macOS / Git Bash):** from the git root, run (no key in this command):

   ```bash
   chmod 700 .testchimp && chmod 600 .testchimp/mcp.json
   ```

   If `chmod` is missing (**Windows** without Git Bash) or the command fails, **continue** — do not treat that as a hard stop. Do not invent an `icacls` line that might print the path into a prompt with the key. If this session has **no shell**, skip this step after the file-write.
5. If `.gitignore` does not already ignore `.testchimp/`, append **exactly this one line and nothing else** — no extra paths, comments, or blanks added in the same edit:

   ```
   .testchimp/
   ```

   Do **not** add `mobilewright-report/`, `playwright-report/`, `test-results/`, `blob-report/`, or any other ignore in this step. Those report folders are a later, separate concern (SKILL.md Preamble checks #4). Never append markdown `---` (those are section breaks in this playbook).

### Local-npm or stdio MCP

If the MCP tool **`save-workspace-creds`** is listed (CLI / local `@testchimp/cli` ≥ **0.1.93**), call it with **only** the folder — never the key:

```json
{ "folder": "<git root>" }
```

Optional: `projectId`, `projectName`, `reassign`. The tool fetches the key from the current MCP auth and writes the same file (mode 0700 / 0600). The response must not include the key.

If **`save-workspace-creds`** is **not** listed (current hosted/prod MCP, or CLI older than **0.1.93**), use the hosted path above (`get-project-credentials` + file-write tool). Do not stall.

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

Best-effort **`report-agent-action`** with `workflowId: init` after connectivity check. First row (creates the run without closing it): `entityType: POLICY`, `actionType: ANALYZED` (or `CREATED` / `UPDATED` if you wrote that policy this step), `entityIdentity: connect-to-test-env.policy.md` — a real **`*.policy.md` filename**. The server **400**s `POLICY entity_identity must be a *.policy.md filename` if you send `init` or any other non-filename. Close later with the whole-run type: `entityType: WORKFLOW`, `actionType: ACTION_COMPLETED`, `entityIdentity: init` (must equal `workflowId`). Never send `WORKFLOW` + `ANALYZED`, and never send `POLICY` + `entityIdentity: init`. If you hit a TestChimp bug or docs gap, you may **`send-feedback`** after telling the user what you will send and why; if they decline the tool, continue.

# /testchimp connect-project

**Links this repo to one TestChimp project.** The only step that writes `.testchimp/creds.json`. Run it once per repo and per developer; after that every workflow knows which project it is working on.

**Claude Code plugin command:** **`/testchimp connect-project`** (menu alias **`/testchimp:connect-project`**). Other hosts: the same words. `/testchimp init` delegates here. `/testchimp check connectivity` is retired (see [`check-connectivity.md`](./check-connectivity.md)).

Not a catalog workflow: no plan file, no approval, no `report-agent-action`.

## Why this exists

The hosted MCP connector and the Claude Code plugin are installed **once per user**, so their sign-in names the **user**, not a project. The project comes from the repo: `<git root>/.testchimp/creds.json` (gitignored). Every hosted / plugin MCP call must pass that file's `projectId` as the **`projectId` tool argument**; TestChimp checks the signed-in user is a member of it.

## `.testchimp/creds.json`

```json
{
  "schemaVersion": 1,
  "projectId": "<projectId>",
  "projectName": "<projectName>",
  "projectApiKey": "<projectApiKey>",
  "userId": "<userId>",
  "backendUrl": "https://featureservice-staging.testchimp.io",
  "ingressUrl": "https://ingress-staging.testchimp.io"
}
```

- 2-space JSON, trailing newline. **Omit `backendUrl` / `ingressUrl` for production** (set both, no trailing slash, only for staging / enterprise). Optional `cliVersion` pins `npx @testchimp/cli@<version>` (testing release candidates); leave it out otherwise.
- Directory `.testchimp/` mode **0700**, file mode **0600**; `.testchimp/` is in `.gitignore`. Files readable by group or others are ignored by the CLI and the preamble.
- Env mapping for runners and the CLI: `projectApiKey` → `TESTCHIMP_API_KEY`, `projectId` → `TESTCHIMP_PROJECT_ID`, `userId` → `TESTCHIMP_USER_ID`, `backendUrl` → `TESTCHIMP_BACKEND_URL`, `ingressUrl` → `TESTCHIMP_INGRESS_URL`. The CLI reads the nearest file itself; Playwright / Mobilewright / k6 do **not**, so export these in the shell that runs them (see [`cli.md`](./cli.md#authentication-and-api-host-testchimp_api_key-testchimp_backend_url-testchimp_ingress_url)).
- Never print the key, never put it in a shell command, never ask the user to paste it in chat.

## Steps

1. **Check the preamble output.** If `TESTCHIMP_CREDS:` names a file and the user did not ask to switch projects, the repo is already linked: skip to step 6 (verify). If the user wants a different project, continue and confirm the overwrite before step 5.
2. **Legacy file with a real key (no network):** if the preamble found a legacy `.testchimp/mcp.json` (or another project MCP file) whose TestChimp `env` has a real `TESTCHIMP_API_KEY` and `TESTCHIMP_PROJECT_ID`, write `creds.json` from those values (`TESTCHIMP_USER_ID` too when present), then go to step 6. Leave the old file alone.
3. **List the projects.** Call **`list-projects`** `{}`. (stdio / API-key setups without OAuth cannot list: ask the user to copy `creds.json` from TestChimp, create-project wizard, **Install manually**.)
   - **No projects:** send the user to create one in TestChimp, then run this command again.
   - **One project:** confirm it in one line.
   - **Several:** suggest the likely match (repo folder or git remote name against `projectName`) and let the user pick, using the host's multiple-choice question tool when it has one.
4. **Fetch the key.** Call **`get-project-credentials`** with **`projectId`** set to the chosen project. It returns `projectId`, `projectName`, `projectApiKey`, `userId` (and `backendUrl` / `ingressUrl` on non-production deployments).
5. **Write the file** with the **file-write tool** (never Bash with the key in the command), keeping any `cliVersion` already in an existing file. Then, where a shell exists: `chmod 700 .testchimp && chmod 600 .testchimp/creds.json`. If `.gitignore` lacks `.testchimp/`, append exactly the line `.testchimp/`. If there is no file-write tool, tell the user to create the file in their editor from the shape above (they paste the key; you never echo it).
6. **Verify with one call:** **`get-eaas-config`** `{}` with `projectId` set to the repo's project (CLI: `testchimp get-eaas-config` from inside the repo). Any successful call is what TestChimp uses to show "your agent is connected" in the create-project wizard and setup guide, so make no other call first.
   - **Success:** "Linked this repo to **<projectName>** and connected." Then the [hand-back](./onboarding-next-step.md).
   - **401 / 403:** the user is not a member of that project, or the sign-in expired. Re-authenticate the TestChimp server (Claude Code: **`/mcp`**; claude.ai desktop: reconnect the connector) and run this command again.
   - **Network error:** check `backendUrl` and the network, then run it again.
   - **Tool missing:** the TestChimp server is not loaded in this session; install the plugin or connector from TestChimp's setup guide and restart the session.
   - If the hand-back still shows `LAUNCHPAD_STEP_CONNECT_AGENT` as `LAUNCHPAD_TODO` right after a successful call, TestChimp could not tell who you are: check `userId` is in `creds.json` and the CLI is **2.0.6 or later**, then restart the session. Never answer "Next: run `/testchimp connect-project`" right after this command.

## Rules for every other workflow

- Read `projectId` from `creds.json` (preamble prints it as `TESTCHIMP_PROJECT_ID:`) and pass it on **every** hosted / plugin MCP tool call. Never use a project id from memory or from a different repo.
- No `creds.json` and a hosted / plugin server: stop and run this command first (the preamble prints the action).
- Several repos or worktrees: each has its own `creds.json`; use the one at or above the directory you are working in.

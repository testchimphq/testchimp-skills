# Seamless agent connection + multi-project connector — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any TestChimp user connects an agent once per machine (user-scoped connector or plugin, plus a user-level skill) and links each repo to a project with `/testchimp connect-project`, so one connector works across many projects without re-authenticating.

**Architecture:** The OAuth bearer identifies the user. The repo's gitignored `.testchimp/creds.json` holds the project identity. The skill reads it, passes `projectId` as a tool argument on every hosted call (sent as `TestChimp-Project-Id`), and exports its values as env vars for test runners; the CLI reads it itself. The backend's existing membership check authorises the project. Platform MCP config files only ever hold the plain hosted URL. The web app's "Connect your agent" step becomes a per-agent dropdown.

**Tech Stack:** TypeScript MCP server and CLI (`testchimp-mcp-client`, node:test, zod); Java/Spring featureservice + protos (`AwareRepo/services`, Gradle/JUnit); React UI (`AwareRepo/ui`, Jest/RTL); skill markdown and one bash script (`testchimp-skills`).

**Spec:** this conversation's decisions (22–23 Nov 2026), summarised below. No separate spec doc.

## Global Constraints

- **Connector/plugin config is user-scoped:** the hosted URL is exactly `https://mcp.testchimp.io/mcp`, with no `?projectId=`, no headers, no key. The plugin's `.mcp.json` stays that way.
- **Project selection per call uses the project ID, never the key.** `projectApiKey` is sent only by QA bots (as today) and once per repo to learn a missing ID.
- **Header precedence** (existing `buildRequestHeaders`, unchanged): `projectApiKey` → `TestChimp-Api-Key`; else `projectId` → `TestChimp-Project-Id`. A `projectId` argument overrides `?projectId=` on the URL.
- **Project ID format:** `isValidProjectId` (`/^[A-Za-z0-9_-]{1,64}$/`) in `src/core/client.ts`.
- **`.testchimp/creds.json`** (flat, mode 0600, dir 0700, `.testchimp/` gitignored): `{ "schemaVersion": 1, "projectId": string, "projectName"?: string, "projectApiKey": string, "userId"?: string, "backendUrl"?: string, "ingressUrl"?: string, "cliVersion"?: string }`. It is not an MCP config. Never print the key or put it in a shell command.
- **Creds → runner env mapping** (one table, used by the skill and the CLI fallback): `projectApiKey`→`TESTCHIMP_API_KEY`, `projectId`→`TESTCHIMP_PROJECT_ID` (the Playwright reporter needs it for TrueCoverage), `userId`→`TESTCHIMP_USER_ID`, `backendUrl`→`TESTCHIMP_BACKEND_URL`, `ingressUrl`→`TESTCHIMP_INGRESS_URL`. `cliVersion` is not exported; it picks the CLI version the skill runs.
- **Read order everywhere** (CLI fallback, skill, preamble script, Studio): `.testchimp/creds.json` → legacy `.testchimp/mcp.json` → `.cursor/mcp.json` → `.mcp.json` → `mcp.json` → `.vscode/mcp.json` → `.github/mcp.json`, walking up to the git root. When `creds.json` is found the walk stops. Only new writes use `creds.json`; existing files keep working. Files that are group/world-readable are ignored (existing `isPrivateFile`).
- **Test runners read env only.** `@testchimp/playwright` (`~/IdeaProjects/playwright-testchimp-reporter`, v0.3.2) never reads `mcp.json` or any creds file; it reads `TESTCHIMP_API_KEY`, `TESTCHIMP_BACKEND_URL`, `TESTCHIMP_INGRESS_URL`, `TESTCHIMP_PROJECT_ID` from the environment (or reporter options). So the skill must export the mapped vars into the runner's shell, and no reporter change is needed.
- **`cliVersion`** (optional, for our own rc testing): the skill runs `npx @testchimp/cli@<cliVersion>` when set, else `@latest`. `backendUrl`/`ingressUrl` already point a repo at staging.
- **Skill install, all agents:** primary `npx skills add testchimphq/testchimp-skills -g -y` (same devX as `npx skills add dealpuffin/agent -g -y`); secondary, shown for every agent as "npx not working? copy this prompt", is the existing install prompt (`buildTestChimpInstallPrompt`) ending in `/testchimp connect-project`. Claude.ai's primary is the prompt. Claude Code plugin users do neither; the plugin carries the skill.
- **Claude Code install:** `/plugin install testchimp --marketplace testchimphq/testchimp-skills` (one command; assume a recent Claude Code).
- **Commands:** `/testchimp connect-project` is the only code that links a repo to a project. `/testchimp init` keeps the per-user workstation checks and local-test-env setup and calls connect-project for the linking step. `/testchimp check-connectivity` stays as a stub that prints "renamed to connect-project" and runs it.
- OAuth calls send no `user-id` header. `userId` in `creds.json` is for the stdio CLI only.
- **Out of scope:** removing the project pick from the OAuth consent page (still the default for calls with no repo, and QA-bot consent depends on it); `headersHelper`; any change to `@testchimp/playwright`.
- **Release order:** backend (T4) → hosted MCP and CLI (T1–T3) → skill (T6–T9) → web wizard (T5). The wizard goes last because it tells users to run commands that must already exist.

## Review Focus

1. **Stale ID:** `creds.json` names a project the user has left (403). The skill stops and says "run `/testchimp connect-project`"; it never falls back to the consent-page project. Covered in T7.
2. **Two files disagree:** `creds.json` and a legacy `.testchimp/mcp.json` name different projects. `creds.json` wins and the skill says so once. Covered in T3 and T6.
3. **Readable key file:** `creds.json` is mode 0644. The CLI ignores it and reports the path; connect-project fixes it with `chmod 600`. Covered in T3 and T8.
4. **No match / many matches:** repo remote matches no project, or two. connect-project shows the full list and never auto-picks. Covered in T8.
5. **Brand-new project:** created seconds ago, not yet in the 60-second membership cache. The first call must succeed. Covered in T4.

---

## Repo: testchimp-mcp-client

### Task 1: `projectId` binding argument on every hosted tool

**Files:**
- Modify: `src/mcp/server.ts` (`BINDING_ARGS`, `splitBindingArgs`, the tool handler in `createMcpServer`)
- Test: `src/mcp/httpServer.test.ts`

**Interfaces:**
- Produces: hosted tool arg `projectId?: string`; `splitBindingArgs(args) => { toolArgs, projectApiKey?, projectId?, botId? }`; `RequestAuth.projectId` set from the arg, falling back to the URL scope.

- [ ] **Step 1: Write failing tests** in the `remote MCP over HTTP` describe, following `"sends ?projectId= as TestChimp-Project-Id unless a projectApiKey names the project"`:
  - `"sends a projectId argument as TestChimp-Project-Id and strips it from the body"`: call `get-project-init-status` with `{ projectId: "proj-3" }`; upstream headers deep-equal `{ "Content-Type": "application/json", Authorization: "Bearer caller-jwt", "TestChimp-Project-Id": "proj-3" }`, upstream body `{}`.
  - `"a projectId argument overrides ?projectId= on the URL"`: `/mcp?projectId=proj-2` with `{ projectId: "proj-3" }` → `TestChimp-Project-Id: proj-3`.
  - `"projectApiKey wins over a projectId argument"`: both given → `TestChimp-Api-Key` present, `TestChimp-Project-Id` absent.
  - `"rejects a malformed projectId argument without calling TestChimp"`: `{ projectId: "../x y" }` → result `isError: true`, text contains `Invalid projectId`, upstream not called.
  - Extend the tools/list assertion (~line 298): every tool also has `inputSchema.properties.projectId`.
- [ ] **Step 2: Run** `npm test` → new tests FAIL.
- [ ] **Step 3: Implement.** Add `projectId: z.string().trim().min(1).max(64).optional()` to `BINDING_ARGS`, described as: "The TestChimp project this repo belongs to: projectId from the repo's .testchimp/creds.json. Pass it on every call when working in a repo. Not a secret." Reword `projectApiKey`'s description: "Project API key. QA bots: required on every call except get-bot-credentials, get-project-credentials and get-bot-compat. Others: only to look up a repo's projectId via get-project-credentials when its creds file has a key but no projectId. Prefer projectId. Never print it." In the handler, throw `Invalid projectId argument` when `isValidProjectId` fails; otherwise call `runWithRequestAuth({ ...auth, projectApiKey, projectId: projectId ?? auth.projectId, botId: botId ?? auth.botId }, …)`.
- [ ] **Step 4: Run** `npm test` → PASS.
- [ ] **Step 5: Commit** `feat(mcp): projectId binding argument selects the project per call`.

### Task 2: `list-projects` tool and `get-project-credentials` wording

**Files:**
- Modify: `src/core/tools.ts` (new definition beside `get-project-credentials`; edit that tool's description), `src/core/toolAnnotations.ts`, the tool-definitions doc the repo keeps in sync (see commit 6b9d194)
- Test: `src/core/tools.test.ts`

**Interfaces:**
- Consumes: backend `POST /api/mcp/list_my_projects` (T4) → `{ projects: [{ projectId, projectName, repoUrl? }] }`.
- Produces: tool `list-projects` (input `S.emptyInput`), returning the backend JSON unchanged.

- [ ] **Step 1: Write failing test** `"list-projects posts to /api/mcp/list_my_projects with an empty body"`, in the style of the existing `runTool` tests with a stub `postMcp`.
- [ ] **Step 2: Run** `npm test` → FAIL (unknown tool; the annotation test also fails until Step 3).
- [ ] **Step 3: Implement.** Description: "OAuth connections: list the TestChimp projects the signed-in user belongs to ({projectId, projectName, repoUrl?}). Used by /testchimp connect-project to bind a repo to a project. Needs no projectId." Add `"list-projects": readOnly("List Projects")`. In `get-project-credentials`, replace every `.testchimp/mcp.json` mention with `.testchimp/creds.json` and describe the project rule: "for the project named by the projectId argument, or by projectApiKey (which also tells you a key-only file's projectId); without either, the connection's default project (URL ?projectId=, else the consent pick)".
- [ ] **Step 4: Run** `npm test` → PASS.
- [ ] **Step 5: Commit** `feat(mcp): list-projects tool`.

### Task 3: `creds.json` read/write in the CLI, `cliVersion`, release

**Files:**
- Modify: `src/workspace/workspaceCredsFile.ts` (`WORKSPACE_DIR`, `workspaceMcpJsonPath`, `findWorkspaceCredsEnv`, `persistWorkspaceCreds`, `FALLBACK_ENV_KEYS`), `src/core/schemas.ts:562` (`saveWorkspaceCredsInput` wording), `src/core/client.ts:104` (error text), `CHANGELOG.md`, `package.json` `2.0.5` → `2.0.6`
- Test: `src/workspace/workspaceCredsFile.test.ts`

**Interfaces:**
- Produces: `export const WORKSPACE_CREDS_FILE = "creds.json"`; `findWorkspaceCredsEnv(startDir, onIgnored?) => { env, path, cliVersion? } | null` — applies the Global Constraints mapping table for `creds.json`, then falls back to legacy `.testchimp/mcp.json` per directory; `persistWorkspaceCreds` writes `<folder>/.testchimp/creds.json` (flat shape) and no longer writes `mcp.json`. The CLI's existing pre-action hook (`src/cli/program.ts:184`) is unchanged: it still applies the fallback only when `TESTCHIMP_API_KEY` is unset.

- [ ] **Step 1: Write failing tests:**
  - `"maps every creds.json field to its TESTCHIMP_* env var"`
  - `"prefers creds.json over a legacy .testchimp/mcp.json in the same directory"`
  - `"falls back to legacy .testchimp/mcp.json when there is no creds.json"` (existing behaviour kept)
  - `"ignores a group-readable creds.json and reports its path through onIgnored"`
  - `"persistWorkspaceCreds writes mode 0600 creds.json in a 0700 dir and gitignores .testchimp/"`
  - `"surfaces cliVersion from creds.json"`
- [ ] **Step 2: Run** `npm test` → FAIL.
- [ ] **Step 3: Implement.** Keep the nearest-ancestor walk; in each directory check `creds.json` first, then `mcp.json`. Add `TESTCHIMP_USER_ID` to `FALLBACK_ENV_KEYS`. Update the `save-workspace-creds` and `get-project-credentials` descriptions to say `creds.json`.
- [ ] **Step 4: Run** `npm test` → PASS.
- [ ] **Step 5: Commit** `feat(cli): .testchimp/creds.json (legacy mcp.json still read); release 2.0.6`. Open a PR; deploy hosted after T4 is live.

## Repo: AwareRepo

### Task 4: Backend — `list_my_projects`, membership re-check

**Files:**
- Modify: `services/protos/bots.proto` (`ListMyProjectsRequest {}`, `ListMyProjectsResponse { repeated McpProjectRef projects = 1; }`, `McpProjectRef { optional string project_id = 1; optional string project_name = 2; optional string repo_url = 3; }`), regenerate with `services/generate-java-protos.sh`
- Modify: `services/featureservice/src/main/java/com/aware/feature/service/McpBotsController.java` (new method beside `getProjectCredentials`)
- Modify: `services/feature-ingest/src/main/java/com/aware/feature/interceptors/oauth/OAuthProjectMembershipCache.java`, and the `isMember` call sites at `AuthorizationInterceptor.java` ~385 and ~405
- Test: `McpBotsControllerTest.java`; the membership cache's test beside it (create `OAuthProjectMembershipCacheTest.java` if none)

**Interfaces:**
- Produces: `POST /api/mcp/list_my_projects`, `@RequireApiKey`, OAuth callers only (`requireOAuthCaller`), returning `{"projects":[{"projectId","projectName","repoUrl"?}]}` from `AdminServiceClient.LIST_USER_PROJECTS` with the caller's `ProjectScopedUserInfo`. `repoUrl` is the project's connected-repo URL if the existing integration config exposes it cheaply; omit the field otherwise (the skill then shows the plain list).
- Produces: `OAuthProjectMembershipCache.isMember(...)` reloads the user's project list once when the project is not in the cached set, before returning false; `invalidate(String userId)`.

- [ ] **Step 1: Write failing tests:**
  - `listMyProjects_apiKeyCaller_isRejected` (same assertion as the API-key case at ~114)
  - `listMyProjects_oauthCaller_returnsTheUsersProjects` (two projects → both in JSON, `Cache-Control: no-store`)
  - `isMember_reloadsOnceWhenProjectMissingFromCache`: first lookup returns `{A}`, project `B` asked for, second lookup returns `{A,B}` → true; loader called exactly twice.
  - `isMember_doesNotReloadWhenProjectIsCached`: loader called once.
  - `isMember_returnsFalseWhenStillMissingAfterReload`: loader called exactly twice, result false.
- [ ] **Step 2: Run** `./gradlew :featureservice:test --tests com.aware.feature.service.McpBotsControllerTest` and the cache test → FAIL.
- [ ] **Step 3: Implement.** One reload per `isMember` call (never a loop). Call `invalidate(userId)` from project create / member add only where an in-process hook already exists; the reload is the guarantee, since the cache is per process.
- [ ] **Step 4: Run** the same tests → PASS.
- [ ] **Step 5: Commit** `feat(mcp): list_my_projects; membership cache reloads once on a miss`. Open a PR.

### Task 5: Web app — "Connect your agent" dropdown

**Files:**
- Create: `ui/src/common/components/ConnectAgentPanel.tsx` (shared by the three entry points), `ui/src/common/connectAgentContent.ts` (pure builders for each agent's text), logo SVGs for Cursor, Codex, Claude.ai, Claude Code, Other (reuse existing assets where present)
- Modify: `ui/src/common/mcpJsonConfig.ts` (`buildTestChimpInstallPrompt` and `TESTCHIMP_INSTALL_PROMPT`; replace `TESTCHIMP_CHECK_CONNECTIVITY_COMMAND` with `TESTCHIMP_CONNECT_PROJECT_COMMAND = "/testchimp connect-project"`), `ui/src/home/CreateProjectWizard/steps/LocalAgentStep.tsx`, `ui/src/common/components/LocalAgentSetupPopover.tsx`, `ui/src/common/components/WorkspaceSetupGuide.tsx`, `ui/src/admin/ProjectSettings/KeyManagementSettings.tsx:187`
- Test: `ui/src/common/__tests__/connectAgentContent.test.ts`, `ui/src/common/components/__tests__/ConnectAgentPanel.test.tsx`; update `LocalAgentStep.test.tsx`

**Interfaces:**
- Produces: `type AgentId = "cursor" | "codex" | "claude-ai" | "claude-code" | "other"`; `buildAgentSteps(agent: AgentId): { steps: string[]; commands: string[]; manual?: ManualInstructions }`; `buildCredsJson(project: { projectId: string; projectName?: string }, apiKey: string, userId?: string): string` (the flat `creds.json` shape, backend/ingress from the existing `resolve*ForMcp` helpers); `buildHostMcpFile(agent): { path: string; content: string }` (URL only, no key); `buildTestChimpInstallPrompt(): string`.
- `buildTestChimpInstallPrompt()` keeps its first two sentences and ends: "Ask user to run /testchimp connect-project afterwards to link this repo to their TestChimp project."

Exact content per agent (the tests assert these strings):
- **Claude Code** (primary): `/plugin install testchimp --marketplace testchimphq/testchimp-skills` → "restart the session" → sign in with `/mcp` → in the repo run `/testchimp connect-project`.
  **Install manually** (link CTA): host file `.mcp.json` = `{"mcpServers":{"testchimp":{"type":"http","url":"https://mcp.testchimp.io/mcp"}}}`; `npx skills add testchimphq/testchimp-skills -g -y`; copy-block for `.testchimp/creds.json` (ID and key prefilled for the current project).
- **Claude.ai** (primary): add a custom connector with URL `https://mcp.testchimp.io/mcp` (Settings → Connectors → Add custom connector); **Copy prompt** to have the agent install the skill; attach the repo folder; run `/testchimp connect-project`. Team/Enterprise note: an Owner adds the connector for the organisation first.
  **Install manually**: the `creds.json` copy-block only (the connector is added in settings, so there is no host file).
- **Cursor:** host file `.cursor/mcp.json` = `{"mcpServers":{"testchimp":{"url":"https://mcp.testchimp.io/mcp"}}}`; `npx skills add testchimphq/testchimp-skills -g -y`; `/testchimp connect-project`.
- **Codex:** host file `.codex/config.toml` = `[mcp_servers.testchimp]\nurl = "https://mcp.testchimp.io/mcp"`; skill command; `/testchimp connect-project`.
- **Other:** generic `mcp.json` URL snippet; skill command; `/testchimp connect-project`.
- **Every agent except Claude Code and Claude.ai's primary path** shows, under the skill command, a secondary link "npx not working? Copy this prompt instead" that copies the install prompt. Claude Code's manual section shows it too. The `creds.json` copy-block is the "skip connect-project" shortcut (collapsed for Cursor/Codex/Other).
- Every copy-block caption says to keep `.testchimp/` in `.gitignore`.

- [ ] **Step 1: Write failing tests:** `buildAgentSteps("claude-code")` contains the exact plugin command and has `manual`; `buildAgentSteps("cursor").commands` contains the skill command and the connect-project command and has no `manual`; `buildHostMcpFile("codex")` is the TOML above; `buildCredsJson` output parses to the flat shape with `schemaVersion: 1`, includes `projectId`, and omits `userId` when not given; `buildTestChimpInstallPrompt()` contains the README URL and `/testchimp connect-project` and not `check connectivity`; the panel renders five options in a dropdown, shows the "Copy prompt" control for Claude.ai as primary and as the secondary link for Cursor, clicking it copies the prompt (clipboard mock), and "Install manually" reveals the host file and copy-block; no rendered text contains `TESTCHIMP_API_KEY`.
- [ ] **Step 2: Run** `cd ui && CI=true npx react-scripts test src/common` → FAIL.
- [ ] **Step 3: Implement** the builders and the panel; replace the three call sites' own text with `<ConnectAgentPanel projectId=… apiKey=… />`. Pass the project whose key was fetched, not `LocalStorageManager.getProjectId()` (during the wizard it may still point at the previous project). Keep the old stdio `.mcp.json` snippet behind a "CI / cloud agents" disclosure, since it is still needed there.
- [ ] **Step 4: Run** the same tests → PASS; run the full UI suite for regressions.
- [ ] **Step 5: Commit** `feat(ui): per-agent connect panel; install-prompt fallback; creds.json copy-block`.

## Repo: testchimp-skills

### Task 6: Skill and CLI resolve `creds.json` (backward compatible)

The skill today finds a project MCP JSON, reads its `env`, exports the values for runners, and calls the CLI. This task makes `creds.json` the first thing it finds and leaves the legacy walk intact for everything else. The lookup is written in four places (SKILL.md prose, `references/cli.md`, `scripts/testchimp-preamble-check`, and the CLI in T3); all four must agree.

**Files:**
- Modify: `SKILL.md` — `## Preamble checks` item 4 (the "Resolve" bullet and its numbered export list, the "Remote MCP (OAuth)" bullet, the "On 401" checklist) and `### Finding project MCP config (TestChimp)` (candidate list, "Remote MCP entries", "If walk-up finds nothing")
- Modify: `references/cli.md` (the resolve/export block ~lines 69–99, including the "`.testchimp/mcp.json` fallback (CLI ≥ 0.1.90)" paragraph and "Already saved")
- Modify: `scripts/testchimp-preamble-check` (candidate lists at ~142 and ~169; the `MCP_CONFIG:` report at ~299)
- Sweep (`.testchimp/mcp.json` → `.testchimp/creds.json` where it means runner credentials; keep legacy mentions only in the two lookup lists above): `references/{TESTING,agent-quick-answers,ai-wright-usage,fix-issue,instrument-truecoverage,invite-team,local-desktop-studio,policies-and-traceability,project-init-testchimp,version-matrix,write-smarttests}.md`
- Modify: `metadata.required_cli_version` in `SKILL.md` frontmatter → `2.0.6`

**Interfaces:**
- Consumes: the mapping table and read order in Global Constraints; CLI ≥ 2.0.6 (T3).
- Produces: a resolution rule the other skill tasks cite: "repo creds = the first file found by the read order; if it is `creds.json`, use its mapped values and stop walking."

- [ ] **Step 1: Write the new resolution text** (replace, don't append; keep the legacy walk text under the heading "Legacy MCP-config walk"):
  1. Walk up from the SmartTests root (`.testchimp-tests`) to the git root checking `.testchimp/creds.json` first.
  2. **Found** → export the mapped vars into the runner/CLI shell (table above), reading the file with the file tool and never echoing the key. Do not walk host MCP files for credentials. If `cliVersion` is set, use `npx @testchimp/cli@<cliVersion>` for every CLI call this session.
  3. **Not found** → run the legacy walk unchanged (including `${TESTCHIMP_API_KEY}` placeholders and cloud/CI files). For hosted/plugin users with only a legacy file, T7 migrates it.
  4. **CLI calls:** run them from inside the repo; CLI ≥ 2.0.6 applies `creds.json` itself when `TESTCHIMP_API_KEY` is unset, so a CLI-only command needs no export. **Runner processes** (Playwright, Mobilewright, k6) always get the exports in their own shell, because the reporter reads env only.
  5. **401 checklist** now starts: "re-read `creds.json`; confirm `backendUrl`/`ingressUrl` were exported; confirm the key is from the same file"; the "refresh `.testchimp/mcp.json`" line becomes "run `/testchimp connect-project`".
- [ ] **Step 2: Update `scripts/testchimp-preamble-check`:** add `$base/.testchimp/creds.json` as the first candidate in both candidate lists with a creds-shaped validator (JSON object with a non-empty `projectId` and `projectApiKey`), and report `CREDS_FILE: <path>` and `TESTCHIMP_PROJECT_ID: <id>` plus the existing style of key-state line (never the key). When a creds file is found, skip the `MCP_JSON` walk but still run the hosted-server detection (`_is_hosted_testchimp_mcp`) so the plugin's server is still reported. Legacy output lines stay unchanged.
- [ ] **Step 3: Verify the script with fixture directories** (in a temp dir, `git init`, run `scripts/testchimp-preamble-check` from inside):
  - only `.testchimp/creds.json` (0600) → prints `CREDS_FILE:` with that path and the project ID, no `MCP_CONFIG:` credentials line, and no key text anywhere in the output.
  - only legacy `.testchimp/mcp.json` → output identical to before the change (`diff` against a saved baseline).
  - both, naming different projects → `CREDS_FILE:` wins and a one-line notice names the legacy file.
  - `creds.json` mode 0644 → reported as ignored with its path.
- [ ] **Step 4: Sweep and verify:** `grep -rn "\.testchimp/mcp\.json" SKILL.md references commands README.md llms-install.md` leaves only the legacy-fallback mentions in the two lookup lists and in `references/cli.md`'s legacy paragraph.
- [ ] **Step 5: Commit** `feat(skill): resolve .testchimp/creds.json first; legacy mcp.json fallback kept`.

### Task 7: Repo project binding on every hosted call

**Files:**
- Modify: `SKILL.md` — new subsection `### Project binding (hosted / plugin MCP)` under `## Preamble checks (run first)`, referenced from `## MCP client and CLI (agents)`
- Modify: `references/cli.md` (hosted-MCP section), `assets/sample-mcp.remote.json` (URL only)

**Interfaces:**
- Consumes: `projectId` argument (T1), the resolution rule (T6).

- [ ] **Step 1: Write the subsection.** Applies when the TestChimp server is the hosted URL:
  1. Resolve the repo creds (T6).
  2. **`projectId` present** → pass it on every TestChimp tool call this session (not on `list-projects`). Never pass `projectApiKey` once the ID is known.
  3. **Key but no ID** (legacy mcp.json or wizard files) → call `get-project-credentials` once with `projectApiKey` (read from the file, never echoed); write the returned `projectId` into `creds.json`, migrating the legacy file's values there in the same write (leave the legacy file untouched); continue as in 2. On 401/403 stop: "This repo's TestChimp key is for a project your account can't access. Run `/testchimp connect-project`." Stdio and CI users with no OAuth are not migrated.
  4. **No creds** → run `/testchimp connect-project` before any write; read-only calls may proceed only after telling the user which project they hit.
  5. **Stale ID** (403 on a call that carried `projectId`) → stop with the message from 3; never retry without `projectId`.
  6. Never send `user-id` on hosted calls. Remove every "re-authenticate via `/mcp` to switch project" instruction.
- [ ] **Step 2: Verify the text:** `grep -n "re-authenticate\|reauth\|/mcp to switch" SKILL.md references/*.md commands/*.md` → no hits except history notes.
- [ ] **Step 3: Scenario check** (plugin in Claude Code, staging hosted MCP, after T1–T4 deploy). Expected:
  - **A:** `creds.json` with P2 while the consent project is P1 → `get-project-init-status` reports P2.
  - **B:** legacy key-only `mcp.json` for P2 → one key-carrying call; `creds.json` now exists with P2; later calls carry only `projectId`.
  - **C:** key for a project the user isn't in → stops with the message; no file written.
  - **D:** claude.ai chat with no folder → the skill names the default project before acting.
  - **E:** `creds.json` + legacy mcp.json naming different projects → `creds.json` is used and the skill says so once.
- [ ] **Step 4: Commit** `feat(skill): bind hosted MCP calls to the repo's creds.json projectId`.

### Task 8: `/testchimp connect-project`; retire check-connectivity

**Files:**
- Create: `commands/connect-project.md`, `references/connect-project.md`
- Modify: `commands/check-connectivity.md` (stub: prints "`/testchimp check-connectivity` is now `/testchimp connect-project`" and follows the new reference), `references/check-connectivity.md` (shrinks to a pointer), `commands/init.md` and `references/init-testchimp.md` (replace "Remote MCP (OAuth) setup" and "Save the runner key" with a call to connect-project; keep the workstation gate and local test environment), `SKILL.md` command routing table, `references/project-init-testchimp.md`, `references/onboarding-next-step.md`, `references/invite-team.md` (rename mentions)

**Interfaces:**
- Consumes: `list-projects` (T2), `get-project-credentials` with `projectId` (T1), the resolution rule (T6), the binding rule (T7).
- Produces: a repo with a valid `<git root>/.testchimp/creds.json` and `.testchimp/` in `.gitignore`.

- [ ] **Step 1: Write `references/connect-project.md`:**
  1. **Signed in?** If no TestChimp tool is reachable, tell the user to sign in (`/mcp` in Claude Code; the connector's Connect button in Claude.ai) and stop.
  2. **Existing creds** (any file in the read order) → call `get-project-credentials` with its `projectId` (or key). Report "This repo is linked to <projectName>" and stop, unless the key's project ≠ the file's `projectId`, in which case say so and rewrite the ID from the key.
  3. **No creds** → call `list-projects`. If exactly one project's `repoUrl` matches `git remote get-url origin` (normalised: scheme, `.git`, case), ask "Link this repo to <name>?"; otherwise show the full list and ask which project this repo is for (AskUserQuestion when available). Zero projects → point to the app's create-project page and offer to re-check.
  4. **Write** `<git root>/.testchimp/creds.json` (flat shape, 0600, dir 0700) from `get-project-credentials(projectId)`; keep a pre-existing `cliVersion`, `backendUrl`, `ingressUrl`; add `.testchimp/` to `.gitignore`; if an existing creds file is group-readable, `chmod 600` it.
  5. Never print the key. Finish with the project name and one next step (`/testchimp project-init` for a first-time project, else `/testchimp run QA`).
- [ ] **Step 2: Add the stub and rename mentions;** `grep -rn "check connectivity\|check-connectivity" . --include=*.md` leaves only the stub, the pointer reference, and history notes.
- [ ] **Step 3: Scenario check.** Expected:
  - **F:** fresh repo, user in 3 projects → the picker shows 3; after picking P3 `creds.json` has P3 and `get-project-init-status` reports P3; no OAuth window opens.
  - **G:** repo whose `origin` matches P2's `repoUrl` → "Link this repo to P2?" is the only question.
  - **H:** remote matches two projects, or none → full list, no auto-pick.
  - **I:** two repos (P1, P2) in two parallel Claude Code sessions → each session's calls land in its own project (verify in the TestChimp UI).
  - **J:** same as I with the claude.ai connector and each folder attached in Claude Desktop.
  - **K:** `/testchimp check-connectivity` prints the rename note and links the repo.
  - **L:** after linking, run one Playwright test through the skill → the reporter's results appear in project P (proves the env export from `creds.json`, since the reporter never reads files).
- [ ] **Step 4: Commit** `feat(skill): /testchimp connect-project; retire check-connectivity`.

### Task 9: Install docs, manifests, release

**Files:**
- Modify: `README.md` (install matrix and the Claude Code line, replacing the two-command form with the one-command form; the prompt in T5 points agents here, so the matrix must be followable by an agent), `llms-install.md`, version in every manifest that carries it (`plugin.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.cursor-plugin/*`, `.codex-plugin/plugin.json`, `gemini-extension.json`, and SKILL.md frontmatter if versioned) bumped together

- [ ] **Step 1: Rewrite the install matrix** to mirror the wizard exactly (same five agents, same strings as T5), with `npx skills add testchimphq/testchimp-skills -g -y` as the skill row. Add an "If you are an AI agent asked to install this skill" paragraph at the top: use the matrix row for your host, then tell the user to run `/testchimp connect-project`. Add: "Sign in once; each repo remembers its own project (`.testchimp/creds.json`)." Add the rc-testing note: "set `cliVersion` in `creds.json` to try a release candidate; set `backendUrl`/`ingressUrl` for staging."
- [ ] **Step 2: Fix the version drift:** plugin and marketplace manifests say 2.0.2 while the last release commit says 2.0.7. Decide the single source of truth, bump all manifests to the next patch together, and add a one-line release checklist to the README so they cannot drift again. `/plugin update` depends on this number.
- [ ] **Step 3: Verify** `grep -rn "\.testchimp/mcp\.json" README.md llms-install.md SKILL.md references commands` → only legacy-fallback notes remain.
- [ ] **Step 4: Run scenarios F–L once more** against the released hosted MCP 2.0.6, CLI 2.0.6 and the released skill, on a clean machine (no prior skill install), using the copy-prompt route once and the npx route once.
- [ ] **Step 5: Commit** `docs(skill): seamless agent connection; release`. Open a PR after T1–T4 are live.

## Open items (not tasks yet)

- **Claude.ai web chat has no shell,** so the copy-prompt route can only install the skill where the agent can write files (Claude Desktop with a folder attached, Cowork). Decide whether the plain web chat also needs a skill-upload path.
- **Studio (`AwareRepo/desktop`):** not read yet. It writes `.testchimp/mcp.json` today; it must read `creds.json` first and keep the legacy fallback. Find where, and add a task.
- **Directory submissions:** submit the plugin and the connector to Anthropic's directory so the wizard can later switch to one-click install. No code change needed.

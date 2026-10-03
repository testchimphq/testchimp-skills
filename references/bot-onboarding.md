# QA bot onboarding (US-243)

Run on the bot's **first conversation** (profile has no role / capabilities yet) and again whenever the user wants to **change focus** ("stop watching my pushes", "I'm a QA lead now", "also help with issue fixes"), or when a flow reports the local folder is not mapped (`project_not_mapped` → [step 6](#6-per-user-init-local-repo-folder) only).

Event handling after onboarding → [`bot-playbook.md`](./bot-playbook.md). Version checks → [`bot-self-update.md`](./bot-self-update.md). CLI shapes → [`cli.md`](./cli.md) § QA bots.

Steps 6 and 6b run on the **user's own computer** through the bot host's access to it, never on the bot's cloud computer ([`bot-playbook.md` § Where commands run](./bot-playbook.md#where-commands-run)).

**Connector first.** If the TestChimp MCP tools are missing, add the custom MCP server yourself: name `testchimp`, URL `https://mcp.testchimp.io/mcp` (staging: `https://mcp-staging.testchimp.io/mcp`). Don't ask the user for the URL. They only click **Add**, then **Authorize**, sign in, pick the project and click **Allow** on the TestChimp consent page.

Before step 1: `get-bot-profile` (CLI: `testchimp bot get-profile`). Tell the user which TestChimp project and team member this bot represents (`projectId`, `userId`). Wrong project or user → stop and ask them to reconnect the bot (OAuth consent) for the right project. Run the compat check once ([`bot-self-update.md`](./bot-self-update.md)).

## Steps

### 1. Project init status

`get-project-init-status` (CLI: `testchimp get-project-init-status`). One project-wide setup (`/testchimp project init`, [`project-init-testchimp.md`](./project-init-testchimp.md)) defines the plans/tests folders, test environment and CI for everyone.

Response: `{status: {platformComms, folderMapping, connectToTestEnv, ciWiring, importPlans, importTests, smokeValidation, overallComplete}}`, each `PROJECT_INIT_ITEM_STATUS_{INCOMPLETE|DONE|SKIPPED|NOT_APPLICABLE}`.

- `overallComplete` is `…_DONE` → say so in one line and continue.
- Otherwise → list the items still `…_INCOMPLETE` (or missing), one line each. Say who usually finishes them (a QA lead or the project owner, via `/testchimp project init`) and that the bot still works for events in the meantime. Do **not** start project init from onboarding unless the user asks.

### 2. Role and responsibilities

- **Role:** `QA_LEAD`, `PM`, `QA_ENGINEER`, or `DEVELOPER`. Offer plain labels: QA lead, product manager, QA engineer, developer.
- **Responsibilities** in their own words (free text, e.g. "checkout + payments; API coverage for billing service"). Keep it verbatim. It personalises digests and triage.

### 3. Capabilities (pre-selected for the role)

Show all six with the role's defaults ticked. The user confirms, adds, or removes:

| Role | Pre-selected capabilities |
|---|---|
| QA_LEAD | QA_POSTURE, TEST_BATCH_FIX, MANUAL_TEST_COORDINATION |
| PM | QA_POSTURE, REQUIREMENTS_UPDATE |
| QA_ENGINEER | E2E_AUTHORING, TEST_BATCH_FIX, MANUAL_TEST_COORDINATION |
| DEVELOPER | E2E_AUTHORING, ISSUE_FIX, REQUIREMENTS_UPDATE |

| Capability | What the bot does | Subscriptions it needs |
|---|---|---|
| REQUIREMENTS_UPDATE | Keeps stories / scenarios in sync with pushed code (AgentWatch) and meeting decisions | `git-push` (`author eq me`), `meeting-ended` (`adder eq me`) |
| E2E_AUTHORING | Proposes E2E tests for your pushed changes | `git-push` (`author eq me`) |
| ISSUE_FIX | Proposes fixes for issues assigned to you | `issue-assigned` (`assignee eq me`) |
| MANUAL_TEST_COORDINATION | Tracks manual scenarios assigned to you | `scenario-assigned` (`assignee eq me`) |
| TEST_BATCH_FIX | Triages failed E2E and k6 batches on your branches | `e2e-batch-completed`, `k6-batch-completed` |
| QA_POSTURE | Release heads-ups and a weekly posture digest | `release-created`, `release-status-updated` |

Subscriptions = union of the selected rows, deduplicated by `eventType` + filters. `meeting-started` (`adder eq me`) is optional context; add it only if the user wants a heads-up when the meeting bot joins. `test-event` (Check Connection) is always delivered, so never subscribe to it.

Also ask for routine preferences (stored in bot memory, not in the profile):

- Weekday reminder time + timezone (default 9:00 local, Mon–Fri).
- Weekly digest day/time (QA_POSTURE only; default Monday after the reminder).
- Green batches (TEST_BATCH_FIX): one-line "all passed" note, or silent (default silent).

### 4. Register the profile

Confirm the summary (role, responsibilities, capabilities, subscriptions, routine times) and get approval. Registration is a mutating action and **replaces** the previous profile and subscriptions atomically.

MCP `register-bot-profile`:

```json
{
  "role": "QA_ENGINEER",
  "responsibilities": "Checkout + payments; API coverage for billing",
  "capabilities": ["E2E_AUTHORING", "TEST_BATCH_FIX"],
  "subscriptions": [
    { "eventType": "git-push", "filters": [{ "field": "author", "op": "eq", "value": "me" }] },
    { "eventType": "e2e-batch-completed" },
    { "eventType": "k6-batch-completed" }
  ]
}
```

CLI:

```bash
testchimp bot register-profile --role QA_ENGINEER \
  --responsibilities "Checkout + payments; API coverage for billing" \
  --capability E2E_AUTHORING --capability TEST_BATCH_FIX \
  --subscriptions-json '[{"eventType":"git-push","filters":[{"field":"author","op":"eq","value":"me"}]},{"eventType":"e2e-batch-completed"},{"eventType":"k6-batch-completed"}]'
```

`botId` defaults to the `bot-id` header (`TESTCHIMP_BOT_ID`) or the OAuth token's bot, so omit it.

### 5. Webhook

Events only reach the bot once TestChimp knows where to deliver them. From the profile (`webhookHost`, `webhookKeySet`, `lastCheckSuccess`):

- **Already verified** (`lastCheckSuccess` true) → one line: "Webhook verified for `<webhookHost>`."
- **Otherwise** → guide the user:
  1. In the bot host (e.g. Grok), copy the bot's webhook URL and key.
  2. Open **Project Settings → My QA Bot**: `<appUrl>/project-config?tab=user-bots` (cloud: `https://prod.testchimp.io/project-config?tab=user-bots`). Make sure the right project is selected in the app header.
  3. Paste the **Webhook URL** and **Webhook key**, click **Save webhook**, then **Check Connection**.
  4. A `test-event` delivery arrives here. Ack it (see [`bot-playbook.md`](./bot-playbook.md#test-event)). Re-run `get-bot-profile` to confirm `lastCheckSuccess`.

The same tab shows the subscriptions you registered, recent deliveries, and the **Pause all** switch.

### 6. Per-user init (local repo folder)

**Runs on the user's computer.** If you don't have access to it yet, ask the user to grant it, explaining that folder mapping and AgentWatch need their local repo and coding-agent chats. If they decline, skip steps 6 and 6b and say requirement updates from pushes and local test runs won't work until then. Check Node.js 20+ and the CLI there first (`node --version`, `testchimp --version`; install with approval).

Flows that read the user's machine (AgentWatch on `git-push`, local test runs) need to know which local folder holds this project's repo. The mapping is per user and lives in `~/.testchimp/projects.json`, shared with TestChimp Studio.

1. `testchimp workspace get --project-id <projectId>`. Exit 0 → show the mapped folder and ask whether it is still right. If it is, skip to step 6.4.
2. Ask for the absolute path of their local clone of the project's repo.
3. With approval (it writes a local file): `testchimp workspace map --project-id <projectId> --folder <path> --project-name "<projectName>"`.
   - `NOT_A_GIT_REPO` / `NOT_REPO_ROOT` / `REPO_MISMATCH` → show the message (it names the expected repo or root) and ask for the right folder.
   - `folder already mapped to project <id>` → ask whether to move it to this project. If they say yes, rerun with `--reassign`.
4. Validate: `testchimp workspace get --project-id <projectId>` prints the folder.

The local test environment is **not** configured here. It stays as project init defines it (env policy / `connect-to-test-env`, [`connect-to-test-env.md`](./connect-to-test-env.md)). If the user wants local runs and their workstation is not set up, offer `/testchimp init` ([`init-testchimp.md`](./init-testchimp.md)) later.

### 6b. AgentWatch credentials (REQUIREMENTS_UPDATE only)

**Runs on the user's computer**, the same one as step 6. Requirement updates from pushes run headless AgentWatch there, because it reads the coding-agent chats stored on that machine. TestChimp Studio is **not** needed. AgentWatch acts as the user, so it needs their user id, their personal access key (PAT) and the project API key. The user grants these once through OAuth:

1. Explain what it does: a browser approval that stores the user's TestChimp keys in `~/.testchimp/agentwatch/credentials.json` (readable only by them) and opts this project in to AgentWatch. Get approval; it writes a local file.
2. Run `testchimp bot connect --project-id <projectId>`. It prints an approval URL and opens the browser. The user signs in, keeps the project selected, leaves **Use this connection as my QA bot** ticked, and clicks **Allow** (the page warns that keys will be stored locally).
3. Exit 0 prints `{projectId, userId, email, botId, credentialsPath}` (never the keys). If `botId` differs from this bot's `TESTCHIMP_BOT_ID`, mention it.
   - `does not match --project-id` → they picked another project; run it again.
   - `The user denied access` / timeout → ask whether to retry.
   - `did not grant the agentwatch scope` / `OAuth is not enabled` → the deployment is too old; Studio sign-in still works (`npx @testchimp/studio`, sign in, enable AgentWatch).
4. Validate: `npx -y @testchimp/agentwatch status` (exit 1 `not_running` is fine; `query` starts the daemon).

To revoke later: `testchimp bot disconnect --project-id <projectId>`.

### 7. Summary

Confirm back in a few lines:

- Project, role, responsibilities, capabilities.
- What you will watch for and what you will propose for each (from the capability table).
- Webhook status, mapped folder, routine times.
- Nothing mutating happens without their approval. They can pause from **My QA Bot** (`?tab=user-bots`) or say "change my focus" anytime.

## Changing focus later

Re-run steps 2–4 with the current profile pre-filled. Ask only about what changed. Always send the **full** desired capability and subscription set, because registration replaces rather than merges. Re-run step 5 only if the webhook check fails, and step 6 only if the folder moved.

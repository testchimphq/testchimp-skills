# TestChimp QA bot template changelog

Versions of the Grok Bot template manifest (`grok-template.json` → `templateVersion`). Existing bots pick up skill and CLI releases automatically through the daily self-update routine (instructions and routines live in the bot host, so the bot asks the user to apply those); bump `templateVersion` when the manifest itself changes (connector, routines, minimum versions, instructions variables).

## 1.0.4 — skill 1.0.61, CLI ≥ 0.1.88

- Project init now ends by offering to invite teammates. The bot asks for emails, confirms them, and calls the new `invite-team-members` MCP tool through the connector (it acts as the signed-in user, who must be an org admin; the CLI's `--bot` key can't invite). Instructions list it next to `get-bot-credentials` and `approve-agentwatch-pairing` as a connector-only call.
- New default event `workflow-execution-assigned` (`recipient eq me`): the bot tells its user when a workflow execution is assigned to them or they're CC'd, suggests the next step for its status (review the plan, approve the run, investigate a failure) and can reassign or CC with `update-workflow-execution-assignees` after approval. New bots get it at creation; onboarding adds it to every role's subscriptions. The weekday reminder lists assigned executions waiting for approval.
- After (re)authorizing, the bot takes its project only from `get-bot-credentials` and asks the user to confirm it, so a second bot doesn't pick up the first bot's project.
- Existing bots need no action: the skill update carries the new steps. Replacing the instructions with the 1.0.4 text is optional.

## 1.0.3 — skill 1.0.57, CLI ≥ 0.1.88

- One bot per project, one connector per user. The host shares the TestChimp connector across a user's bots, so it now carries only the user. Each bot keeps its own **project binding** (`projectId`, `projectName`, `botId`, `projectApiKey`) as a bot-scoped env var or secret, else in bot memory. It gets the binding with `get-bot-credentials` right after the user authorizes the connector for that bot's project (onboarding step 0).
- The CLI is now the bot's preferred path: `testchimp bot save-binding` once per computer, then `testchimp --bot <botId> …` (`bot exec` for runners). It talks to TestChimp directly. MCP tools are for binding (`get-bot-credentials`), AgentWatch pairing approval and as a fallback; every tool takes `projectApiKey` and `botId` arguments, and bots pass them on every call.
- A second bot no longer moves the first bot to its project: the backend takes the project from the key and the user from the connector.
- **Existing bots must re-bind.** QA bot calls without a project key now get 403 "no project binding". Replace the instructions with the 1.0.3 text (or reinstall from the template). The bot then runs step 0: the user clicks Authorize on the existing connector, picks the bot's project, and ticks **Use this connection as my QA bot**.

## 1.0.2 — skill 1.0.56, CLI ≥ 0.1.87

- Daily self-update is automatic: the routine looks up the latest skill (`SKILL.md` on `main`) and CLI (npm) versions at run time and updates anything older on the bot's cloud computer without asking; updating the CLI on the user's computer still asks first. It tells the user only what was updated or failed. Instructions pre-approve the cloud-computer updates (hard rule 1) and install the latest CLI instead of a pinned minimum.
- Bots created from 1.0.1 or earlier: replace the instructions and the **Daily self-update** routine prompt with the 1.0.2 text (or reinstall from the template). Until then they keep asking before updating.

## 1.0.1

- Before connecting, the bot tells the user it will use TestChimp cloud and lets them enter a different MCP URL (enterprise or self-hosted). Backend URL comes from `/.well-known/oauth-protected-resource`; ingress is derived by replacing `featureservice` with `ingress` in the hostname.
- Onboarding uses structured cards: no name question; role picked from four options (QA lead, Product manager, QA engineer, Developer); then the role's pre-selected activities with a choice to change them (multi-select of all six). No responsibilities question.
- If project init is incomplete, the bot guides the user through `/testchimp project init` after the webhook is set up, whatever their role.
- The bot installs `@testchimp/cli` on both its cloud computer and the user's computer, and uses the CLI as the fallback when the MCP is flaky.
- AgentWatch setup needs no second browser consent: `testchimp bot connect --pair` on the user's computer, the bot approves the pairing code (`approve-agentwatch-pairing`), then `--finish-pair` stores the keys there. The connector's one consent page covers it (every QA bot connection can approve pairings); there is no browser fallback. CLI ≥ 0.1.86.
- Webhook setup moved to **User Settings → My Bots**. The bot sends the user `settingsUrl` from `get-bot-profile`, a direct link to its own settings page, instead of describing where to click. The old Project Settings tab redirects there.

## 1.0.0 — skill 1.0.53, CLI ≥ 0.1.85

- Remote MCP connector `https://mcp.testchimp.io/mcp` with OAuth consent (bot-scoped token per project).
- Bot instructions: `assets/bot/instructions.md` (generic, no variables; the bot learns its user and project during onboarding). First run self-installs the skill and the TestChimp connector if missing.
- Built in Grok from `assets/bot/GROK-BUILD.md` and shared with **Share as Template**.
- Onboarding: project init status, role and responsibilities, role-preselected capabilities, profile registration, webhook setup in **Project Settings → My QA Bot**, local repo folder mapping (`testchimp workspace map`), AgentWatch credentials (`testchimp bot connect`, no Studio), summary.
- AgentWatch runs headless via `npx -y @testchimp/agentwatch` (optional tool `agentwatch`).
- Local work (folder mapping, `bot connect`, AgentWatch, git reads, local test runs) runs on the user's own computer through access they grant in the bot host, never on the bot's cloud computer (`localMachine` in the manifest).
- Event handling for event schema `1`: `git-push` (AgentWatch requirement updates, E2E authoring), `meeting-ended`, `meeting-started`, `issue-assigned`, `scenario-assigned`, `e2e-batch-completed`, `k6-batch-completed`, `release-created`, `release-status-updated`, `test-event`.
- Routines: daily self-update (08:00), weekday reminder (09:00), weekly QA posture digest (Monday 09:30, QA_POSTURE only). Times are defaults in the user's timezone; onboarding can change them.

# TestChimp QA bot template changelog

Versions of the Grok Bot template manifest (`grok-template.json` → `templateVersion`). Existing bots pick up skill and instruction changes through the daily self-update routine; bump `templateVersion` when the manifest itself changes (connector, routines, minimum versions, instructions variables).

## 1.0.1

- Before connecting, the bot tells the user it will use TestChimp cloud and lets them enter a different MCP URL (enterprise or self-hosted). Backend URL comes from `/.well-known/oauth-protected-resource`; ingress is derived by replacing `featureservice` with `ingress` in the hostname.
- Onboarding uses structured cards: no name question; role picked from four options (QA lead, Product manager, QA engineer, Developer); then the role's pre-selected activities with a choice to change them (multi-select of all six).
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

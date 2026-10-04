# TestChimp QA bot template changelog

Versions of the Grok Bot template manifest (`grok-template.json` → `templateVersion`). Existing bots pick up skill and CLI releases automatically through the daily self-update routine (instructions and routines live in the bot host, so the bot asks the user to apply those); bump `templateVersion` when the manifest itself changes (connector, routines, minimum versions, instructions variables).

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

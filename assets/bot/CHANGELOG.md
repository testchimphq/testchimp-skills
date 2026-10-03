# TestChimp QA bot template changelog

Versions of the Grok Bot template manifest (`grok-template.json` → `templateVersion`). Existing bots pick up skill and instruction changes through the daily self-update routine; bump `templateVersion` when the manifest itself changes (connector, routines, minimum versions, instructions variables).

## 1.0.0 — skill 1.0.53, CLI ≥ 0.1.85

- Remote MCP connector `https://mcp.testchimp.io/mcp` with OAuth consent (bot-scoped token per project).
- Bot instructions: `assets/bot/instructions.md` (generic, no variables; the bot learns its user and project during onboarding). First run self-installs the skill and the TestChimp connector if missing.
- Built in Grok from `assets/bot/GROK-BUILD.md` and shared with **Share as Template**.
- Onboarding: project init status, role and responsibilities, role-preselected capabilities, profile registration, webhook setup in **Project Settings → My QA Bot**, local repo folder mapping (`testchimp workspace map`), AgentWatch credentials (`testchimp bot connect`, no Studio), summary.
- AgentWatch runs headless via `npx -y @testchimp/agentwatch` (optional tool `agentwatch`).
- Local work (folder mapping, `bot connect`, AgentWatch, git reads, local test runs) runs on the user's own computer through access they grant in the bot host, never on the bot's cloud computer (`localMachine` in the manifest).
- Event handling for event schema `1`: `git-push` (AgentWatch requirement updates, E2E authoring), `meeting-ended`, `meeting-started`, `issue-assigned`, `scenario-assigned`, `e2e-batch-completed`, `k6-batch-completed`, `release-created`, `release-status-updated`, `test-event`.
- Routines: daily self-update (08:00), weekday reminder (09:00), weekly QA posture digest (Monday 09:30, QA_POSTURE only). Times are defaults in the user's timezone; onboarding can change them.

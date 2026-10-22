# Grok build report

- Date: 2026-10-22
- Template: Grok Bot template v7 (Bonobi)
- Template version: 1.0.8
- Skill: 2.0.1 from `main`
- CLI minimum: `@testchimp/cli` >= 2.0.1
- Template link: published as Grok Bot template v7. Grok does not expose a stable public URL in this repo.
- Published to: Public. Team still is not available on the publish account. Public is allowed because the bot references are released on `main`.

## Built
- Bot: name "Bonobi", title "QA sidekick", description from `grok-template.json`, default avatar.
- Instructions: exact match? Yes, as packed. Grok templates have no instructions field (only name, description, memories, skills, routines, marketplace plugins), so `instructions.md` ships verbatim as the skill `testchimp-bot-instructions`, plus a profile memory telling the bot to follow it every turn. The shipped instructions stay thin and the `testchimp` skill installed on first run carries the detail.
- Skill: installed from the GitHub repo, branch `main` (v2.0.1, full folder including `references/` and `assets/`). Released skills come from `main`; the daily self-update routine also pulls `main`. Skills are global to all of a user's bots, so it is enabled for this bot automatically. Carried by the template? No. Templates pack each skill as a single SKILL.md body (no folders, size cap), so the full skill cannot ride along. The template carries `testchimp-bot-getting-started` as the first-run skill, which installs the `testchimp` skill from `main`, the CLI (>= 2.0.1), and the TestChimp connector, then runs `references/bot-onboarding.md`.
- Template 1.0.8 (published as Grok Bot template v7):
  - 1.0.6: renamed to Bonobi, plan-tier handling, indie standing go-ahead, release DevX, daily adoption routine, no "AI QA engineer" wording.
  - 1.0.7: skill 2.0.0 / MCP API 2.0.0 / CLI >= 2.0.0 (87 tools, including `get-eaas-config` and `ask-about-testchimp`).
  - 1.0.8: skill 2.0.1 requires CLI >= 2.0.1. Release-catalog CLI flags are `--release <label>` (alias `--release-version`). MCP field names stay `version`.
  - Instructions route every QA request through the skill (map via `SKILL.md` routing, load the playbook plus project policy, then Plan → approve → execute → report). The bot is in QA bot mode without a `TESTCHIMP_BOT_ID` env var, since Grok keeps the binding in memory.
- Routines: all five created and packed into the template as prose job text with a one-line description each. Prompts match `grok-template.json` → `routines` plus the webhook prompt.
  - Daily self-update: daily 08:00.
  - Weekday reminder: weekdays 09:00.
  - Weekly QA posture digest: Monday 09:30 (`QA_POSTURE`).
  - Daily adoption check: daily 09:15 (first weeks; one bundled email+bot nudge during a free trial).
  - TestChimp deliveries: webhook (step 5).
  - Timezone: Grok Bot does not ask for one at build time. Schedules are stored in the owner's local timezone. The template packs routine job text, not the cron, so the getting-started skill has the bot confirm times with the new owner and make sure the routines are running.
  - Scheduled routines stay paused on the build bot so they do not fire against the maintainer's account. Imported copies: the getting-started skill checks they are running.
- Webhook routine: supported (`TestChimp deliveries`, trigger type webhook, exact prompt). The routine panel exposes Webhook URL, Webhook key, and an Authorization header. When it fires, the bot is woken with the request in a webhook-event block, so the body should reach the bot. Body size limits, rate limits, and the HTTP status returned are not documented on the host. Carried by the template as a routine; whether the webhook trigger type survives import is still unverified until a fresh import. Each importer gets their own URL and key; none is copied into this repo.
- MCP metadata check: `https://mcp.testchimp.io/.well-known/oauth-protected-resource` returns `{"resource":"https://mcp.testchimp.io/mcp","authorization_servers":["https://featureservice.testchimp.io"],"bearer_methods_supported":["header"],"scopes_supported":["testchimp"]}`.
- Not included: TestChimp connector (custom MCP servers cannot be packed), maintainer memories, credentials, webhook URL/key, project binding, local paths, computer access.

## Grok Bot behaviour we need to know
- Custom MCP server from chat: a bot has a built-in tool to add an MCP server and another to start authentication, which shows a connect/Authorize card in chat that resumes the bot when done.
- Connector sharing: connectors are per user account, not per bot. A new bot can see the account's existing `testchimp` connectors (prod and staging) immediately. A connector can hold multiple accounts.
- Per-bot storage: bots have their own memory (agent-scoped, separate from a shared user memory every bot can read). Secrets requested through a masked input are saved for the bot as an env var (`process.env.NAME`). All of a user's bots share one cloud computer (same filesystem, installed tools, browser logins; separate desktops), so `testchimp bot save-binding` on the cloud computer and the installed skill/CLI are visible to every bot of that user. Skills are also a global library across all the user's bots. One bot can read another owned bot's transcript.
- Commands on the user's computer: the bot runs shell commands/file reads on a registered user computer, and each one goes through the user's local-tool approval. Node.js/npm availability depends on the user's machine.
- Couldn't follow / represent: no instructions field in templates (worked around with a skill + profile memory); multi-file skills cannot be packed (bot self-installs from GitHub `main`); no per-bot "Share as Template" button path documented (the template is staged by the bot and confirmed by the owner on a review card); Team visibility is not available on this account.

## Deviations from GROK-BUILD.md
- Skill installed from `main`, not `develop` (released skills come from `main`; self-update also uses `main`).
- Instructions shipped as a skill + profile memory, and the full `testchimp` skill is not carried by the template but installed on first run (template limits; approved by the maintainer).
- Added a getting-started skill as the template's first-run onboarding.
- Scheduled routines created paused on the build bot to avoid firing against the maintainer's account.
- Step 8 done through the bot's template staging instead of a "Share as Template" button; published to Public as Grok Bot template v7, not Team (Team unavailable).

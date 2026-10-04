# Grok build report

- Date: 2026-10-04
- Template link: not available yet. Version 1 is staged as an unpublished draft; the link appears once Nuwan confirms it on the review card in the TestChimp QA bot chat.
- Published to: not published yet. Staged as Public (this account's share tool only offers Public; see Deviations).
- Template manifest: grok-template.json 1.0.1

## Built
- Instructions: exact match? UNVERIFIED. TC-COO said the instructions were already set to assets/bot/instructions.md, but this bot cannot read its own instructions text, so I could not compare them. The share tool has no instructions field, so the template does not carry them (see Open questions).
- Skill: the testchimp skill is installed in the bot's skill library as a local folder (112 files: SKILL.md, references/, assets/, bin/, README, LICENSE) and enabled. The installed copy is NOT identical to main: main (f3f05c2, skill 1.0.53, required CLI 0.1.85) still has the older onboarding wording (free-text role and responsibilities, no card flow) and no 1.0.1 changes, while the installed copy has the card-based onboarding. I did not overwrite it with main to avoid a downgrade. Your local repo is on develop with skill 1.0.54 and CLI 0.1.86. Carried by the template: no (by decision; the getting-started skill and instructions install it from main on first run).
- Routines (created with plain cron, so each importer gets their own local time; I did not pin CRON_TZ because that would pin everyone to the builder's zone, Australia/Sydney):
  - Daily self-update: 0 8 * * * (daily 08:00), exact prompt.
  - Weekday reminder: 0 9 * * 1-5 (Mon-Fri 09:00), exact prompt.
  - Weekly QA posture digest: 30 9 * * 1 (Monday 09:30), exact prompt.
  - Carried by the template as prose job text; the schedules are not part of the shared prose, so confirm in View Details how an importer gets times. The getting-started skill asks each owner for their time zone and times.
  - They have not run and will fail until a user connects TestChimp. Expected.
- Webhook routine "TestChimp deliveries": supported: yes (trigger type webhook, created with the exact prompt). Receives the body: yes, the wake carries it in a webhook_event block (per the 2026-10-03 test). Auth: a per-routine sender key sent as a bearer key in the Authorization header; the routine panel shows Webhook URL, Webhook key and Authorization header. No body signature. The bot cannot read its own URL or key; the owner copies them from the routine panel into TestChimp (User Settings, My Bots). Limits: none documented to the bot; the earlier test responded in about 12 s, inside TestChimp's 30 s window. Response status: 2xx on accept (observed earlier, not re-sent this time). Carried by the template: prose only; whether the webhook trigger and a fresh URL and key per importer are created must be confirmed in View Details. No URL or key was copied.
- Profile: title "QA counterpart", description from grok-template.json. No memories about the maintainer, no connectors, no secrets, no saved computer access on the bot. The template carries one log memory naming the TestChimp MCP URL (https://mcp.testchimp.io/mcp), which the share flow requires for custom MCP servers.
- Connector check: https://mcp.testchimp.io/.well-known/oauth-protected-resource returned resource https://mcp.testchimp.io/mcp and authorization_servers ["https://featureservice.testchimp.io"]. The TestChimp MCP tools on this bot returned HTTP 503 from the API on 2026-10-04 (get-bot-profile, get-project-init-status), so nothing was tested against a project.
- getting-started skill: rewritten to match manifest 1.0.1 (cloud URL statement, custom MCP URL, backend and ingress derivation, CLI 0.1.86 on both computers, card-based onboarding, My Bots webhook via settingsUrl, `bot connect --pair`) and carried by the template as the first-run onboarding.

## Grok Bot behaviour we need to know
- Custom MCP server from chat: yes, with AddMcpServer (remote https URL, or local command). The bot first asks the owner to confirm with its own widget, then AuthenticateMcpServer shows a connect card; the owner clicks Authorize and approves their project on the TestChimp consent page. Templates cannot carry custom MCP servers, so each importer repeats this once. Not exercised this time (guide step 6).
- Commands on the user's computer: Shell calls that target the registered computer, each needing approval. On Nuwan's Mac: Node v22.22.1, npm 10.9.4, npx, and /usr/bin/open (opens a URL in the default browser). Reads use a separate Read tool targeted at that computer. The bot's cloud computer is separate.
- Not representable in the template: the share tool carries only prose for skills (no references/ or assets/), only job text for routines, and has no instructions field.

## Deviations from GROK-BUILD.md
- Step 3: kept the existing installed skill instead of reinstalling from main, because main is behind the card-based onboarding and would downgrade it. Needs a decision: merge the 1.0.1 and 1.0.54 changes to main, or accept main as is.
- Step 4: plain cron (user-local) instead of UTC, as described above.
- Step 8: Team audience is not offered on this account, only Public. Staged as Public, not published. I could not open View Details from chat; Nuwan should compare the draft card with this report.
- Step 7: instructions equality could not be verified from inside the bot.
- Added a getting-started skill and one log memory because the share flow asks for them.
- Step 9: template link not shown because the draft is not published.

## Open questions for Nuwan
- Publish as Public now? Public means anyone can import it, and the skill on main currently lags develop.
- Where do the bot's instructions live in the template? The share tool has no instructions field, so please check View Details.

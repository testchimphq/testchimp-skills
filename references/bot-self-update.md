# QA bot self-update (compatibility)

Run on **bot startup** (first delivery / first conversation of the day) and **at most once per day** after that.

## Check

MCP `get-bot-compat` → `{ minSkillVersion, minCliVersion, eventSchemaVersion }`.

CLI (also compares the CLI's own version):

```bash
testchimp bot compat --skill-version <SKILL.md frontmatter version>
# stdout: {..., "cliVersion": "0.1.85", "cliUpgradeRequired": false, "skillVersion": "1.0.53", "skillUpgradeRequired": false}
```

Compare (semver, numeric `x.y.z`):

| Check | Local value | Action when older |
|---|---|---|
| Skill | `version` in this skill's `SKILL.md` frontmatter | Ask to update the skill |
| CLI | `testchimp --version` (or `cliVersion` above) | Ask to update the CLI |
| Event schema | Playbook supports **`1`** ([`bot-playbook.md`](./bot-playbook.md)) | Conservative handling (below) |

If `get-bot-compat` is unavailable (404 / unknown tool) the deployment predates QA-bot compat checks — skip silently and retry tomorrow.

## Updating (requires approval)

Tell the user what is outdated and the exact command, then wait for approval — installs are local commands:

- **CLI:** `npm i -g @testchimp/cli@latest`, on the user's computer (folder mapping, AgentWatch) and wherever else you run the CLI (or bump the pinned version in the bot host's MCP / package config; `npx -y @testchimp/cli@latest` picks it up on next start). Remote MCP deployments: redeploy the MCP server image.
- **Skill:** `git -C "$SKILL_DIR" pull origin main` when git-installed, otherwise reinstall per the skill README ([Updating this skill from Git](../SKILL.md#updating-this-skill-from-git)). Grok-style hosted bots: re-upload / re-sync the skill files.
- **Bot template (Grok):** after a skill update, compare `templateVersion` in [`assets/bot/grok-template.json`](../assets/bot/grok-template.json) with the version the bot was created from. If it changed, summarise the [`CHANGELOG`](../assets/bot/CHANGELOG.md) entries (new routines, connector or instruction changes) and ask the user to apply them in the bot host.

After updating, re-run the check. Until updated, keep handling events (ack everything) but avoid workflows the user is warned may misbehave.

## Event schema mismatch

`eventSchemaVersion` ≠ `1`:

- Keep acking every event (never leave them unacked).
- Do not act on payload fields you don't recognise; for known event types, use only the documented required fields.
- Tell the user once: the platform sends a newer event schema; update the skill to handle it fully.

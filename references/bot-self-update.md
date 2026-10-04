# QA bot self-update

Run by the **daily self-update routine** and on **bot startup** (first delivery / first conversation of the day). Updates on **your cloud computer** (the skill and the CLI installed there) are **automatic**: the user approved them by installing the bot, so don't ask. Updates on **your user's computer** still need their approval. Never downgrade.

## 1. Latest published versions (at run time)

Look them up fresh on every run; never reuse a value from memory.

| What | Latest | Installed |
|---|---|---|
| Skill | `version` in the frontmatter of `https://raw.githubusercontent.com/testchimphq/testchimp-skills/main/SKILL.md` | `version` in the installed skill's `SKILL.md` frontmatter |
| CLI | `npm view @testchimp/cli version` (or `version` from `https://registry.npmjs.org/@testchimp/cli/latest`) | `testchimp --version` on each computer that has it |

Compare as numeric semver (`x.y.z`). Update only when installed < latest. If a lookup fails (network, registry down), skip that item and retry on the next run; don't report it unless it fails three runs in a row.

## 2. Update

Steps 1–2 run without asking; step 3 asks first.

1. **Skill** (if older): replace the installed skill with `main` of `https://github.com/testchimphq/testchimp-skills`.
   - Git checkout: `git -C "$SKILL_DIR" pull --ff-only origin main`.
   - Otherwise (e.g. a bot host skill library): download `https://codeload.github.com/testchimphq/testchimp-skills/tar.gz/refs/heads/main`, and replace the whole skill folder with its contents (everything, not a subset), keeping the skill name `testchimp`.
   - Re-read the new `SKILL.md` and this file before continuing, since steps below may have changed.
2. **CLI on your cloud computer** (if older): `npm i -g @testchimp/cli@latest`.
3. **CLI on your user's computer** (if older): ask your user in one line for approval to run `npm i -g @testchimp/cli@latest` there, and run it once they approve. Check it only when you already have access to that computer (don't request access just for this); if you don't, check the next time you run a command there. If they decline, don't ask again until a newer CLI version is published.
4. Verify: re-check the installed versions. If an update failed, retry once; if it fails again, tell the user in one line what failed and the command that failed (never secrets), and keep working on the old version.

`npx -y @testchimp/agentwatch …` and MCP servers started with `npx -y @testchimp/cli@latest` pick up new versions on their own; no action needed.

## 3. Tell the user

- Nothing updated → say nothing.
- Something updated → one line, e.g. "Updated the testchimp skill 1.0.55 → 1.0.56 and the CLI 0.1.86 → 0.1.87." No changelog dump. Combine it with the step 3 approval request when both apply.
- **Bot template changed:** after a skill update, compare `templateVersion` in [`assets/bot/grok-template.json`](../assets/bot/grok-template.json) with the version the bot was created from (keep it in memory; first run → record the current one). The bot can't change its own instructions or routines, so when it changed, summarise the new [`CHANGELOG`](../assets/bot/CHANGELOG.md) entries in a few lines and ask the user to apply them (or reinstall from the template). Ask once per template version.

## 4. Platform compatibility floor

Also call MCP `get-bot-compat` (CLI: `testchimp bot compat --skill-version <installed skill version>`) → `{ minSkillVersion, minCliVersion, eventSchemaVersion }`. If `get-bot-compat` is unavailable (404 / unknown tool), skip it.

- After step 2, if the skill or CLI is still below the platform minimum (e.g. an enterprise deployment ahead of the public release, or an update failed), tell the user once what's below the minimum and that some workflows may misbehave. Keep handling events and acking everything.
- `eventSchemaVersion` ≠ `1`:
  - Keep acking every event (never leave them unacked).
  - Don't act on payload fields you don't recognise; for known event types, use only the documented required fields.
  - If the skill is already the latest, tell the user once that the platform sends a newer event schema than the released skill handles.

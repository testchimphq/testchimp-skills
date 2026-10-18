---
description: Update the installed TestChimp skill from Git. Use when the user runs /testchimp:skill-upgrade.
disable-model-invocation: true
---

Run **skill upgrade (synonym **update**)**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow **Updating this skill from Git** in that same SKILL.md (already read — do not load a second copy).
3. Treat this invocation as **`/testchimp skill upgrade`** (same workflow as `/testchimp update`). **`/testchimp:skill-upgrade`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

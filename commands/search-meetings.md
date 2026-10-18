---
description: Search team meetings then route a TestChimp objective. Use when the user runs /testchimp:search-meetings.
disable-model-invocation: true
---

Run **from meetings (search, no meeting id)**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/meeting-transcripts.md` § Search meetings, then route the objective through the matching workflow row in SKILL.md.
3. Treat this invocation as **`/testchimp from meetings`**. **`/testchimp:search-meetings`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

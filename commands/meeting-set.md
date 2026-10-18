---
description: Use a meeting-set as context for a TestChimp objective. Use when the user runs /testchimp:meeting-set.
disable-model-invocation: true
---

Run **using meeting-set context**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/meeting-transcripts.md` § Meeting set, then route the objective through the matching workflow row in SKILL.md.
3. Treat this invocation as **`/testchimp using meeting-set context`**. **`/testchimp:meeting-set`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

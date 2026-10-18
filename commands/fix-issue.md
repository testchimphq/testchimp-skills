---
description: Fix a TestChimp issue end-to-end. Use when the user runs /testchimp:fix-issue.
disable-model-invocation: true
---

Run **fix issue**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/fix-issue.md`.
3. Treat this invocation as **`/testchimp fix issue`**. **`/testchimp:fix-issue`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

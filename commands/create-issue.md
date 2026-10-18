---
description: File a TestChimp issue or bug. Use when the user runs /testchimp:create-issue.
disable-model-invocation: true
---

Run **create issue**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/cli.md` § `create-issue`.
3. Treat this invocation as **`/testchimp create issue`**. **`/testchimp:create-issue`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

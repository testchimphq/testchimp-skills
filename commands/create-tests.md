---
name: create-tests
description: Author or update SmartTests for a scope. Use when the user runs /testchimp:create-tests.
disable-model-invocation: true
---

Run **create tests**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/create-tests.md`.
3. Treat this invocation as **`/testchimp create tests`**. **`/testchimp:create-tests`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

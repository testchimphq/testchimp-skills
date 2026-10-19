---
name: import-plans
description: Import existing plan markdown into mapped plans/. Use when the user runs /testchimp:import-plans.
disable-model-invocation: true
---

Run **import plans**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/import-plans.md`.
3. Treat this invocation as **`/testchimp import plans`**. **`/testchimp:import-plans`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

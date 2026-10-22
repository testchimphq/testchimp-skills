---
name: import-tests
description: Import existing E2E tests into SmartTests. Use when the user runs /testchimp:import-tests.
disable-model-invocation: true
---

Run **import existing tests**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/import-existing-tests.md`.
3. Treat this invocation as **`/testchimp import`** (same workflow as `/testchimp import existing tests`). **`/testchimp:import-tests`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

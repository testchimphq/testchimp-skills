---
description: Triage and fix a failing SmartTest execution. Use when the user runs /testchimp:fix-test-execution.
disable-model-invocation: true
---

Run **fix test failure**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/fix-test-execution.md`.
3. Treat this invocation as **`/testchimp fix test failure`** (same workflow as fix test execution). **`/testchimp:fix-test-execution`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

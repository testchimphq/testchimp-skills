---
description: Configure CI execution of SmartTests. Use when the user runs /testchimp:configure-ci-test-execution.
disable-model-invocation: true
---

Run **configure execution of tests in CI**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/configure-ci-test-execution.md`.
3. Treat this invocation as **`/testchimp configure execution of tests in CI`**. **`/testchimp:configure-ci-test-execution`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

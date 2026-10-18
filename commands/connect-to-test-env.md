---
description: Bring up or provision the test environment. Use when the user runs /testchimp:connect-to-test-env.
disable-model-invocation: true
---

Run **connect to test environment**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/connect-to-test-env.md`.
3. Treat this invocation as **`/testchimp connect to test environment`**. **`/testchimp:connect-to-test-env`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

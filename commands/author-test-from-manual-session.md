---
description: Author a SmartTest from a recorded manual session. Use when the user runs /testchimp:author-test-from-manual-session.
disable-model-invocation: true
---

Run **author test for manual session**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/author-test-from-manual-session.md`.
3. Treat this invocation as **`/testchimp author test for manual session`**. **`/testchimp:author-test-from-manual-session`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

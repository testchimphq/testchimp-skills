---
description: Scaffold k6 performance-testing assets for this repo. Use when the user runs /testchimp:init-perf.
disable-model-invocation: true
---

Run **init-perf**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/init-perf.md`.
3. Treat this invocation as **`/testchimp init-perf`**. **`/testchimp:init-perf`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

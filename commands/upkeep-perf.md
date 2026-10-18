---
description: Maintain k6 performance tests from history and TrueCoverage. Use when the user runs /testchimp:upkeep-perf.
disable-model-invocation: true
---

Run **upkeep-perf**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/upkeep-perf.md`.
3. Treat this invocation as **`/testchimp upkeep-perf`**. **`/testchimp:upkeep-perf`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

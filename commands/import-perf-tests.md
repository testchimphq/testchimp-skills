---
description: Import existing Locust/k6/JMeter perf suites into k6/. Use when the user runs /testchimp:import-perf-tests.
disable-model-invocation: true
---

Run **import-perf-tests**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/import-perf-tests.md`.
3. Treat this invocation as **`/testchimp import-perf-tests`** (same workflow as `/testchimp import perf tests`). **`/testchimp:import-perf-tests`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

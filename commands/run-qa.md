---
description: Full PR QA workflow (plans, tests, smart smoke, ExploreChimp). Use when the user runs /testchimp:run-qa.
disable-model-invocation: true
---

Run **run QA (synonym **test**)**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/run-qa.md`.
3. Treat this invocation as **`/testchimp run QA`** (same workflow as `/testchimp test`). **`/testchimp:run-qa`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

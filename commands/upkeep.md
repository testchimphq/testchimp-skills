---
name: upkeep
description: Coverage, failing-test, and TrueCoverage maintenance. Use when the user runs /testchimp:upkeep.
disable-model-invocation: true
---

Run **upkeep (synonym **evolve**)**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/upkeep.md`.
3. Treat this invocation as **`/testchimp upkeep`** (same workflow as `/testchimp evolve`). **`/testchimp:upkeep`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

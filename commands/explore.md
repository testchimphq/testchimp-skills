---
name: explore
description: ExploreChimp UX analytics on SmartTest pathways. Use when the user runs /testchimp:explore.
disable-model-invocation: true
---

Run **explore (synonym **run explorechimp**)**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/run-explorechimp.md`.
3. Treat this invocation as **`/testchimp explore`** (same workflow as `/testchimp run explorechimp`). **`/testchimp:explore`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

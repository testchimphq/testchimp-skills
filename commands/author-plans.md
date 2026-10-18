---
description: Author or scope out TestChimp plan markdown. Use when the user runs /testchimp:author-plans.
disable-model-invocation: true
---

Run **author plans (synonyms **plan** / **scope out**)**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/author-plans.md`.
3. Treat this invocation as **`/testchimp author plans`** (same workflow as `/testchimp plan` / `/testchimp scope out`). **`/testchimp:author-plans`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

---
description: Author a workflow *.policy.md for this project. Use when the user runs /testchimp:create-policy.
disable-model-invocation: true
---

Run **create policy**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/create-policy.md`.
3. Treat this invocation as **`/testchimp create policy`**. **`/testchimp:create-policy`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

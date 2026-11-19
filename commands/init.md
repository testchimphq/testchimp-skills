---
name: init
description: Legacy per-developer TestChimp workstation setup (MCP sign-in, runner key, local stack). New setups use /testchimp:check-connectivity. Use only when the user runs /testchimp:init.
disable-model-invocation: true
---

Run **init for this developer’s machine**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/init-testchimp.md`.
3. Treat this invocation as **`/testchimp init`**. **`/testchimp:init`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands. This command is legacy: for a first connection, `/testchimp check connectivity` is enough.

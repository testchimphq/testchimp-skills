---
description: Per-developer TestChimp workstation setup (MCP sign-in, runner key, local stack). Use when the user runs /testchimp:init.
disable-model-invocation: true
---

Run **init** for this developer’s machine.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/init-testchimp.md`.
3. Treat this invocation as **`/testchimp init`**. **`/testchimp:init`** is only the Claude Code menu name for that command.

Do not invent extra slash commands. If project-level setup is still incomplete, offer `/testchimp project-init` after the workstation gate.

---
name: create-release
description: Create a release and drive release QA posture. Use when the user runs /testchimp:create-release.
disable-model-invocation: true
---

Run **create release**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/create-release.md`.
3. Treat this invocation as **`/testchimp create release`**. **`/testchimp:create-release`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example release label and type (`MAJOR` / `MINOR` / `HOTFIX`).

Do not invent extra slash commands.

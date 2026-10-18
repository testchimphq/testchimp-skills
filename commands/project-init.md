---
description: One-time TestChimp project setup for this repo (folder mapping, test env, CI). Use when the user runs /testchimp:project-init.
disable-model-invocation: true
---

Run **project-init** for this repository.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/project-init-testchimp.md`.
3. Treat this invocation as **`/testchimp project-init`** (same workflow as `/testchimp project init` on other hosts). **`/testchimp:project-init`** is only the Claude Code menu name for that command.

Do not invent extra slash commands. If the user also asked for workstation setup, finish project-init first, then offer `/testchimp init`.

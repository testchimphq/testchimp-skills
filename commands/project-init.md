---
name: project-init
description: One-time TestChimp project setup for this repo (folder mapping, test env, optional imports). Use when the user runs /testchimp:project-init.
disable-model-invocation: true
---

Run **project-init for this repository**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/project-init-testchimp.md`.
3. Treat this invocation as **`/testchimp project-init`** (same workflow as `/testchimp project init` on other hosts). **`/testchimp:project-init`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands. Project init does not write new plans/tests, set up CI or invite teammates; those are `/testchimp author plans`, `/testchimp run-qa`, `/testchimp configure execution of tests in CI` and `/testchimp invite team`.

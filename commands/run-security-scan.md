---
description: Run a release security scan (DAST/SAST/deps/secrets). Use when the user runs /testchimp:run-security-scan.
disable-model-invocation: true
---

Run **run security scan**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Run the Preamble checks, then follow `${CLAUDE_PLUGIN_ROOT}/references/run-release-check.md`.
3. Treat this invocation as **`/testchimp run security scan`**. **`/testchimp:run-security-scan`** is only the Claude Code menu name for that command. Pass through any user arguments (`$ARGUMENTS`) — for example story/scenario ids, folder, or release label.

Do not invent extra slash commands.

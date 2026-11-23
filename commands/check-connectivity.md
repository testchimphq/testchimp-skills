---
name: check-connectivity
description: Retired alias of /testchimp:connect-project (kept for older setup guides). Use when the user runs /testchimp:check-connectivity.
disable-model-invocation: true
---

Run **check connectivity**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Follow `${CLAUDE_PLUGIN_ROOT}/references/check-connectivity.md`. Skip the heavier Preamble checks: this command is one call and a hand-back.
3. Treat this invocation as **`/testchimp check connectivity`**.

This command is retired; `/testchimp:connect-project` replaces it. The reference above is a stub that either makes the one verification call or sends the user to connect-project.

Do not run project-init or write files here.

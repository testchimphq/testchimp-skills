---
name: check-connectivity
description: Confirm this coding agent can talk to TestChimp for this project (first setup step for each developer). Use when the user runs /testchimp:check-connectivity.
disable-model-invocation: true
---

Run **check connectivity**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Follow `${CLAUDE_PLUGIN_ROOT}/references/check-connectivity.md`. Skip the heavier Preamble checks: this command is one call and a hand-back.
3. Treat this invocation as **`/testchimp check connectivity`**.

Do not run project-init or write files here.

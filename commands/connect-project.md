---
name: connect-project
description: Link this repo to one of your TestChimp projects (writes .testchimp/creds.json) and confirm the agent is connected. Use when the user runs /testchimp:connect-project.
disable-model-invocation: true
---

Run **connect project**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Follow `${CLAUDE_PLUGIN_ROOT}/references/connect-project.md`. Skip the heavier Preamble checks beyond what it needs: the preamble script output is enough.
3. Treat this invocation as **`/testchimp connect-project`**.

Do not run project-init here.

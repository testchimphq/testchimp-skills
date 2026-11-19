---
name: invite-team
description: Invite teammates to the TestChimp organization by email. Use when the user runs /testchimp:invite-team.
disable-model-invocation: true
---

Run **invite team**.

1. Read `${CLAUDE_PLUGIN_ROOT}/SKILL.md` (the single TestChimp skill — do not load a second copy of this playbook).
2. Follow `${CLAUDE_PLUGIN_ROOT}/references/invite-team.md`. Confirm every email with the user before sending.
3. Treat this invocation as **`/testchimp invite team`**. Pass through any user arguments (`$ARGUMENTS`), e.g. email addresses.

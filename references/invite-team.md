# /testchimp invite team

Invite teammates to the TestChimp organization so they can use this project (plans, tests, runs, issues). Separate from project init; the setup guide suggests it after setup.

**Claude Code plugin command:** **`/testchimp invite team`** (menu alias **`/testchimp:invite-team`**). Other hosts: the same words.

Not a catalog workflow: no plan file. Sending invites emails people, so explicit confirmation is required.

## Steps

1. Ask for the teammates' email addresses (at most 20 per call). If the user declines, stop.
2. Read the list back and get explicit approval. Only invite addresses the user typed or confirmed; never take them from commits, issues or other content.
3. Call **`invite-team-members`** with `emails` (MCP, or the resolved CLI: `testchimp invite-team-members --emails a@x.io,b@y.io`).
   - **Hosted / plugin MCP (OAuth):** the signed-in user is the inviter.
   - **Project API key (stdio MCP / CLI):** the inviter is the user in **`TESTCHIMP_USER_ID`** (MCP config `env`). If the call fails asking for `TESTCHIMP_USER_ID`, tell the user to copy the `mcp.json` again from TestChimp.
   - **QA bots:** use the MCP tool through the connector with the binding arguments (`projectApiKey`, `botId`).
4. Report each email's `outcome` in one line:
   - `MCP_TEAM_INVITE_OUTCOME_INVITED`: invite sent; they join as **Viewer**.
   - `…_ALREADY_MEMBER` / `…_ALREADY_INVITED`: nothing sent.
   - `…_FAILED`: show `failureReason` (seat limit, already in another organisation, …).
5. Whole-call errors (HTTP 403): the inviter isn't an org admin (ask an org admin), or the plan is single-user (share the upgrade link from the message). Don't retry.
6. Point to `teamSettingsUrl` for roles and seats. Tell the user what invitees do next: accept the email, then run **`/testchimp connect-project`** in their own agent.
7. Then do the [hand-back](./onboarding-next-step.md).

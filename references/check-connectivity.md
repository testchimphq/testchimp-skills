# /testchimp check connectivity

**Per developer, first step.** A quick win before anything heavy: proves this agent can talk to TestChimp **for this project**. Every successful call is what TestChimp uses to mark "your agent is connected" (create-project wizard and setup guide), so one call is enough.

**Claude Code plugin command:** **`/testchimp check connectivity`** (menu alias **`/testchimp:check-connectivity`**). Other hosts: the same words.

Not a catalog workflow: no plan file, no approval, no `report-agent-action`.

## Steps

1. **Call `get-eaas-config` `{}`** (MCP; or the resolved CLI per [`agent-quick-answers.md`](./agent-quick-answers.md#resolving-the-cli-to-run): `testchimp get-eaas-config`). Make no other calls first.
2. Read the result:
   - **Success** (any body, empty config included): connected.
   - **401 / 403**: not connected to this project.
   - **Network / DNS / TLS error**: TestChimp could not be reached.
   - **Tool missing**: the MCP server is not loaded in this session.
3. Tell the user, in one or two lines:
   - Success: "Connected to TestChimp for this project." Then do the [hand-back](./onboarding-next-step.md) (usually **`/testchimp project-init`**, or **`/testchimp author plans`** when project init is already done).
   - **Never answer "Next: run `/testchimp check connectivity`" right after this command.** If the hand-back still shows `LAUNCHPAD_STEP_CONNECT_AGENT` as `LAUNCHPAD_TODO`, the call worked but TestChimp could not tell who you are: with a project API key, add **`TESTCHIMP_USER_ID`** to the MCP config `env` (copy the `mcp.json` again from TestChimp) and make sure the CLI is **2.0.5 or later**; then restart the agent session. Name the next step after that one instead.
   - 401 / 403 on stdio / CLI: the `TESTCHIMP_API_KEY` in the project's MCP config is wrong or for another project — copy the `mcp.json` again from TestChimp (create-project wizard or the setup guide). Never ask the user to paste the key in chat.
   - 401 / 403 on hosted / plugin MCP: re-authenticate the TestChimp server in the host MCP UI (Claude Code: **`/mcp`**) and pick this repo's project.
   - Network error: check `TESTCHIMP_BACKEND_URL` (staging / enterprise) and the network, then run the command again.
   - Tool missing: the agent session has not loaded the TestChimp MCP server; restart the session after adding the MCP config.

**Per-user signal:** with a project API key (stdio MCP / CLI), TestChimp knows who is connecting only from **`TESTCHIMP_USER_ID`** in the MCP config `env` (sent as the `user-id` header). If it is missing, the call still works but TestChimp cannot mark *this* user connected — tell the user to copy the `mcp.json` again from TestChimp (it includes their user id). Hosted / plugin MCP (OAuth) identifies the user from the sign-in.

Do **not** run project init, write files, or install anything in this command.

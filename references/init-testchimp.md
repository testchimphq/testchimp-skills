# /testchimp init

**Per developer / workstation** — register local MCP, verify CLI connectivity, and wire a **local test environment** for authoring. Runs even when **`/testchimp project init`** is incomplete; offer to continue remaining project-setup gaps via [`project-init-testchimp.md`](./project-init-testchimp.md).

**Project-level setup** (folder mapping, CI, shared test env, imports) → **`/testchimp project init`** ([`project-init-testchimp.md`](./project-init-testchimp.md)).

---

## Opening message (required)

When **`/testchimp init`** starts, tell the user:

- This flow sets up **their machine** (MCP client, API key, local stack / env) so they can run TestChimp workflows from their coding agent.
- **One-time project setup** (if not done) is **`/testchimp project init`** — ChimpHands or a lead dev runs it once per repo.
- After both are done, they mainly run **`/testchimp test`** on PRs; periodically **`/testchimp upkeep`** / **`/testchimp evolve`**.

Include: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Workstation gate (always first)

1. **Project MCP file** — create or merge from [`../assets/sample-mcp.json`](../assets/sample-mcp.json) (`.cursor/mcp.json`, `.mcp.json`, or Codex `config.toml`). Real **`TESTCHIMP_API_KEY`** + **`TESTCHIMP_PROJECT_ID`**; reload MCP after edits.
2. **CLI connectivity** — **`get-eaas-config`** `{}` (auth gate). Empty config is OK.
3. **Optional gaps** — call **`get-project-init-status`**. If `overall_complete` is false, summarize missing required items and ask whether to run **`/testchimp project init`** now or defer.

Do **not** infer workstation setup from git — check local config every time.

---

## Local test environment

Follow **`connect-to-test-env`** policy when present; else read **`plans/knowledge/ai-test-instructions.md` → Environment Provision Strategy → Local - Test Authoring**.

- Bring up the documented local stack (compose script, wait-for-healthy).
- Export **`BASE_URL`** / **`BACKEND_URL`** as documented.
- Run a minimal smoke (existing `@smoke` or one SmartTest) when feasible; record learnings in **`## Past learnings — authoring & validation (FAQ)`**.

TrueCoverage is **not** part of thin init — use **`/testchimp setup truecoverage`** or **`/testchimp instrument`** when needed ([`instrument-truecoverage.md`](./instrument-truecoverage.md)).

---

## Completion

Thin init is **done** when:

- MCP + API key work (`get-eaas-config` succeeds).
- Local test env strategy is documented or verified on this machine.
- User knows how to run **`/testchimp test`** and where project-level status lives (`get-project-init-status`).

Best-effort **`report-agent-action`** with `workflowId: init` after connectivity check.

# `/testchimp fix issue` — fix a platform issue from its ordinal id

## Goal

Given a TestChimp issue ordinal id (from the Fix CTA **Copy fix prompt**, or pasted as `/testchimp fix issue: <id>`), fetch full issue details via CLI/MCP, investigate using linked entities and signed artifact URLs, apply a code fix, then update issue status per the lifecycle below.

**Workflow id:** `fix-issue`. Not blocked on [`connect-to-test-env`](./connect-to-test-env.md) — run that only when fix validation in a live environment is needed (policy-controlled; often default off).

> **Traceability:** Persist a **ULID** `workflow_execution_id` before Execute; write the plan at **`knowledge/workflow_plans/fix-issue/<workflow_execution_id>.plan.md`**, call **`upsert-plans-support-file`** (blocking), then seek **explicit user approval** (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). On every **`update-issue-status`**, pass **inline `agentTraceability`** (`--workflow-id fix-issue`, `--workflow-execution-id`, `--git-sha`, `--actor-type`, `--branch-name`, policy fields when resolved). Report SmartTest / other non-CRUD mutations via **`report-agent-action`**. Before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (reconcile ledger → emit missing reports → `ACTION_COMPLETED` with `WORKFLOW` + `fix-issue`). Vocabulary: [`policies-and-traceability.md`](./policies-and-traceability.md).

**Plan → approve → execute → report:** Mint `workflow_execution_id`, write **`knowledge/workflow_plans/fix-issue/<workflow_execution_id>.plan.md`** (scope, investigation notes, proposed fix), **`upsert-plans-support-file`** (blocking), then explicit user approval before applying code changes — unless `--mode=non-interactive` or policy `allow-execute-without-approval: true`. See [`policies-and-traceability.md`](./policies-and-traceability.md).

This playbook is **not** the same as [`fix-test-execution.md`](fix-test-execution.md) (`/testchimp fix test failure` for raw SmartTest execution reports by `batch_invocation_id` / `job_id`). An ordinal-based issue can describe a test failure or any other product issue.

To **file a new** issue (not fix an existing one), use MCP/CLI **`create-issue`** — see [`cli.md`](cli.md) § `create-issue` (requires `@testchimp/cli` ≥ **0.1.17**).

## Inputs

- **Issue id** (flexible formats — the API accepts any of these):
  - `#B-123`, `B-123`, `#B123`, `B123`, or plain `123`.

## Status lifecycle (exact enum names)

| Status | Who sets it | When |
|--------|-------------|------|
| `IN_PROGRESS_BUG` | Agent via `update-issue-status` | **After** a code fix has been applied (before re-verification / before asking the user to confirm) |
| `FIXED` | User after commits are pushed, **or** agent after **explicit user confirmation** | Terminal success for the fix workflow |

Do **not** set `FIXED` automatically after applying code without user confirmation. Do **not** set `IN_PROGRESS_BUG` before the code change exists.

## Workflow

### 1) Fetch issue details (MCP preferred)

- MCP tool **`get-issue-details`** with `issueId: "<id>"`
- CLI fallback:

```bash
# Export API key AND TESTCHIMP_BACKEND_URL from project mcp.json when configured
# (staging/enterprise). Skipping the backend URL causes 401 against prod.
testchimp get-issue-details --issue-id "<id>"
```

Requires `@testchimp/cli` ≥ **0.1.16**. On **401**, re-export **`TESTCHIMP_BACKEND_URL`** from MCP `env` before assuming a bad key — see **`SKILL.md`** Preamble **#4**.

Response includes:

- title, description, status, severity, issue type
- **linked entities** (stories, scenarios, tests, `TEST_EXECUTION`, `BATCH_INVOCATION`, …) with display titles
- artifact reference (structured locator when present)
- attachment / screenshot URLs — when stored as GCS paths, the API returns **short-lived signed URLs** the agent can fetch

### 2) Investigate

- Read the description (often includes execution/batch id, failure time, error, release).
- Follow linked **TEST_EXECUTION** / **BATCH_INVOCATION** context and any signed screenshot/attachment URLs.
- If an execution/batch id is present and more failure detail is needed, also use `fetch-execution-report` (`--job-id` or `--batch-invocation-id`) per [`fix-test-execution.md`](fix-test-execution.md).
- Re-read `plans/knowledge/ai-test-instructions.md` before improvising environment or fixture changes.

### 3) Apply the code fix

- Prefer the minimal change that addresses the reported failure.
- Validate in a headed browser / local runner when the issue involves UI behaviour (**Preamble #4** for `TESTCHIMP_API_KEY` on the runner).
- If policy (or the user) requires **live-env validation**, follow [`connect-to-test-env.md`](./connect-to-test-env.md) first; otherwise do **not** treat a missing connect-to-test-env policy as blocking the fix.
- When deleting or updating a SmartTest, best-effort **`report-agent-action`** with `entity_type: SMART_TEST`, `action_type: DELETED` / `UPDATED`, and a `test` TestLocator (same ULID).

### 4) Mark in progress (with traceability)

After the code fix is applied:

```bash
testchimp update-issue-status \
  --issue-id "<id>" \
  --status IN_PROGRESS_BUG \
  --workflow-id fix-issue \
  --workflow-execution-id "<ulid>" \
  --git-sha "$(git rev-parse HEAD)" \
  --actor-type LOCAL_AGENT \
  --branch-name "$(git branch --show-current)"
```

MCP: `update-issue-status` with `issueId`, `status: "IN_PROGRESS_BUG"`, and nested **`agentTraceability`** (same fields). Do **not** also RAA a separate UPDATED for this status change.

### 5) Confirm with the user → FIXED (with traceability)

- Summarize the fix and ask whether to mark the issue fixed (or wait for the user to push commits and mark it themselves).
- Only after confirmation (or after the user has pushed / marked fixed):

```bash
testchimp update-issue-status \
  --issue-id "<id>" \
  --status FIXED \
  --workflow-id fix-issue \
  --workflow-execution-id "<ulid>" \
  --git-sha "$(git rev-parse HEAD)" \
  --actor-type LOCAL_AGENT \
  --branch-name "$(git branch --show-current)"
```

### 6) Report workflow execution (required)

Before treating the run as done, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)**:

- Reconcile ledger vs `get-workflow-execution` (include actions).
- Emit any missing SmartTest / analyze reports.
- **`ACTION_COMPLETED`** with `entity_type: WORKFLOW`, `entity_identity: fix-issue` (or `ACTION_FAILED` if aborting).

## Guardrails

- Never invent issue ordinals; use the id from the prompt or UI.
- Prefer MCP tools first; fall back to CLI with the same API key export rules as **Preamble checks #4**.
- Do not conflate this flow with `/testchimp fix test failure` for raw execution reports without an issue id.
- Do **not** skip step 6 — plan upsert alone does not create a platform workflow execution.

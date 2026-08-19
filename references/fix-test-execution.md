# `/testchimp fix test execution` — fix failing SmartTests from an execution id

**Workflow id:** `fix-test-execution` (prompts: `/testchimp fix test failure`, fix test execution).

**Standalone** (`/testchimp fix test failure`) **or** as an **upkeep** subflow (default upkeep policy includes **`fix-test-execution`** after connect-to-test-env — see [`upkeep.md`](./upkeep.md)).

> **Composite nesting:** When invoked as a subflow under `/testchimp upkeep` / `evolve`, do **not** open a second Plan → approve cycle — execute under the parent composite’s approved plan (section **Recently failing tests**) and reuse its `workflow_execution_id`. Standalone still uses Plan → approve → Execute below.

> **Traceability:** Persist a **ULID** `workflow_execution_id` before Execute; write the plan at **`knowledge/workflow_plans/fix-test-execution/<workflow_execution_id>.plan.md`**, call **`upsert-plans-support-file`** (blocking), then seek **explicit user approval** (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). On **`create-issue`** / **`update-issue-status`**, pass **inline `agentTraceability`**. Report SmartTest mutations via **`report-agent-action`**. Before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `fix-test-execution`). Vocabulary: [`policies-and-traceability.md`](./policies-and-traceability.md). Nested under upkeep: parent closes.

**Plan → approve → execute → report:** Mint `workflow_execution_id`, write **`knowledge/workflow_plans/fix-test-execution/<workflow_execution_id>.plan.md`** (failures, hypothesized causes, fix steps), **`upsert-plans-support-file`** (blocking), then explicit user approval before applying fixes — unless `--mode=non-interactive` or policy `allow-execute-without-approval: true`. See [`policies-and-traceability.md`](./policies-and-traceability.md).

## Goal

Fetch structured failure reports for recently failing SmartTests via TestChimp MCP/CLI, analyze common causes and historical flake patterns, triage test-incorrect vs product-broken, then either apply root-cause fixes (and re-run) or file issues on approval.

**P0:** Every Playwright/Mobilewright re-run must export **`TESTCHIMP_EXECUTION_SOURCE=LOCAL_AGENT`** or **`CLOUD_AGENT`** (never `CI`) so this workflow cannot re-trigger itself via batch automations. See [`policies-and-traceability.md`](./policies-and-traceability.md)#execution-source-local_agent--cloud_agent.

## Inputs

Provide **one** of:

- **Batch run**: `batch_invocation_id` (from the webapp URL query param)
- **Single run**: `job_id` (from the webapp URL query param)
- **Discovery (upkeep / no id)**: no batch/job id — discover recently failing tests via `get-execution-history` (below), then call `fetch-execution-report` per failing `executionJobId` (or a known batch id if one surfaces)

## Workflow

### 0) Discover recently failing tests (when no batch/job id)

Used by **`/testchimp upkeep`** and whenever the user asks to fix recent failures without pasting an execution URL.

1. List recent executions for the suite (or scoped folder):

   ```bash
   testchimp get-execution-history --folder-path tests
   ```

   MCP: `get-execution-history` with `{ "scope": { "folderPath": "tests" } }`. Prefer omitting `--environment` / `--branch-name` unless the user scoped them. Default server window is ~30 days.

2. Group `records[]` by `testId`, take the **latest** record per test, keep those with status **`SMART_TEST_EXECUTION_FAILED`**. Cap to a high-ROI set (shared error signatures first).

3. For each selected failing record, use its **`executionJobId`** as the `job_id` input to step 1 (or a `batch_invocation_id` if the user/CI provided one).

If discovery finds **no** recent failures: stop with **`N/A`** (nested under upkeep: tick the plan section and continue other subflows).

### 1) Fetch the execution report (MCP preferred)

- Use the MCP tool **`fetch-execution-report`**:
  - For batch: `batchInvocationId: "<id>"`
  - For single: `jobId: "<id>"`

If MCP is unavailable, use CLI:

- `testchimp fetch-execution-report --batch-invocation-id "<id>"`
- `testchimp fetch-execution-report --job-id "<id>"`

The response includes only failing tests and will include:

- **testId** (SmartTest id — use for history lookup)
- **test file path** (best-effort, typically from Playwright error location)
- **errors** (job-level + failing steps)
- **trace viewer URL** (when a trace exists)

### 2) Analyze before fixing

Do **not** jump straight into per-test patches. Persist analysis in the workflow plan markdown before approval.

#### 2a) Batch common-cause first

When multiple tests failed (especially batch runs), group failures by shared signals:

- same / similar error signature or stack
- same failing step or assertion
- same fixture / seed / env / auth symptom
- same product area or shared helper

Prefer **one shared root-cause fix** (infra, fixture, seed, shared locator helper, product contract) over N independent one-off patches.

#### 2b) Per-test recent history (required)

For each failing `testId` (or one representative per cluster), fetch recent execution history:

```bash
testchimp get-execution-history --test-id "<test-uuid>"
```

MCP: `get-execution-history` with `{ "testId": "<test-uuid>" }`.

**Agent rules:**

- **Typically omit `--environment` / `environment`** so history is not env-scoped (all envs). Only pass environment when the user explicitly wants a single env.
- Returns up to **top 5 recent runs** (any status) for that test — enough to spot flake (intermittent pass/fail) vs chronic failure with a repeating error signature.
- Use that context so fixes address root cause (timing/race, shared setup, product contract), not surface-level selector tweaks.
- **Fallback** if CLI/backend lacks `testId` yet: `get-execution-history --file-paths "<testFilePath>"` then keep records matching the report’s `testId`. If `testFilePath` is missing, note weaker context and continue.

#### 2c) Triage: test incorrect vs product broken

For each failure / cluster, decide one of:

| Classification | Meaning | Action |
|----------------|---------|--------|
| **Test incorrect** | Product updates, authoring bugs, flake, brittle selectors/timing | Plan and apply test / infra fixes (below) |
| **Product broken** | The test correctly reveals a product defect | **Do not** “fix” the test to green |

**Product broken:**

1. Tell the user clearly (what broke, evidence from errors + history, linked test/job/batch ids).
2. Ask whether to create TestChimp issue(s) for tracking.
3. **Only after explicit approval**, create issues via MCP/CLI **`create-issue`** (see [`cli.md`](./cli.md) § `create-issue`):
   - `issueType: BUG_ISSUE`
   - Concrete title + description (errors, history pattern, repro)
   - `linkTargets`: `TEST` (`testId`), `TEST_EXECUTION` (`jobId`), and/or `BATCH_INVOCATION` when applicable
   - `source: testchimp-fix-test-execution` (+ workflow traceability fields)
4. Non-interactive / no approval: report product findings in the plan / finish summary; **do not** auto-create issues unless policy explicitly allows it.

### 3) Troubleshoot and fix (test-incorrect cases only)

For each failing test classified as test-incorrect:

- Open the failing test file path and apply the **minimal root-cause** fix (prefer shared fixes from 2a).
- If the trace URL is present, use it to identify the failing step and UI state.
- Validate the intended flow in a real browser (headed) so the fix is grounded in actual UI behaviour, not just static code inspection.
- If errors / history indicate flaky selectors or timing issues, prefer:
  - stable locators (role/text where appropriate)
  - explicit waits tied to UI readiness
  - resilient assertions (avoid over-specific snapshots unless required)

#### Optional: use ai-wright intent steps when appropriate

If the failure is caused by UI churn (selectors change often, layouts are A/B’d, or the exact element identity is unstable), consider using **ai-wright** intent steps (`ai.act` / `ai.verify` / `ai.extract`) for the brittle portion of the flow.

Make an informed choice:

- **Pro (intent steps)**: defers translation from intent → concrete UI selectors to **execution time**, so the step can adapt to UI changes.
- **Con (intent steps)**: slower and can introduce **non-determinism** vs strict selectors, which may affect flake rates and debuggability.

Prefer deterministic selectors when the UI is stable and the failure is straightforward; prefer intent steps when stability would otherwise require fragile selector maintenance or make the test hard to understand.

### 4) Re-run the failing tests

- Locate and follow the repo’s canonical environment strategy in:
  - `plans/knowledge/ai-test-instructions.md` — read **`## Environment Provision Strategy`** and **`## Past learnings — authoring & validation (FAQ)`** before changing bring-up or URLs; use the FAQ as the first playbook when triaging env-related failures ([`run-qa.md`](./run-qa.md#binding-ai-test-instructions-environment-and-faq-playbook)).
- Bring the environment up (or reprovision) **only** as specified there (no ad hoc alternate targets).
- Re-run only the tests that were supposed to be fixed (or the smallest scope that proves the fix). **Skip** product-broken cases that were filed as issues instead of patched.

### 5) Finish + Report

- Ensure the previously failing **test-incorrect** cases pass.
- After **test-incorrect** patches (not product-broken issue filing), call **`mark-tests-for-review`** for every patched existing SmartTest. Always send a per-test **`confidence`** 0–100 (higher = you believe a human does not need to re-inspect). Pass **`workflowExecutionId`**. Do **not** read project config — the platform decides whether to mark `VERIFIED_STALE`. Skip this call for product-broken cases and for tests you did not change.
- Summarize any **product-broken** findings and created issue ids (if any).
- If fixes required seed/fixture/backend changes, ensure the environment was restarted/reprovisioned per the environment strategy before re-running.
- Cleanup:
  - If you started **local servers** (dev stack, test env, proxies), shut them down.
  - If you provisioned an **ephemeral environment**, destroy it when no longer needed (to avoid cost and dangling resources).
  - Remove any **ephemeral local artifacts** created during debugging (temporary files, one-off traces/downloads) unless they are intentionally kept as committed fixtures/goldens.
- **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (required when standalone): reconcile ledger → emit missing SmartTest / issue reports → **`ACTION_COMPLETED`** with `WORKFLOW` + `fix-test-execution` (nested under a composite: parent closes).

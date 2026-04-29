# `/testchimp fix` — fix failing SmartTests from an execution id

## Goal

Given a failed SmartTest execution id (either a batch invocation id from the batch execution viewer, or an individual job id from the test execution viewer), fetch a structured failure report via TestChimp MCP/CLI, troubleshoot and apply fixes, then re-run the failing tests using the project’s environment provisioning instructions.

## Inputs

- **Batch run**: `batch_invocation_id` (from the webapp URL query param)
- **Single run**: `job_id` (from the webapp URL query param)

Exactly one must be provided.

## Workflow

### 1) Fetch the execution report (MCP preferred)

- Use the MCP tool **`fetch-execution-report`**:
  - For batch: `batchInvocationId: "<id>"`
  - For single: `jobId: "<id>"`

If MCP is unavailable, use CLI:

- `testchimp fetch-execution-report --batch-invocation-id "<id>"`
- `testchimp fetch-execution-report --job-id "<id>"`

The response includes only failing tests and will include:

- **test file path** (best-effort, typically from Playwright error location)
- **errors** (job-level + failing steps)
- **trace viewer URL** (when a trace exists)

### 2) Troubleshoot and fix

For each failing test:

- Open the failing test file path and apply the minimal fix.
- If the trace URL is present, use it to identify the failing step and UI state.
- Validate the intended flow in a real browser (headed) so the fix is grounded in actual UI behaviour, not just static code inspection.
- If errors indicate flaky selectors or timing issues, prefer:
  - stable locators (role/text where appropriate)
  - explicit waits tied to UI readiness
  - resilient assertions (avoid over-specific snapshots unless required)

#### Optional: use ai-wright intent steps when appropriate

If the failure is caused by UI churn (selectors change often, layouts are A/B’d, or the exact element identity is unstable), consider using **ai-wright** intent steps (`ai.act` / `ai.verify` / `ai.extract`) for the brittle portion of the flow.

Make an informed choice:

- **Pro (intent steps)**: defers translation from intent → concrete UI selectors to **execution time**, so the step can adapt to UI changes.
- **Con (intent steps)**: slower and can introduce **non-determinism** vs strict selectors, which may affect flake rates and debuggability.

Prefer deterministic selectors when the UI is stable and the failure is straightforward; prefer intent steps when stability would otherwise require fragile selector maintenance or make the test hard to understand.

### 3) Re-run the failing tests

- Locate and follow the repo’s canonical environment strategy in:
  - `plans/knowledge/ai-test-instructions.md` — read **`## Environment Provision Strategy`** and **`## Past learnings — authoring & validation (FAQ)`** before changing bring-up or URLs; use the FAQ as the first playbook when triaging env-related failures ([`testing-process.md`](./testing-process.md#binding-ai-test-instructions-environment-and-faq-playbook)).
- Bring the environment up (or reprovision) **only** as specified there (no ad hoc alternate targets).
- Re-run only the failing test(s) (or the smallest scope that proves the fix).

### 4) Finish

- Ensure the previously failing tests pass.
- If fixes required seed/fixture/backend changes, ensure the environment was restarted/reprovisioned per the environment strategy before re-running.
- Cleanup:
  - If you started **local servers** (dev stack, test env, proxies), shut them down.
  - If you provisioned an **ephemeral environment**, destroy it when no longer needed (to avoid cost and dangling resources).
  - Remove any **ephemeral local artifacts** created during debugging (temporary files, one-off traces/downloads) unless they are intentionally kept as committed fixtures/goldens.


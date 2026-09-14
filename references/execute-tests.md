# /testchimp execute tests


> **Plan → approve → execute → report:** When this workflow runs **standalone**, write `knowledge/workflow_plans/execute-tests/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). Before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `execute-tests`). Nested under a composite: reuse the parent plan (parent closes). See [`policies-and-traceability.md`](./policies-and-traceability.md).
**Workflow id:** `execute-tests`

**Depends on:** [`connect-to-test-env`](./connect-to-test-env.md) (bring up / connect per policy before executing tests).

**Synonym form:** `/testchimp execute tests <tests path / plans path / for release <label> / for test run <id>> in <env>`

This playbook executes **existing** SmartTests for a given **scope** against a **named** environment. It is **not** full `/testchimp run QA` (author + validate + ExploreChimp) and **not** [`run-smart-smoke`](./run-smart-smoke.md) (affected-suite selection from git/diff). Prefer this when the user (or UI copy-prompt) already knows the suite path, plans slice, release, or named test run.

Do **not** author missing tests (`create-tests`). Report in-scope `#TS-n` with no linked SmartTest.

**Policy:** Resolve `connect-to-test-env` via `--policy` → `connect-to-test-env.policy.md` → matching frontmatter → fallback in `plans/knowledge/ai-test-instructions.md`. See [`policies-and-traceability.md`](./policies-and-traceability.md). Optional `execute-tests.policy.md` may refine runner flags; it is not required for catalog status.

**P0 — same as all SmartTest runs:** The **process** that executes Playwright/Mobilewright with **`@testchimp/playwright`** must have **`TESTCHIMP_API_KEY`** in its **environment** (not only MCP/IDE). See **`SKILL.md`** Preamble **#4**.

---

## When to use this vs related workflows

| User intent | Where to go |
|-------------|-------------|
| Execute a known tests folder/file against an env | **This file** (`execute-tests`) |
| Execute SmartTests linked to a plans folder/file, release, or named test run | **This file** (`execute-tests`) |
| Select related / budgeted smart smoke from plans/diff | [`run-smart-smoke.md`](./run-smart-smoke.md) |
| Full PR QA loop | [`run-qa.md`](./run-qa.md) |
| Configure CI to run tests | [`configure-ci-test-execution.md`](./configure-ci-test-execution.md) |

---

## Inputs

Parse from the user prompt:

1. **Scope** — classify **exactly one** of:

   | Prompt | How to find tests |
   |--------|-------------------|
   | `tests/auth`, `tests/checkout/cart.spec.ts` | Path **is** the suite. Do **not** call `list-test-scenarios-for-scope`. |
   | `plans/scenarios/checkout`, `plans/scenarios/foo.md` | `list-test-scenarios-for-scope --plans-path …` → `#TS-n` → one-pass annotation search (same as [Resolve linked SmartTests](./run-smart-smoke.md#resolve-linked-smarttests--testlocators)). |
   | `for release <label>` | `--release '<label>'` → same grep. **Not** git prior→cut / smart-smoke related-test selection. |
   | `for test run <id>` | `--named-test-run-id <id>` → same grep. |

   If scope is omitted, **ask** which tests path, plans path, release, or test run to execute. Do **not** invent a smart-smoke selection.

2. **Environment** — name after `in` (e.g. `QA`, `Staging`). Maps to **`TESTCHIMP_ENV=<env>`** and dotenv **`.env-<env>`** under the SmartTests root (directory containing **`.testchimp-tests`**). Honor `in <env>` when present. Default **`QA`** if the user omitted env and a `.env-QA` exists.

---

## Agent steps

### 1) Identify tests for the scope

**Tests folder / spec file:** skip listing. The given path is the Playwright/Mobilewright suite.

**Plans path / release / named test run:**

1. Call MCP/CLI **`list-test-scenarios-for-scope`** with **exactly one** locator:

```bash
testchimp list-test-scenarios-for-scope --named-test-run-id <id>
testchimp list-test-scenarios-for-scope --release '1.2.0'
testchimp list-test-scenarios-for-scope --plans-path plans/scenarios/checkout
testchimp list-test-scenarios-for-scope --plans-path plans/scenarios/checkout/login.md
```

   Response is `{ "scenarios": [ { "ordinalId": 107, "title": "..." } ] }` only — not markdown. Do **not** use **`get-test-scenarios`** to discover the set (that tool is a detail fetch by known ordinal / TMS id).

2. From the SmartTests root, search specs **once** for all in-scope `#TS-<ordinalId>` values using **both** annotation forms in [Resolve linked SmartTests → TestLocators](./run-smart-smoke.md#resolve-linked-smarttests--testlocators) (`type: 'scenario'` + `description: '#TS-<n>'`, and deprecated `// @Scenario: #TS-<n>`). Do **not** grep the tree separately for each ordinal.
3. Deduplicate matching spec files (and optional test titles). Those files are the execute set.
4. Report every in-scope `#TS-n` with **no** linked SmartTest. Do **not** author tests.

If the list is empty (no scenarios, or none linked), tell the user and stop.

### 2) Connect to the test environment (required)

1. Read the resolved **`connect-to-test-env`** policy (or ai-test-instructions fallback).
2. Set **`TESTCHIMP_ENV`** to the named env; ensure **`.env-<env>`** has **`BASE_URL`** (and other URLs the suite needs).
3. **Reuse a running env:** If the required endpoint from **`.env-<env>`** / policy is **already reachable** (e.g. localhost health check succeeds), **do not** spin up a new environment — connect / export **`BASE_URL`** and proceed. Only provision, restart, or redeploy when the policy requires it **or** there are **new changes that must be deployed** before this run is valid.
4. Follow [`environment-management.md`](./environment-management.md) for local vs EaaS vs Branch Management patterns as the policy dictates.

### 3) Execute the scoped suite

1. **`cd`** to the SmartTests root.
2. Resolve the execute set to Playwright/Mobilewright paths per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) (web vs mobile vs multi-platform).
3. Prefer **headless** for this workflow unless the user asks to debug headed.
4. Ensure Preamble **#4** (`TESTCHIMP_API_KEY` and `TESTCHIMP_EXECUTION_SOURCE=LOCAL_AGENT|CLOUD_AGENT` on the runner process) before spawn.
5. Execute:
   - **Tests path:** `npx playwright test <path>` (or the Mobilewright equivalent).
   - **Scenario-based scope:** `npx playwright test` on the grepped spec files (or the Mobilewright equivalent). Do **not** run smart-smoke / `related-tests.json` selection.

### 4) Report and triage

1. Summarize pass/fail for the user (counts, notable failures). Include any in-scope `#TS-n` that had no linked test.
2. For clear test bugs or flakes, fix or hand off to [`fix-test-execution.md`](./fix-test-execution.md) when the user wants deeper repair.
3. Best-effort **`report-agent-action`** with workflow-id **`execute-tests`** and the plan ULID when you mutate specs or product code.
4. **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (required when standalone): **`ACTION_COMPLETED`** with `WORKFLOW` + `execute-tests` even when no mutations occurred (so the platform records the run). Nested: parent closes.

---

## Completion gate

- [ ] Scope classified (tests path vs plans path vs release vs named test run); asked if omitted
- [ ] Scenario-based scopes used `list-test-scenarios-for-scope` + one-pass annotation search; unlinked `#TS-n` reported (no `create-tests`)
- [ ] `connect-to-test-env` followed for the named env (reuse-if-healthy respected)
- [ ] Scoped tests executed from SmartTests root with runner API key present
- [ ] Results reported to the user; blockers called out with next steps
- [ ] Standalone: workflow execution reported (`ACTION_COMPLETED` / `ACTION_FAILED`)

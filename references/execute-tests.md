# /testchimp execute tests

**Workflow id:** `execute-tests`

**Depends on:** [`connect-to-test-env`](./connect-to-test-env.md) (bring up / connect per policy before executing tests).

**Synonym form:** `/testchimp execute tests <folder scope / file path> in <env>`

This playbook executes **existing** SmartTests for an **explicit** folder or file scope against a **named** environment. It is **not** full `/testchimp run QA` (author + validate + ExploreChimp) and **not** [`run-smart-regression`](./run-smart-regression.md) (affected-suite selection from plans/diff). Prefer this when the user (or UI copy-prompt) already knows which specs to execute.

**Policy:** Resolve `connect-to-test-env` via `--policy` → `connect-to-test-env.policy.md` → matching frontmatter → fallback in `plans/knowledge/ai-test-instructions.md`. See [`policies-and-traceability.md`](./policies-and-traceability.md). Optional `execute-tests.policy.md` may refine runner flags; it is not required for catalog status.

**P0 — same as all SmartTest runs:** The **process** that executes Playwright/Mobilewright with **`@testchimp/playwright`** must have **`TESTCHIMP_API_KEY`** in its **environment** (not only MCP/IDE). See **`SKILL.md`** Preamble **#4**.

---

## When to use this vs related workflows

| User intent | Where to go |
|-------------|-------------|
| Execute a known folder/file against an env | **This file** (`execute-tests`) |
| Select affected + related specs from plans/diff | [`run-smart-regression.md`](./run-smart-regression.md) |
| Full PR QA loop | [`run-qa.md`](./run-qa.md) |
| Configure CI to run tests | [`configure-ci-test-execution.md`](./configure-ci-test-execution.md) |

---

## Inputs

Parse from the user prompt:

1. **Scope** — SmartTests-relative folder path (e.g. `tests/auth`) or file path (e.g. `tests/checkout/cart.spec.ts`). If omitted, ask which folder/file to execute (do not invent a smart-regression selection).
2. **Environment** — name after `in` (e.g. `QA`, `Staging`). Maps to **`TESTCHIMP_ENV=<env>`** and dotenv **`.env-<env>`** under the SmartTests root (directory containing **`.testchimp-tests`**). Default **`QA`** if the user omitted env and a `.env-QA` exists.

---

## Agent steps

### 1) Connect to the test environment (required)

1. Read the resolved **`connect-to-test-env`** policy (or ai-test-instructions fallback).
2. Set **`TESTCHIMP_ENV`** to the named env; ensure **`.env-<env>`** has **`BASE_URL`** (and other URLs the suite needs).
3. **Reuse a running env:** If the required endpoint from **`.env-<env>`** / policy is **already reachable** (e.g. localhost health check succeeds), **do not** spin up a new environment — connect / export **`BASE_URL`** and proceed. Only provision, restart, or redeploy when the policy requires it **or** there are **new changes that must be deployed** before this run is valid.
4. Follow [`environment-management.md`](./environment-management.md) for local vs EaaS vs Branch Management patterns as the policy dictates.

### 2) Execute the scoped suite

1. **`cd`** to the SmartTests root.
2. Resolve the scope to Playwright/Mobilewright paths per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) (web vs mobile vs multi-platform).
3. Prefer **headless** for this workflow unless the user asks to debug headed.
4. Ensure Preamble **#4** (`TESTCHIMP_API_KEY` on the runner process) before spawn.
5. Execute only the given folder/file scope (e.g. `npx playwright test <path>` or the Mobilewright equivalent for the project type).

### 3) Report and triage

1. Summarize pass/fail for the user (counts, notable failures).
2. For clear test bugs or flakes, fix or hand off to [`fix-test-execution.md`](./fix-test-execution.md) when the user wants deeper repair.
3. Best-effort **`report-agent-action`** with workflow-id **`execute-tests`** and a stable ULID when you mutate specs or product code; close with **`ACTION_COMPLETED`** when done.

---

## Completion gate

- [ ] `connect-to-test-env` followed for the named env (reuse-if-healthy respected)
- [ ] Scoped tests executed from SmartTests root with runner API key present
- [ ] Results reported to the user; blockers called out with next steps

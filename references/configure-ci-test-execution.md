# /testchimp configure execution of tests in CI

**Not a catalog workflow.** Thin playbook for the UI copy-prompt:

`/testchimp configure execution of tests in CI if missing and inform user how to trigger tests on the CI`

Reuse init guidance — do **not** invent a parallel CI story.

---

## What to do

1. **Discover** existing CI (e.g. `.github/workflows/`, other CI configs) for Playwright / Mobilewright / TestChimp runs. Report what you find first.
2. If CI is **missing or incomplete**, follow **Key Area 6 — CI setup** and **Action item H — CI behavior** in [`init-testchimp.md`](./init-testchimp.md):
   - Author or adjust a workflow that **`cd`**s into the **mapped SmartTests folder** (directory with **`.testchimp-tests`**).
   - Pass **`BASE_URL`** (and env strategy) per [`environment-management.md`](./environment-management.md) / project policy.
   - Require **`TESTCHIMP_API_KEY`** (and related reporter env) on the job so `@testchimp/playwright` reports executions.
   - Align with [`importing-existing-tests.md`](./importing-existing-tests.md) when an existing suite already has CI.
3. If CI **already exists** and is correctly wired, say so — do not rewrite unnecessarily.
4. **Inform the user how to trigger** runs on CI (e.g. push/PR, `workflow_dispatch`, branch protection checks) based on what you authored or found.
5. Optionally point at product docs: SmartTests in CI with Playwright runner.

## Out of scope

- Running the suite locally (use [`execute-tests.md`](./execute-tests.md)).
- Full `/testchimp init` unless the user asks to (re)init the whole workspace.

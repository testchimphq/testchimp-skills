# /testchimp configure execution of tests in CI

**Standalone command** (not part of project init). The setup guide suggests it after setup: run the tests on CI and report results to TestChimp. Also used by the UI copy-prompt:

`/testchimp configure execution of tests in CI if missing and inform user how to trigger tests on the CI`

Not a catalog workflow: no plan file. Confirm the workflow file change with the user before writing it.

---

## What to do

1. **Discover** existing CI (e.g. `.github/workflows/`, other CI configs) for Playwright / Mobilewright / TestChimp runs. Report what you find first.
2. **Repository secret (do this with the user first):** CI needs the project API key as a repository secret named **`TESTCHIMP_API_KEY`**.
   - Tell the user where to add it (GitHub: repo **Settings → Secrets and variables → Actions → New repository secret**; other CI: its secret store) and that the value is the project API key from TestChimp (Project Settings → Key management, or the key in the project's MCP config).
   - Never ask for the key in chat and never write it into a file or command. Wait for the user to confirm the secret exists.
3. If CI is **missing or incomplete**, author it:
   - Copy [`../assets/template_smarttests.yml`](../assets/template_smarttests.yml) to **`.github/workflows/smarttests.yml`**. Change `working-directory` / `cache-dependency-path` from `tests` to the **mapped SmartTests folder** (directory with **`.testchimp-tests`**) when it is not `tests`. Do not invent a draft and patch it with `sed`.
   - Use job **`defaults.run.working-directory`** (or a step `working-directory`) — do **not** `cd` into the folder in the `run:` script.
   - Prefer **`git -C <dir>`** over `cd <dir> && git …`.
   - Pass **`BASE_URL`** (and env strategy) per [`environment-management.md`](./environment-management.md) / project policy.
   - Require **`TESTCHIMP_API_KEY`** (and related reporter env) on the job so `@testchimp/playwright` reports executions.
   - Set **`TESTCHIMP_EXECUTION_SOURCE=CI`** on true pipeline / testrunner jobs so batch automations (e.g. `fix-test-execution`) can fire. Do **not** set `CI` from the skill — agent runs use `LOCAL_AGENT` / `CLOUD_AGENT`.
   - Exclude plan-sync PRs titled `TestChimp Platform Sync [Plans]` (the template already does).
   - Align with [`import-existing-tests.md`](./import-existing-tests.md) when an existing suite already has CI (replace vs separate Action).
   - **ChimpHands:** pushing `.github/workflows/*` needs the TestChimp GitHub App **Workflows: Read & write** permission. If the push is rejected for that, tell the user to grant it, accept the install update, run `testchimp chimphands refresh-git-auth` and retry. Do not add `permissions.workflows` to the YAML (invalid key).
4. If CI **already exists** and is correctly wired, say so — do not rewrite unnecessarily.
5. **Inform the user how to trigger** runs on CI (e.g. push/PR, `workflow_dispatch`, branch protection checks) based on what you authored or found. Once a CI run reports, the setup guide's "Set up test execution in CI" card ticks.
6. Suggest a commit / PR on a **`testchimp-`** branch; use `git -C <dir>`.
7. Then do the [hand-back](./onboarding-next-step.md).

## Out of scope

- Running the suite locally (use [`execute-tests.md`](./execute-tests.md)).
- Project init (folder mapping / test env) — that is [`project-init-testchimp.md`](./project-init-testchimp.md).

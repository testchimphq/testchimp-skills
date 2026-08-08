# /testchimp create tests

> **Workflow id:** `create-tests`. **Policy:** `plans/knowledge/policies/create-tests.policy.md` (optional; fallback `ai-test-instructions.md`). Depends on [`connect-to-test-env.md`](./connect-to-test-env.md). **Plan path** (standalone): `knowledge/workflow_plans/create-tests/<workflow_execution_id>.plan.md`. Nested under **run-qa** / **upkeep**: reuse the parent plan and `workflow_execution_id` — do **not** start a second Plan → approve → Execute cycle.

Authors or updates SmartTests (UI and/or API) and related fixtures for a **scope**. Traceability and reporting follow [`policies-and-traceability.md`](./policies-and-traceability.md).

---

## Prompts

```text
/testchimp create tests
/testchimp create tests for plans/stories/checkout
/testchimp create tests for password reset
/testchimp create tests for TestChimp operation id 01HXYZ...
/testchimp create tests for service OpenAPI root services/foo/openapi.yaml
```

Platform Copy Test prompts from the Operations UI use the **`for <operation scope>`** form — treat that as explicit scope for this workflow.

---

## Scope resolution

Use the skill-wide rule ([`policies-and-traceability.md`](./policies-and-traceability.md)#scoping-overarching--all-workflows), then specialize:

1. **Explicit scope** — plans paths, story/scenario ordinals, plain-English focus, **or API operation scope** (see [`api-testing.md`](./api-testing.md) → *API operation coverage scopes*).
2. **Feature / PR branch** — requirements and surface area tied to the branch diff.
3. **Default branch** — since last `create-tests` via `get-last-run-workflow-detail`, or ask the user (non-interactive: last-run / recent commits).
4. **Release** — when the prompt names a release, use that git commit range / release catalog entry.

When nested under run-qa / upkeep, inherit the **parent** scope and plan.

---

## Authoring references

| Scope / surface | Load |
|---|---|
| UI SmartTests | [`write-smarttests.md`](./write-smarttests.md), [`fixture-usage.md`](./fixture-usage.md), [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) |
| Mobile UI | [`mobilewright-smarttests.md`](./mobilewright-smarttests.md) |
| API tests / **API operation coverage scopes** | [`api-testing.md`](./api-testing.md) (coverage strategy: update existing UI or API tests; dedicated `api/` specs are one option) |
| Seeds / probes | [`seeding-endpoints.md`](./seeding-endpoints.md) |
| Environment | [`connect-to-test-env.md`](./connect-to-test-env.md) |

For Arrange → Act → Assert planning and Execute batching when running as part of run-qa, reuse the Execute guidance in [`run-qa.md`](./run-qa.md) without re-running Analyze/Plan.

---

## `@testchimp/playwright` upgrade (autonomous)

**Why:** Config loads `@testchimp/playwright/reporter` **by package name**. Client CI installs whatever the **lockfile** pins. New npm releases do **not** roll out until something bumps the dependency. **create-tests**, **run-qa**, and **upkeep** own that bump so upgrades stay autonomous.

**When:** First concrete Execute step (before authoring or running SmartTests), once per `workflow_execution_id`. Nested under run-qa / upkeep: skip if the parent already completed this step for the same execution id.

**Steps (blocking before authoring):**

1. Resolve the **install root** (walk up from SmartTests root to the `package.json` that declares `@playwright/test` / `@testchimp/playwright`) — same as **SKILL.md** Preamble **#6** / **#8**.
2. `npm view @testchimp/playwright version` → registry **latest**.
3. `npm ls @testchimp/playwright --prefix <install-root>` (or lockfile) → **installed**.
4. If installed **&lt;** latest: at the install root run **`npm install @testchimp/playwright@latest`** (prefer this over bare `npm update`, which only moves within an existing semver range). Include **`package.json` + lockfile** in the workflow’s commits / PR.
5. If already on latest, or parent already bumped: mark **done** with the version string; do not reinstall.
6. If npm is unreachable: note on the plan, continue on the lockfile version, tell the user to confirm when online.
7. Do **not** edit reporter config solely for a version bump unless a release note requires it.

Also listed as **SKILL.md** Preamble check **#8**.

---

## Execute (standalone or nested)

After Plan approval (standalone) or when the parent hands off (nested):

1. **[`@testchimp/playwright` upgrade](#testchimpplaywright-upgrade-autonomous)** — complete before any new/changed specs or runner invocations.
2. **[`connect-to-test-env.md`](./connect-to-test-env.md)** when the parent has not already brought the env up.
3. **Filter by verification strategy (required before authoring):** After the in-scope scenario ordinals are known (from coverage, plans, or the approved plan), call **`get-spec-lifecycle-details --scenario-ids …`** (CLI ≥ **0.1.30** / MCP `get-spec-lifecycle-details`) in one batch. For each scenario, read `lifecycleFields.verification_strategy`. **Skip** scenarios where the value is **`manual`**. Missing / empty → treat as **`auto`**. Only author SmartTests for **`auto`** scenarios. Note skipped manual scenarios on the plan. Do **not** infer this from plan markdown frontmatter — it is platform lifecycle only.
4. Author / update SmartTests and fixtures per [Authoring references](#authoring-references) and the approved plan (automated scenarios only).
5. Run and triage with the real runner; report workflow completion when standalone.

---

## API operation scopes (summary)

When the prompt is `/testchimp create tests for …` with an **API operation** identity (TestChimp operation id, OpenAPI root, method+path, and optional field/response-code cover):

1. **Immediately** load [`api-testing.md`](./api-testing.md) → *API operation coverage scopes* (and *Prompt → CLI mapping*).
2. Treat any `Hint: …` line after the prompt as human-readable context only — scope identity is the `for …` clause.
3. Fetch coverage with CLI/MCP: `list-api-operation-services`, `list-api-operations`, `get-api-operation-detail` (CLI ≥ **0.1.28**). Do not invent coverage without those tools.
4. Close gaps by **updating existing tests** and/or **authoring new ones** (UI e2e that hits the API counts). Prefer extending an existing journey; a dedicated API test is not required per gap. Operation-level covering tests do **not** imply field/response-code coverage — use detail for those gaps.
5. **Standalone Plan** for API scopes: list the target operation(s)/fields, chosen vehicle tests (update vs new, UI vs `api/`), and Arrange/Act/Assert for each new or changed test — then upsert + approve as usual.

---

## Standalone vs nested

- **Standalone:** Plan → `upsert-plans-support-file` → user approval (unless non-interactive) → **`@testchimp/playwright` upgrade** → connect-to-test-env → Execute authoring → report workflow completion.
- **Nested under run-qa / upkeep:** Execute authorship only for the parent-approved items; same `workflow_execution_id`. Still honor the upgrade step unless the parent already completed it for this execution.

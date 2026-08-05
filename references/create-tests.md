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

## API operation scopes (summary)

When the prompt is `/testchimp create tests for …` with an **API operation** identity (TestChimp operation id, OpenAPI root, method+path, and optional field/response-code cover):

1. **Immediately** load [`api-testing.md`](./api-testing.md) → *API operation coverage scopes* (and *Prompt → CLI mapping*).
2. Treat any `Hint: …` line after the prompt as human-readable context only — scope identity is the `for …` clause.
3. Fetch coverage with CLI/MCP: `list-api-operation-services`, `list-api-operations`, `get-api-operation-detail` (CLI ≥ **0.1.28**). Do not invent coverage without those tools.
4. Close gaps by **updating existing tests** and/or **authoring new ones** (UI e2e that hits the API counts). Prefer extending an existing journey; a dedicated API test is not required per gap. Operation-level covering tests do **not** imply field/response-code coverage — use detail for those gaps.
5. **Standalone Plan** for API scopes: list the target operation(s)/fields, chosen vehicle tests (update vs new, UI vs `api/`), and Arrange/Act/Assert for each new or changed test — then upsert + approve as usual.

---

## Standalone vs nested

- **Standalone:** Plan → `upsert-plans-support-file` → user approval (unless non-interactive) → connect-to-test-env → Execute authoring → report workflow completion.
- **Nested under run-qa / upkeep:** Execute authorship only for the parent-approved items; same `workflow_execution_id`.

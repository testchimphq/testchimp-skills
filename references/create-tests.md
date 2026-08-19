# /testchimp create tests

> **Workflow id:** `create-tests`. **Policy:** `plans/knowledge/policies/create-tests.policy.md` (optional; fallback `ai-test-instructions.md`). Depends on [`connect-to-test-env.md`](./connect-to-test-env.md). **Plan path** (standalone): `knowledge/workflow_plans/create-tests/<workflow_execution_id>.plan.md`. Nested under **run-qa** / **upkeep**: reuse the parent plan and `workflow_execution_id` — do **not** start a second Plan → approve → Execute cycle.

Authors or updates SmartTests (UI and/or API) and related fixtures for a **scope**. Traceability and reporting follow [`policies-and-traceability.md`](./policies-and-traceability.md).

**Do not call `mark-tests-for-review`.** That tool is only for [`fix-test-execution.md`](./fix-test-execution.md) after patches to **existing** failing tests. New tests authored here do not need it.

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
| Suite tags / goals | Project **`plans/knowledge/policies/global.policy.md`** (seed: [`assets/policies/global.policy.md`](../assets/policies/global.policy.md); or **`get-policy --policy-file-name global.policy.md`**) — coverage target, prioritization, **`tags:`** |

For Arrange → Act → Assert planning and Execute batching when running as part of run-qa, reuse the Execute guidance in [`run-qa.md`](./run-qa.md) without re-running Analyze/Plan.

### Global policy tags (blocking before authoring)

Before writing or updating any SmartTest:

1. Read **`plans/knowledge/policies/global.policy.md`** → **`## Test suite management` → `tags:`** (CLI: **`get-policy --policy-file-name global.policy.md`**). If `tags:` is missing, treat legacy **`annotations:`** `values` as tags.
2. For each tag, use its **`instructions`** to decide whether to apply it. A test may receive multiple tags.
3. Put `tag: '@<value>'` (or `tag: ['@a', '@b']`) on every new/changed test. Keep scenario links as `{ type: 'scenario', description: '#TS-…' }` on `annotation` only.
4. Do not invent tag values outside the policy. Never emit `{ type: 'group', description: '…' }`. If `tags:` is empty (and no legacy `annotations:`), suite tags are **`N/A`**.

Canonical rules: [`write-smarttests.md`](./write-smarttests.md) §6b · [`policies-and-traceability.md`](./policies-and-traceability.md)#global-policy--suite-tags-required-when-authoring-tests.

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
4. Author / update SmartTests and fixtures per [Authoring references](#authoring-references) and the approved plan (automated scenarios only) — include **suite tags** from [Global policy tags](#global-policy-tags-blocking-before-authoring).
5. Run and triage with the real runner until green (or explicit blockers). On the **final green Validate** of new/changed specs: pin `TESTCHIMP_BATCH_INVOCATION_ID`, capture `[TestChimp] Batch invocation view:` from that spawn, then **`unset TESTCHIMP_BATCH_INVOCATION_ID`**. Upsert the PR/MR comment per [`policies-and-traceability.md`](./policies-and-traceability.md)#authored-tests-pr-comment (after the PR exists; soft-fail if no PR/URL).
6. **Write `plans/smart-smoke/<branch>/related-tests.json` (BLOCKING)** — see [Related-tests.json (required)](#related-testsjson-required). Do **not** close create-tests (standalone or nested) without this file for the current branch.
7. Report workflow completion when standalone.

---

## Related-tests.json (required)

**Blocking** after authoring (standalone **and** nested under run-qa / upkeep). CI smart-smoke and `/testchimp run smart smoke` load this file for the branch — if it is missing, related selection is empty.

**Path:** `plans/smart-smoke/<branch_name>/related-tests.json`  
(`<branch_name>` = current git branch; keep `/` segments as nested dirs.)

**Must include TestLocators for:**

1. **Every new or materially changed SmartTest** authored in this run (always).
2. **Impact-related existing tests** — from PR/scope analysis: scenarios sharing the same feature area / journey / APIs as the change, then specs linked via `annotation: { type: 'scenario', description: '#TS-…' }` (see [`run-smart-smoke.md`](./run-smart-smoke.md) → *Analyze impact* / *Write `related-tests.json`*).

**Format:** JSON array of TestLocators, or `{ "relatedTests": [ … ] }` / `{ "related_tests": [ … ] }`.  
`folderPath` is relative to the SmartTests root and **must not** prefix `tests/` (e.g. `["auth"]`, not `["tests","auth"]`).

**Also:** set / document **`TESTCHIMP_BRANCH_NAME=<branch>`** so runners load this path. Do **not** author `.testchimp-smart-smoke-selection.json` (plugin temp sidecar only).

**Nested under run-qa:** writing this file here does **not** replace run-qa **Phase 5** (smoke execute + triage). Phase 5 may **refine** the same file, then run with `TESTCHIMP_SMART_SMOKE_ENABLED`. Record the path on the plan checklist.

**Completion checklist:**

- [ ] `plans/smart-smoke/<branch>/related-tests.json` exists and lists new/changed + impact-related locators
- [ ] Path recorded on the workflow plan
- [ ] File is included in the branch commit / PR when the rest of the authorship is

---

## API operation scopes (summary)

When the prompt is `/testchimp create tests for …` with an **API operation** identity (TestChimp operation id, OpenAPI root, method+path, and optional field/response-code cover) — including Operations UI **Copy Test** prompts:

1. **Immediately** load [`api-testing.md`](./api-testing.md) → *API operation coverage scopes* (and *Prompt → CLI mapping*).
2. Treat any `Hint: …` line after the prompt as human-readable context only — scope identity is the `for …` clause.
3. Fetch coverage with CLI/MCP: `list-api-operation-services`, `list-api-operations`, `get-api-operation-detail` (CLI ≥ **0.1.28**). Do not invent coverage without those tools.
4. **Check existing plan items first (required):** search mapped `plans/`, `get-test-scenarios` / `get-requirement-coverage` / semantic-nearby if useful for a scenario (or story) that already matches the signal (same journey, operation, field, or response path). Prefer **linking an existing scenario** when one fits.
5. Only when **no suitable scenario exists**, propose new scenario(s) — and a parent **story** only if no relevant story exists (link an existing story when one fits). Record titles, rationale, linked signal, and that the existence check found none.
6. **Explicit user approval** (Plan → approve) before creating any new story/scenario. Do not create plan entities on a silent path.
7. Close gaps by **updating existing tests** and/or **authoring new ones** (UI e2e that hits the API counts). Prefer extending an existing journey; a dedicated API test is not required per gap. Create **only approved missing** plan items as lifecycle **`ready`** + verification **`auto`**, then author SmartTests with scenario `annotation` links. No phantom ids; never duplicate a scenario that already covers the gap. Operation-level covering tests do **not** imply field/response-code coverage — use detail for those gaps.
8. **Suite size soft hint:** call `get-suite-execution-stats` vs `global.policy.md` caps; if over or within ~10% of a non-zero cap, inform the user (not a hard blocker).
9. **Standalone Plan** for API scopes: list the target operation(s)/fields, existence-check outcome, chosen vehicle tests (update vs new, UI vs `api/`), and Arrange/Act/Assert for each new or changed test — then upsert + approve as usual.

---

## Standalone vs nested

- **Standalone:** Plan → `upsert-plans-support-file` → user approval (unless non-interactive) → **`@testchimp/playwright` upgrade** → connect-to-test-env → Execute authoring → **write `plans/smart-smoke/<branch>/related-tests.json`** → report workflow completion.
- **Nested under run-qa / upkeep:** Execute authorship only for the parent-approved items; same `workflow_execution_id`. Still honor the upgrade step unless the parent already completed it for this execution. **Still write/update `related-tests.json`** before handing back to the parent (run-qa Phase 5 may refine + execute smoke).

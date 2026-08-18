# /testchimp run smart smoke

**Workflow id:** `run-smart-smoke`

**Canonical prompt:** `/testchimp run smart smoke`

**Legacy synonym (one release):** `/testchimp run smart regression` → same workflow. Prefer the smart-smoke prompt and docs; keep accepting the old phrasing so existing policies/prompts do not break.

**Depends on:** [`connect-to-test-env`](./connect-to-test-env.md) (bring up / connect per policy before running tests).

**Policy:** Resolve via `--policy` → `run-smart-smoke.policy.md` → any matching frontmatter `workflow-id` → fallback guidance in `plans/knowledge/ai-test-instructions.md`. See [`policies-and-traceability.md`](./policies-and-traceability.md). Legacy `run-smart-regression.policy.md` may still resolve for one release — migrate to `run-smart-smoke.policy.md`.

**Plan → approve → execute:** When this workflow runs **standalone**, write `knowledge/workflow_plans/run-smart-smoke/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). When nested under **`run-qa`**, Smart smoke is **Phase 5 guidance during Execute** of the composite (after Validate); reuse the parent plan — do not invent a separate approval gate.

**Traceability:** On mutating fixes (update existing specs, fix product code because of a failure), call **`report-agent-action`** best-effort with the stable workflow-execution ULID (from the plan file when nested under run-qa). **Standalone:** before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `run-smart-smoke`). Nested under run-qa: parent closes.

This playbook is the full Smart smoke guidance. The same logic lives inline under **Phase 5** in [`run-qa.md`](./run-qa.md) so behavior is unchanged if an agent only reads that file.

---

## Scoping rules

Follow the **overarching** scoping rule in [`policies-and-traceability.md`](./policies-and-traceability.md#scoping-overarching--all-workflows) (explicit → feature branch → default/last-run; ask for consent when last-run is missing). Specialized for this workflow:

1. **Explicit scope** — user-provided plans folder path(s), scenario ids, or plain-English focus → limit affected scenarios and linked tests to that focus.
2. **Feature branch** (no explicit scope) — likely affected scenarios from **PR/branch diff** + related `plans/stories/` / `plans/scenarios/` (same as identification below).
3. **Default / main branch** (no explicit scope) — **`get-last-run-workflow-detail`** with **`workflow-id: run-smart-smoke`** first (or parent `run-qa` when nested). **One-release fallback:** if no last run for `run-smart-smoke`, call again with **`workflow-id: run-smart-regression`**. Optional `branch-name` / `user-id` on both. If last run is missing or too far back, ask the user for since-when (recent commits vs broader).
4. **Nested under run-qa** — use the branch plan **§6 Smart smoke scope** and the identification steps below (PR + plans); still bound by the composite’s single chosen scope.

---

## Goal

After **new/changed** tests are **authored and validated**, analyze **impact** of the change, write **related TestLocators**, collaborate on a **smoke config** (related-tests-only vs budgeted), enable **`@testchimp/playwright` smart-smoke** for the run, execute with the **same** `npx playwright test` command (no bin/CLI smart-smoke flags), and **rectify** failures (test vs product — same triage as `/testchimp test` Validate).

### When to run

**Always** after new/changed tests are green in the enclosing flow (e.g. after **Phase 4** in run-qa), unless the plan records **`N/A`** with rationale (e.g. greenfield repo with no existing scenarios, docs-only PR). **Do not** skip silently when existing plans and linked tests exist.

Standalone: run after connect-to-test-env; skip authoring unless the user asked to fix only.

---

## 1) Analyze impact → related tests

Using **scope** (above), **PR/branch diff** when on a feature branch, plan markdown under **`<MAPPED_PLANS_ROOT>`**, and (when nested) **branch plan §6**:

1. Read relevant **`plans/stories/`** and **`plans/scenarios/`** (folder paths give feature context; scenario **`story:`** frontmatter links to parent stories—see [`author-plans.md`](./author-plans.md)).
2. Select scenarios **likely affected** when they share:
   - The same **feature area**, screens, routes, or APIs touched by the change
   - The same **user journey** or business rules changed in product code
   - **Sibling** scenarios under the same story folder when the story’s scope overlaps the change
3. Prefer keeping scenarios covered by **new** tests in the related set when they still add confidence; always include locators for those new tests themselves (next section).
4. Optionally corroborate with MCP/CLI **`get-requirement-coverage`** scoped to affected **`plans/...`** folders (omit **`--branch-name`** unless you need one branch only).
5. Record: **`#TS-…`** id, title, **why** it is in the related set (on the branch/evolve plan or a short standalone plan markdown).

**Never invent** `#TS-…` ids—only ids present in plan files or returned by the platform.

### Resolve linked SmartTests → TestLocators

From the SmartTests root (directory containing **`.testchimp-tests`**):

1. Search **`*.spec.{js,ts}`** for each affected scenario id using **both**:
   - **Canonical:** `type: 'scenario'` (or `type: "scenario"`) with `description: '#TS-<n>'` (or `"#TS-<n>"`) in the test’s `annotation` array
   - **Deprecated (still linked):** `// @Scenario: #TS-<n>` comments  
   A spec may cover **multiple** scenarios.
2. For each matching **test** (not only the file), build a **TestLocator** relative to the SmartTests / mapped tests root:
   - **`folderPath`** / **`folder_path`**: path segments **under the mapped tests root** — **do not** prefix `tests/` (e.g. `["auth"]` or `["checkout","cart"]`, never `["tests","auth"]`).
   - **`fileName`** / **`file_name`**: spec basename (e.g. `login.spec.ts`)
   - **`testSuite`** / **`test_suite`**: nested `test.describe` titles (array; empty if none)
   - **`testName`** / **`test_name`**: the test title
3. **Also include** every **new or materially changed** SmartTest from this run / PR (always).
4. Deduplicate by locator identity; record the list under completion notes on the plan.

### Write `related-tests.json` (BLOCKING)

**Required** for **`run-smart-smoke`**, **run-qa Phase 5**, and **create-tests** (see [`create-tests.md`](./create-tests.md)#related-testsjson-required). Do not run smart smoke until this file exists for the branch (unless plan records **`N/A`** with rationale).

Write (create parents as needed):

```text
plans/smart-smoke/<branch>/related-tests.json
```

- **`<branch>`** = current git branch name. Keep path segments literally when the branch contains `/` (nested dirs).
- File body: either a **JSON array** of TestLocators, or `{ "relatedTests": [ … ] }` / `{ "related_tests": [ … ] }`.

Example:

```json
{
  "relatedTests": [
    {
      "folderPath": ["auth"],
      "fileName": "login.spec.ts",
      "testSuite": [],
      "testName": "user can log in"
    }
  ]
}
```

---

## Related perf selection (run-qa / create-perf-tests)

When the SmartTests root has **`k6/journeys`**, this workflow (and **run-qa Phase 5**, **create-perf-tests**) also writes:

```text
plans/smart-smoke/<branch>/related-perf-tests.json
```

Build `perf-changes.json` (`branch`, `scenarios`, `operations`, `paths`) from the same impact analysis as related SmartTests, then from the SmartTests root:

```bash
k6/scripts/select-related.sh <MAPPED_PLANS_ROOT>/smart-smoke/<branch>/perf-changes.json
```

**Do not** execute `k6/scripts/run.sh` here. CI or `/testchimp run-perf-tests` later uses `k6/scripts/run.sh --impacted`. Nested **create-perf-tests** under run-qa is **opt-in (default No)**. Details: [`run-qa.md`](./run-qa.md)#1b-write-related-perf-testsjson-when-k6journeys-exists-blocking.

---

## 2) Collaborate on smoke config

Before Execute, agree with the user (or record on the plan in non-interactive mode) which mode to use:

| Mode | When | Effect |
|------|------|--------|
| **Related-tests-only** (preferred **safe default**) | Tight PR confidence; avoid expanding the suite | Plugin runs **only** locators from `related-tests.json` (skips selection API). Equivalent to **`TESTCHIMP_SMART_SMOKE_RELATED_TESTS_ONLY=true`** (or `1`). |
| **Budgeted smoke** | Broader ROI within a size cap | Plugin selects **related ∪ tagged** (and future server ranking) within budget. |

**Prefer documenting related-tests-only as the safe default** on the branch/standalone plan unless the user asks for budgeted smoke.

### Enable + overrides (env — never CLI flags)

Smart smoke is **opt-in per run** via environment. **Do not** auto-enable in `playwright.config`. There are **no** Playwright bin/CLI flags for smart smoke — use the same `npx playwright test` as always.

**Required to enable:**

```bash
export TESTCHIMP_SMART_SMOKE_ENABLED=true   # or 1
```

**Optional overrides** (env wins over `use.testchimpSmartSmoke` when set):

| Env | Purpose |
|-----|---------|
| `TESTCHIMP_SMART_SMOKE_RELATED_TESTS_ONLY` | `true` / `1` → related-tests-only |
| `TESTCHIMP_SMART_SMOKE_MAX_TIME_BUDGET_MINS` | Time packing (minutes) |
| `TESTCHIMP_SMART_SMOKE_MAX_TESTS` | Top N tests |
| `TESTCHIMP_SMART_SMOKE_SUITE_PERCENTAGE` | Top N% of suite |
| `TESTCHIMP_SMART_SMOKE_INCLUDE_TAGS` | Comma-separated tags (e.g. `smoke` or `@smoke`) |

If budgeted mode is on and **no** size constraint is set, `@testchimp/playwright` defaults to **suitePercentage = 20** (with a log warning).

Also set **`TESTCHIMP_BRANCH_NAME`** to the current branch when not already injected by CI so the reporter can load `plans/smart-smoke/<branch>/related-tests.json`.

### Project defaults (`playwright.config`)

Optional **defaults only** under `use` (templates seed these — **never** set `enabled` / related-only here as always-on):

```js
use: {
  // …
  testchimpSmartSmoke: {
    suitePercentage: 20,
    includeTags: ['smoke'],
  },
},
```

Enable a given run with **`TESTCHIMP_SMART_SMOKE_ENABLED`**, not by flipping config.

### Tags

- Suite membership for budgeted smoke uses Playwright **`tag: '@smoke'`** (and other values from **`global.policy.md` → `tags:`**).
- **Do not** use `{ type: 'group', description: 'smoke' }` annotations — Playwright CLI and smart-smoke tag matching use **tags**, not group annotations.
- See [`global.policy.md`](../assets/policies/global.policy.md) and [`write-smarttests.md`](./write-smarttests.md) §6b.

---

## 3) Execute the smoke suite

- Ensure **connect-to-test-env** guidance was followed (`BASE_URL` / health).
- **`cd`** SmartTests root; export **Preamble #4** env (`TESTCHIMP_API_KEY`, `TESTCHIMP_EXECUTION_SOURCE=LOCAL_AGENT|CLOUD_AGENT`, backend/ingress when configured) **and** smart-smoke env from §2.
- Run the **same** runner as usual — e.g. `npx playwright test` (plus any existing `--project` / path args for the scaffold). **No** `--smart-smoke` or other smart-smoke CLI flags.
- Prefer **headless** for smoke unless debugging (headed default remains for **authoring** per `SKILL.md`).
- Non-selected tests are **skipped** with skip-reason **`smart-smoke`** (distinct from explicit `test.skip`).
- Re-run after fixes until **pass** or each failure is **explicitly blocked** with next steps. Keep smart-smoke env on re-runs so selection stays consistent.

---

## 4) Rectify failures

Apply the same triage as [`run-qa.md`](./run-qa.md) → Validation failure triage:

- **Product regression:** fix application code; keep tests aligned with intended behavior.
- **Test outdated:** update the **existing** spec (fixtures, steps, assertions, probes)—document material changes for **ExploreChimp** handoff when nested under run-qa.

If a failure reveals a **missing** scenario for new behavior, add it to the plan backlog (create in platform during Execute rules if not already done)—do not invent ids in annotations.

**Best-effort:** `report-agent-action` for each material fix (`action_type` created/updated; SmartTests via `test` TestLocator; scenarios/stories via ordinal `entityIdentity`).

**Standalone only:** after the checklist, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — **`ACTION_COMPLETED`** with `WORKFLOW` + `run-smart-smoke` (nested under run-qa: parent closes).

---

## Checklist

- [ ] Scope resolved (explicit / feature branch / default+last-run / nested §6).
- [ ] Last-run lookup used **`run-smart-smoke`**, with one fallback to **`run-smart-regression`** when needed.
- [ ] Affected scenarios identified from **plans + change set** (listed on plan).
- [ ] Linked tests resolved via scenario **`annotation`** / deprecated `// @Scenario:` → TestLocators (no `tests/` prefix on `folderPath`).
- [ ] **`plans/smart-smoke/<branch>/related-tests.json`** written.
- [ ] **`plans/smart-smoke/<branch>/related-perf-tests.json`** written when `k6/journeys` exists (or **`N/A`**); k6 not executed.
- [ ] Smoke mode agreed: **related-tests-only** (safe default) or budgeted; env set (`TESTCHIMP_SMART_SMOKE_ENABLED` + overrides).
- [ ] Suite executed with real runner (**`TESTCHIMP_API_KEY`** on process) via normal `npx playwright test`.
- [ ] Failures triaged; tests and/or product updated; suite re-run to green or explicit blockers recorded.
- [ ] When nested under run-qa with ExploreChimp **`yes`**: plan ExploreChimp targets updated to include **smoke-touched** UI specs.
- [ ] Standalone: **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** done (`ACTION_COMPLETED` / `ACTION_FAILED` for `WORKFLOW` + `run-smart-smoke`).

### Completion gate

- [ ] Affected scenarios + related TestLocators / `related-tests.json` documented (or **`N/A`** + rationale).
- [ ] Smoke mode + run results recorded (pass / fail / blocked).
- [ ] Any **materially changed** existing specs noted for ExploreChimp scope when applicable.
- [ ] Standalone: workflow execution closed on the platform.

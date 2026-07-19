# /testchimp run smart regression

**Workflow id:** `run-smart-regression`

**Depends on:** [`connect-to-test-env`](./connect-to-test-env.md) (bring up / connect per policy before running tests).

**Policy:** Resolve via `--policy` → `run-smart-regression.policy.md` → any matching frontmatter `workflow-id` → fallback guidance in `plans/knowledge/ai-test-instructions.md`. See [`policies-and-traceability.md`](./policies-and-traceability.md).

**Plan → approve → execute:** When this workflow runs **standalone**, follow Plan → user approval → Execute. When nested under **`run-qa`** (`/testchimp run QA` / `/testchimp test`), Smart regression is **Phase 5 guidance during Execute** of the composite (after Validate); do not invent a separate approval gate beyond the branch plan’s existing Plan approval.

**Traceability:** On mutating fixes (update existing specs, fix product code because of a regression), call **`report-agent-action`** best-effort with the stable workflow-execution ULID (from the plan file when nested under run-qa).

This playbook is the full Smart regression guidance. The same proven logic lives inline under **Phase 5** in [`run-qa.md`](./run-qa.md) so behavior is unchanged if an agent only reads that file.

---

## Scoping rules

Follow the **overarching** scoping rule in [`policies-and-traceability.md`](./policies-and-traceability.md#scoping-overarching--all-workflows) (explicit → feature branch → default/last-run; ask for consent when last-run is missing). Specialized for this workflow:

1. **Explicit scope** — user-provided plans folder path(s), scenario ids, or plain-English focus → limit affected scenarios and linked specs to that focus.
2. **Feature branch** (no explicit scope) — likely affected scenarios from **PR/branch diff** + related `plans/stories/` / `plans/scenarios/` (same as Phase 5 identification below).
3. **Default / main branch** (no explicit scope) — **`get-last-run-workflow-detail`** with `workflow-id: run-smart-regression` (or parent `run-qa` when nested) and optional `branch-name` / `user-id`. If last run is missing or too far back, ask the user for since-when (recent commits vs broader).
4. **Nested under run-qa** — use the branch plan **§6 Smart regression scope** and the identification steps below (PR + plans); still bound by the composite’s single chosen scope.

---

## Goal

After **new/changed** tests are **authored and validated**, find **existing** coverage that the change may have broken, **run** those SmartTests/API tests, and **rectify** failures (test vs product — same triage as `/testchimp test` Validate).

This workflow is **codebase-driven** (no new platform APIs required beyond coverage helpers): scenarios and stories live under the mapped **`plans/`** tree; linkage to specs is via **`// @Scenario: #TS-<n>`** comments in the SmartTests root.

### When to run

**Always** after new/changed tests are green in the enclosing flow (e.g. after **Phase 4** in run-qa), unless the plan records **`N/A`** with rationale (e.g. greenfield repo with no existing scenarios, docs-only PR). **Do not** skip silently when existing plans and linked tests exist.

Standalone: run after connect-to-test-env; skip authoring unless the user asked to fix only.

---

## 1) Identify likely affected scenarios

Using **scope** (above), **PR/branch diff** when on a feature branch, plan markdown under **`<MAPPED_PLANS_ROOT>`**, and (when nested) **branch plan §6**:

1. Read relevant **`plans/stories/`** and **`plans/scenarios/`** (folder paths give feature context; scenario **`story:`** frontmatter links to parent stories—see [`author-plans.md`](./author-plans.md)).
2. Select scenarios **likely affected** when they share:
   - The same **feature area**, screens, routes, or APIs touched by the change
   - The same **user journey** or business rules changed in product code
   - **Sibling** scenarios under the same story folder when the story’s scope overlaps the change
3. **Exclude** scenarios already covered by **new** tests authored in this run (unless you still want a regression run for confidence).
4. Optionally corroborate with MCP/CLI **`get-requirement-coverage`** scoped to affected **`plans/...`** folders (omit **`--branch-name`** unless you need one branch only).
5. Record: **`#TS-…`** id, title, **why** it is in the regression set (on the branch/evolve plan or a short standalone plan markdown).

**Never invent** `#TS-…` ids—only ids present in plan files or returned by the platform.

---

## 2) Resolve linked SmartTests

From the SmartTests root (directory containing **`.testchimp-tests`**):

1. Search **`*.spec.{js,ts}`** for `// @Scenario: #TS-<n>` matching each affected scenario id (a spec may cover **multiple** scenarios).
2. Build a **deduplicated** list of spec files (and API tests if they use the same comment convention).
3. Record the list under completion notes on the plan.

---

## 3) Run the regression suite

- Ensure **connect-to-test-env** guidance was followed (`BASE_URL` / health).
- **`cd`** SmartTests root; run per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — **Preamble #4** required.
- Prefer **headless** for regression unless debugging (headed default remains for **authoring** per `SKILL.md`).
- Re-run after fixes until **pass** or each failure is **explicitly blocked** with next steps.

---

## 4) Rectify failures

Apply the same triage as [`run-qa.md`](./run-qa.md) → Validation failure triage:

- **Product regression:** fix application code; keep tests aligned with intended behavior.
- **Test outdated:** update the **existing** spec (fixtures, steps, assertions, probes)—document material changes for **ExploreChimp** handoff when nested under run-qa.

If a failure reveals a **missing** scenario for new behavior, add it to the plan backlog (create in platform during Execute rules if not already done)—do not invent ids in comments.

**Best-effort:** `report-agent-action` for each material fix (`action_type` created/updated; SmartTests via `test` TestLocator; scenarios/stories via ordinal `entityIdentity`).

---

## Checklist

- [ ] Scope resolved (explicit / feature branch / default+last-run / nested §6).
- [ ] Affected scenarios identified from **plans + change set** (listed on plan).
- [ ] Linked specs resolved via **`// @Scenario:`** grep (listed on plan).
- [ ] Regression suite executed with real runner (**`TESTCHIMP_API_KEY`** on process).
- [ ] Failures triaged; tests and/or product updated; suite re-run to green or explicit blockers recorded.
- [ ] When nested under run-qa with ExploreChimp **`yes`**: plan ExploreChimp targets updated to include **regression-touched** UI specs.

### Completion gate

- [ ] Affected scenarios + linked spec paths documented (or **`N/A`** + rationale).
- [ ] Regression run results recorded (pass / fail / blocked).
- [ ] Any **materially changed** existing specs noted for ExploreChimp scope when applicable.

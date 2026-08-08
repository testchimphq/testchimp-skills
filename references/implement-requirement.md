# `/testchimp implement` — implement a requirement

**Workflow id:** `implement`  
**Canonical prompts:**
- `/testchimp implement <story id / scenario id>`
- `/testchimp implement <path-to-plan.md>` (or “implement this plan” with a plan file path / attachment)

**Policy:** `plans/knowledge/policies/implement.policy.md` (or `--policy` / matching frontmatter; fallback `ai-test-instructions.md`). Default seed: [`assets/policies/implement.policy.md`](../assets/policies/implement.policy.md).

Implement product behaviour for a **user story** or **scenario** using the repo’s implementation conventions and the project **implement** policy. This is a **Development** workflow (not Run QA): ship code that satisfies the requirement, then mark implementation and close the workflow execution.

**Skill role (critical):** This workflow **wraps** normal product implementation planning with policy, ULID plan persistence, approval, and `TASK_ISSUE` traceability. It must **not** reduce planning quality vs unconstrained implementation planning (e.g. Cursor Plan mode / “implement this story” without TestChimp). Do **not** let workflow ceremony, gate tables, or task-title lists substitute for a real design.

Users often refine a story into a detailed plan first, then ask to implement that plan. Prefer the **plan file** as Execute scope when given; resolve the parent **story** (and any **scenario**) from the plan for platform load + task linking.

> **Traceability:** Persist a **ULID** `workflow_execution_id` before Execute; write the plan at **`knowledge/workflow_plans/implement/<workflow_execution_id>.plan.md`**, call **`upsert-plans-support-file`** (blocking), then seek **explicit user approval** (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). Report mutating actions with **`report-agent-action`**. Before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (reconcile ledger → emit missing reports → `ACTION_COMPLETED` with `WORKFLOW` + `implement`). Vocabulary: [`policies-and-traceability.md`](./policies-and-traceability.md).

## Inputs

Resolve **one** primary input (priority order when several are present: **plan file** → explicit story/scenario id in the prompt):

1. **Plan file** — path under the repo or mapped plans root (e.g. `plans/knowledge/implement_plans/….md`, a Cursor plan, or any `.md` the user points at). Read the file as the finetuned implementation plan.
2. **Story** — `US-42`, `42`, `#US-42`, or `/testchimp implement story 42`
3. **Scenario** — `TS-107`, `107`, `#TS-107`, or `/testchimp implement scenario 107`

### Resolving story / scenario ordinals

Parse to a **numeric ordinal** for MCP/CLI and for `report-agent-action` (`entity_identity` must be the ordinal only — no `US-` / `TS-` prefix).

**From a plan file** — read YAML frontmatter first (preferred), then a light body fallback:

| Source | Keys / patterns | Result |
|--------|-----------------|--------|
| Frontmatter | `story: US-42`, `story: 42`, `story: #US-42` | Story ordinal **42** |
| Frontmatter | `userStoryOrdinalId: 42` / `user_story_ordinal_id: 42` | Story ordinal **42** |
| Frontmatter | `scenario: TS-107`, `scenario: 107`, `scenarioOrdinalId: 107` | Scenario ordinal **107** (then load parent story) |
| Body (fallback only) | First clear `US-<n>` / `#US-<n>` mention near the top | Story ordinal **n** |

If the plan has a **scenario** but no story, load the scenario via **`get-test-scenarios`** and use its parent story ordinal for linking. If **no story and no scenario id** can be resolved, still implement from the plan, but **omit** story/scenario `linkTargets` on task issues (and note that in the checklist). **Ask the user** only when the plan is ambiguous (multiple conflicting story ids) or empty of both scope and tasks.

If the user names a scenario (without a plan file), treat that scenario as the primary target and still load its parent story. If they name a story, implement the story **and** its related scenarios (see Analyze).

## Phase overview

**Analyze → Plan → Execute → Report** (strict). Do not mutate product code until the user approves the Plan (when the input **is** an already-finetuned plan file and the user asked to implement it, treat that as Plan approval for the file’s content—still mint `workflow_execution_id` and confirm any agent-added deltas). Mint `workflow_execution_id` during Plan and reuse it for every `report-agent-action`.

**Two-pass Plan (design-first, wrap-second):**
1. Author (or adopt) the **Product plan** — architecture, files, schema/DDL, API contracts, UI structure, committed decisions — at unconstrained depth.
2. Then add the **Workflow envelope** — frontmatter (ULID), derived task titles for `create-issue`, Execute checklist, upsert, approval.

### Phase gating

For every gate line: **done**, **blocked**, or **`N/A`** + one-line justification. Keep gate status **short** (chat and/or a brief appendix)—**do not** let Phase-1 ceremony dominate the written plan body. Prefer a short implement plan file under the mapped plans root when helpful (e.g. `<MAPPED_PLANS_ROOT>/knowledge/implement_plans/…`); otherwise keep the checklist in chat and on the story/scenario notes you update. When the user supplied a plan file, **use that path** as the plan artifact (update it in place with ULID / task → issue id mappings when practical).

---

## Phase 1 — Analyze (read-only)

**Goal:** Understand the requirement, related scenarios, quality gaps, and current code coverage. Do **not** implement yet.

1. **Load the primary requirement (platform SoT)**
   - **Plan file input:** resolve story/scenario ordinals from the plan (see above); then load platform content for those ordinals.
   - Story: MCP/CLI **`get-user-stories`** with the ordinal.
   - Scenario: **`get-test-scenarios`** with the ordinal; then **`get-user-stories`** for each linked parent story ordinal.
   - Prefer returned **`content`** over stale local files; use `plans/stories/` / `plans/scenarios/` as fallback.
   - Also read the **plan file body** as the intended implementation scope (code deltas, task list)—do not ignore it in favor of a from-scratch redesign.

2. **Find related scenarios (story-scoped)**
   - When a **story** ordinal is known (from prompt or plan): under the mapped plans root, **grep scenario frontmatter** for that story id (e.g. `story: US-42` / variants the repo uses).
   - Collect every matching scenario file; load platform content via **`get-test-scenarios`** for those ordinals.
   - Record the full set: primary + related scenarios. Plan file may narrow in-scope scenarios—honor explicit in/out lists in the plan.

3. **Gaps, ambiguities, and testability**
   - Skim acceptance criteria vs code / existing SmartTests (scenario **`annotation`** links, or deprecated `// @Scenario:` in older specs).
   - Note missing scenarios, ambiguous acceptance criteria, and product areas that must change.
   - **Requirement quality (agent judgment):** When the requirement looks thin, ambiguous, or hard to test — or the user asks — call **`get-requirement-quality-report`**. If no prior analysis exists (subject stub only: no findings/metrics), **ask** whether to run quality analytics via [`run-requirement-quality-checks.md`](./run-requirement-quality-checks.md) (that playbook updates the platform report). Do **not** treat quality analytics as mandatory on every run.

4. **Environment / conventions**
   - Re-read `plans/knowledge/ai-test-instructions.md` and **`implement.policy.md`** for coding standards, out-of-scope rules, post-implement lifecycle status, and any Pre-/Post-Execute workflows.
   - Do **not** start a full Run QA unless the policy or user asks; optional post-implement QA is a separate `/testchimp run QA` / subflow.
   - Spend exploration budget on **codebase design inputs** needed for a high-quality Product plan (existing modules, APIs, schema, reuse paths). Keep Analyze ceremony short in the written artifact.

### Phase 1 completion gate

- [ ] Input resolved (story / scenario / plan file) and story ordinal noted or explicitly missing.
- [ ] Primary story/scenario markdown loaded when ordinals exist (platform preferred); plan file read when provided.
- [ ] Related scenarios discovered via frontmatter grep (or `N/A` if scenario-only / plan-scoped with no siblings / no story).
- [ ] Gaps / ambiguities / testability notes captured (quality report optional per judgment).
- [ ] Policy + ai-test-instructions consulted.

---

## Phase 2 — Plan

**Goal:** Produce a **Product plan** good enough to implement without re-deriving design, then **wrap** it with workflow traceability. Persist **`workflow_execution_id`** (ULID) here.

The implement skill must **not** reduce planning quality vs unconstrained implementation planning. Workflow sections are **additive**; they must not compress or replace design detail.

### A — Product plan (required; design-first)

Author this **as if `/testchimp implement` were not involved** (same depth as Cursor Plan mode / “implement this story”).

**When the user supplied a detailed plan file** (Cursor `.plan.md`, finetuned implement plan, etc.): **Adopt it wholesale** as the Product plan. Do **not** rewrite into a thinner outline. Only surface material gaps or conflicts with the story. Then add the Workflow envelope (§B).

**When starting from a story/scenario id (or a thin story markdown that is not an implement plan):** Explore the codebase and write a full Product plan. Include, when knowable:

1. **Architecture** — components/services and how data flows (diagram optional but encouraged for multi-service work).
2. **Committed decisions** — pick defaults for major tech choices; do **not** leave “option A or B” unresolved without a stated default.
3. **Schema / persistence** — concrete DDL or migration intent (table/column/index changes), entity owners (Hibernate / TypeORM / etc.).
4. **API / proto contracts** — owning service, message/RPC names, key request/response fields (not just “add APIs”).
5. **UI structure** — screens/components, layout, reuse of existing widgets, interaction behaviour.
6. **Key files to touch** — concrete paths (and what changes in each area).
7. **Scope** — story ordinal and scenario ordinals in / out; explicit out-of-scope.
8. **Tests** — add/update SmartTests or API tests in this run, or defer to `/testchimp run QA` (say which).
9. **Risks / open questions** — only true blockers; prefer deciding defaults over deferring design.

**Anti-patterns (fail Phase 2 if the plan is mostly these):**
- Phase-1 gate tables and policy/ceremony as the main body.
- A task-title table **without** architecture / files / contracts above.
- Vague “implement the story” / “add APIs” / “update UI” with no paths or shapes.
- Major choices left as unresolved “or” with no default.

### B — Workflow envelope (required; wrap-second)

**Derive** from the Product plan — do **not** invent a separate thin plan:

1. **Task breakdown** — concrete actionable **tasks** projected from the Product plan for platform `TASK_ISSUE` recording. For each task (before `create-issue`):
   - **title** (e.g. `Add policy upsert API`)
   - **priority** (`critical` / `high` / `medium` / `low`) → maps to **`severity`** on create (see Execute)
   - **category** (best-fit `BugCategory`, e.g. `FUNCTIONAL`, `SECURITY`, `PERFORMANCE` — see [`cli.md`](./cli.md) § `create-issue`)
   - Prefer task titles already listed in a supplied plan file. Task titles are a **projection** of the Product plan, not a substitute for it.
   - Do **not** call **`create-issue`** yet — platform mutations wait until after Plan approval (same rule as stories/scenarios).
2. **Execute checklist** — actionable `- [ ]` items (every task; optional self-review / smoke).
3. **Frontmatter** — `workflow_execution_id: <ulid>`, `workflow_id: implement`, `LastRunOnCommit`, `PlanApproved` (plus story/scenario ordinals when known).
4. **Write** the combined Product plan + envelope to **`<MAPPED_PLANS_ROOT>/knowledge/workflow_plans/implement/<workflow_execution_id>.plan.md`** (or adopt/update a user-supplied plan file and also copy/sync into that canonical path when executing as workflow `implement`).
5. **`upsert-plans-support-file`** with that relative path + content (**BLOCKING** before Execute).

**Pause for explicit user approval** before Execute — **except** when (a) the prompt has **`--mode=non-interactive`** (set `PlanApproved: yes` + `ApprovedBy: auto`, Execute, open a PR), (b) the user already asked to implement a specific plan file (that counts as approval of the file’s content; still confirm if you changed scope or task titles), or (c) policy sets `allow-execute-without-approval: true`.

### Phase 2 completion gate

- [ ] Product plan written or adopted at unconstrained implementation depth (architecture / files / contracts as applicable)—not ceremony- or task-table-only.
- [ ] Workflow envelope added: ULID frontmatter, derived task titles (each with priority + category), Execute checklist.
- [ ] Plan upserted; user approved (or plan-file implement request treated as approval).

---

## Phase 3 — Execute

**Goal:** File task issues (story/scenario-linked when ordinals are known; severity + category + `TestChimp Implement` label), implement the approved plan in the product codebase, mark tasks **`FIXED`** as work completes, then self-review.

1. **Create task issues (required, immediately after Plan approval)** — For each planned task, MCP-first **`create-issue`** (CLI ≥ **0.1.17**; see [`cli.md`](./cli.md) § `create-issue`) with:
   - **`issueType`:** `TASK_ISSUE`
   - **`status`:** `ACTIVE` (default)
   - **`title`:** the planned task title
   - **`severity`:** from the Plan priority for that task — map `critical` → `CRITICAL_SEVERITY`, `high` → `HIGH_SEVERITY`, `medium` → `MEDIUM_SEVERITY`, `low` → `LOW_SEVERITY`. Default **`MEDIUM_SEVERITY`** when priority was not recorded.
   - **`category`:** the Plan category for that task (required). Prefer a concrete `BugCategory` (e.g. `FUNCTIONAL` for feature work, `SECURITY` / `PERFORMANCE` / `ACCESSIBILITY` when clearly that domain). Default **`FUNCTIONAL`** only when no better fit.
   - **`labels`:** `["TestChimp Implement"]` — **required**. Do **not** use `source: testchimp-implement` / the `source` field for implement tasks (that becomes label `source:testchimp-implement`).
   - **`linkTargets`:** link the requirement entities this task implements (**numeric plan ordinals only**, as strings — the server resolves them to internal entity ids). Build the array from what is known:
     - **Story:** when a story ordinal is known (from prompt or plan), include `{ "toEntityType": "STORY", "toEntityId": "<storyOrdinal>" }` (parent story even when the primary input was a scenario).
     - **Scenario(s):** when scenario ordinal(s) are in scope for this run, include one `{ "toEntityType": "SCENARIO", "toEntityId": "<scenarioOrdinal>" }` per in-scope scenario the task covers (at minimum: the primary scenario when input was scenario-scoped; when story-scoped, all in-scope scenario ordinals from the Plan unless the task is explicitly scoped to a subset).
     - **If neither story nor scenario ordinal is known:** omit `linkTargets` and record `N/A — no story/scenario id on plan/prompt` next to the task.
   - **Traceability on the mutating call (P0):** nested **`agentTraceability`** (or CLI flags) **must** include both **`workflow_id: implement`** and the **same Plan `workflow_execution_id`** (the ULID from Phase 2 frontmatter) on every `create-issue` / `update-issue-status`. Also pass `--policy-file`, `--policy-version`, `--git-sha`, `--actor-type`, `--branch-name`, `--agent-model` when known — see [`policies-and-traceability.md`](./policies-and-traceability.md). **Never omit `workflow_execution_id`**; **never mint a new ULID per task** — that creates orphan RUNNING executions in workflow history. The server will not attach Activity without both ids (and will not invent an execution id).
   - Record each returned **`issueId`** / **`ordinalId`** next to the matching checklist item (e.g. `- [ ] Add policy upsert API → B-42`).
   - Do **not** invent issue ids; do **not** skip story/scenario linking when those ordinals **are** known; do **not** omit `severity`, `category`, or the **`TestChimp Implement`** label.

2. Follow **`implement.policy.md`** and repo conventions (**minimal diffs on Execute** — match existing style; do not use “minimal” as an excuse to thin the Product plan in Phase 2).

3. **Implement per task** — Work through checklist tasks in order (or a declared dependency order). As each task’s product work completes, MCP-first **`update-issue-status`** with that task’s **`issueId`** and **`status: FIXED`** (pass the **same** Plan `workflow_id` / `workflow_execution_id` and other traceability fields). Marking a task **`FIXED`** does **not** close the workflow execution — only Phase 4 **`ACTION_COMPLETED`** does. Optional: set **`IN_PROGRESS_BUG`** when starting a task; default path is **`ACTIVE` → `FIXED`** on completion. Abandoned tasks: mark **`N/A`** + one-line justification in the checklist (do not leave as silent `ACTIVE`).

4. Implement behaviour for the story and in-scope scenarios (via the task loop above), following the approved / supplied plan.

5. **Self-review (required before Report)** — check and fix:
   - Gaps vs acceptance criteria / in-scope scenarios / plan file
   - Logical errors in changed paths
   - Performance issues (chatty reads/writes, N+1, unnecessary round-trips, sub-optimal queries)
   - Code smells in touched code (match local patterns; no drive-by refactors)

6. Optionally run focused unit/integration/SmartTests if the plan called for them (**Preamble #4** for runner `TESTCHIMP_API_KEY`).

7. After each material mutation, best-effort **`report-agent-action`** (`CREATED` / `UPDATED` on code-backed artifacts when applicable; prefer reporting on **`USER_STORY` / `SCENARIO`** once implementation for that entity is done — see Report). **`create-issue`** / **`update-issue-status`** already carry traceability on the mutating call.

Do **not** invent story/scenario/issue ids.

### Phase 3 completion gate

- [ ] Task issues created (`TASK_ISSUE`; story/scenario `linkTargets` when ordinals known; `severity` + `category` + label `TestChimp Implement`) with recorded `issueId`s (or `N/A` + justification if zero tasks).
- [ ] Each created task marked `FIXED` (or checklist `N/A` + justification if abandoned).
- [ ] Checklist items done or `N/A` + justification.
- [ ] Self-review against acceptance criteria, logic, performance, and smells completed (issues fixed or escalated).
- [ ] Open blockers reported to the user.

---

## Phase 4 — Report

**Goal:** Activity timeline, lifecycle status, and workflow execution closed correctly.

1. **Task issue gate** — Confirm every task issue created in Execute is **`FIXED`**, or explicitly abandoned with checklist **`N/A`** + justification. If any remain `ACTIVE` / `IN_PROGRESS_BUG` without justification, finish them or escalate before closing the workflow.

2. **`IMPLEMENTED` reports** — For each story and each in-scope scenario whose product behaviour you finished this run, call **`report-agent-action`** with:
   - `action_type`: `IMPLEMENTED`
   - `entity_type`: `USER_STORY` or `SCENARIO`
   - `entity_identity`: numeric ordinal only
   - same `workflow_execution_id`, `workflow_id: implement`, policy / git / actor / branch fields
   - Skip story/scenario `IMPLEMENTED` only when no ordinal was ever resolved (`N/A` + justification).
3. **Lifecycle status** — Unless **`implement.policy.md`** overrides (see **Post-implement lifecycle status**), set status to **`ready`** for each finished story/scenario via MCP/CLI **`update-plan-items-lifecycle-status`**:
   - `--entity-type story|scenario`
   - `--ordinal-id <n>`
   - `--status ready` (or the policy override value)
   - One call per entity when multiple are in scope.
   - Policy may set `skip` / leave unchanged — do not call the tool in that case.
   - Do **not** use `mark-plan-items-implementation-done` here (`done` is for post-QA Validate).
4. **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (required):
   - Reconcile ledger vs `get-workflow-execution` (include actions).
   - Emit any missing create/update/analyze/implement reports.
   - **`ACTION_COMPLETED`** with `entity_type: WORKFLOW`, `entity_identity: implement` (or `ACTION_FAILED` if aborting).

Actions appear on the story/scenario **Activity** tabs and the workflow execution timeline. Task issues appear linked on the story and/or scenario(s) via **`linkTargets`** when those ordinals were known.

### Phase 4 completion gate

- [ ] All created task issues `FIXED` (or abandoned with `N/A` + justification).
- [ ] `IMPLEMENTED` sent for finished story/scenario ordinals (or `N/A` if none resolved).
- [ ] Lifecycle status updated per policy (default `ready`) or explicitly skipped.
- [ ] Ledger reconciled; missing reports emitted.
- [ ] `ACTION_COMPLETED` (or `ACTION_FAILED`) for `WORKFLOW` / `implement`.

---

## Guardrails

- Story/scenario ordinals are platform-provisioned — never invent ids ([`author-plans.md`](./author-plans.md)).
- Prefer MCP tools first; CLI fallback with **Preamble #4** (`TESTCHIMP_API_KEY` + `TESTCHIMP_BACKEND_URL` when configured).
- Accept a **plan file** as primary input; resolve **`story`** / **`scenario`** from its frontmatter (or body fallback). **Adopt detailed plans wholesale** as Product plan; only wrap with envelope + derived tasks.
- Break work into **`TASK_ISSUE`** issues via `create-issue` with story/scenario **`linkTargets`**, **`severity`**, **`category`**, and label **`TestChimp Implement`**; mark each **`FIXED`** via **`update-issue-status`** as that task completes — do not rely on a separate link tool. Task issues record the breakdown; they do **not** replace Product plan depth.
- Keep implement focused on **product implementation**; use `/testchimp run QA` for full author-plans → create-tests → ExploreChimp composites unless the implement policy nests a post-execute workflow.
- Identity and action vocabulary: [`policies-and-traceability.md`](./policies-and-traceability.md) — no `detail_json`.

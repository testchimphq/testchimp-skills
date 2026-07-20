# `/testchimp implement` — implement a requirement

**Workflow id:** `implement`  
**Canonical prompt:** `/testchimp implement <story id / scenario id>`  
**Policy:** `plans/knowledge/policies/implement.policy.md` (or `--policy` / matching frontmatter; fallback `ai-test-instructions.md`). Default seed: [`assets/policies/implement.policy.md`](../assets/policies/implement.policy.md).

Implement product behaviour for a **user story** or **scenario** using the repo’s implementation conventions and the project **implement** policy. This is a **Development** workflow (not Run QA): ship code that satisfies the requirement, then mark implementation and close the workflow execution.

> **Traceability:** Persist a **ULID** `workflow_execution_id` before Execute; report mutating actions with **`report-agent-action`**. Before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (reconcile ledger → emit missing reports → `ACTION_COMPLETED` with `WORKFLOW` + `implement`). Vocabulary: [`policies-and-traceability.md`](./policies-and-traceability.md).

## Inputs

- **Story** — `US-42`, `42`, `#US-42`, or `/testchimp implement story 42`
- **Scenario** — `TS-107`, `107`, `#TS-107`, or `/testchimp implement scenario 107`

Parse to a **numeric ordinal** for MCP/CLI and for `report-agent-action` (`entity_identity` must be the ordinal only — no `US-` / `TS-` prefix).

If the user names a scenario, treat that scenario as the primary target and still load its parent story. If they name a story, implement the story **and** its related scenarios (see Analyze).

## Phase overview

**Analyze → Plan → Execute → Report** (strict). Do not mutate product code until the user approves the Plan. Mint `workflow_execution_id` during Plan and reuse it for every `report-agent-action`.

### Phase gating

For every gate line: **done**, **blocked**, or **`N/A`** + one-line justification. Prefer a short implement plan file under the mapped plans root when helpful (e.g. `<MAPPED_PLANS_ROOT>/knowledge/implement_plans/…`); otherwise keep the checklist in chat and on the story/scenario notes you update.

---

## Phase 1 — Analyze (read-only)

**Goal:** Understand the requirement, related scenarios, quality gaps, and current code coverage. Do **not** implement yet.

1. **Load the primary requirement (platform SoT)**
   - Story: MCP/CLI **`get-user-stories`** with the ordinal.
   - Scenario: **`get-test-scenarios`** with the ordinal; then **`get-user-stories`** for each linked parent story ordinal.
   - Prefer returned **`content`** over stale local files; use `plans/stories/` / `plans/scenarios/` as fallback.

2. **Find related scenarios (story-scoped)**
   - When the primary target is a **story** (or after resolving the parent story for a scenario): under the mapped plans root, **grep scenario frontmatter** for that story id (e.g. `story: US-42` / variants the repo uses).
   - Collect every matching scenario file; load platform content via **`get-test-scenarios`** for those ordinals.
   - Record the full set: primary + related scenarios.

3. **Gaps, ambiguities, and testability**
   - Skim acceptance criteria vs code / existing SmartTests (`// @Scenario:` links).
   - Note missing scenarios, ambiguous acceptance criteria, and product areas that must change.
   - **Requirement quality (agent judgment):** When the requirement looks thin, ambiguous, or hard to test — or the user asks — call **`get-requirement-quality-report`**. If no prior analysis exists (subject stub only: no findings/metrics), **ask** whether to run quality analytics via [`run-requirement-quality-checks.md`](./run-requirement-quality-checks.md) (that playbook updates the platform report). Do **not** treat quality analytics as mandatory on every run.

4. **Environment / conventions**
   - Re-read `plans/knowledge/ai-test-instructions.md` and **`implement.policy.md`** for coding standards, out-of-scope rules, post-implement lifecycle status, and any Pre-/Post-Execute workflows.
   - Do **not** start a full Run QA unless the policy or user asks; optional post-implement QA is a separate `/testchimp run QA` / subflow.

### Phase 1 completion gate

- [ ] Primary story/scenario markdown loaded (platform preferred).
- [ ] Related scenarios discovered via frontmatter grep (or `N/A` if scenario-only with no siblings).
- [ ] Gaps / ambiguities / testability notes captured (quality report optional per judgment).
- [ ] Policy + ai-test-instructions consulted.

---

## Phase 2 — Plan

**Goal:** A concrete, approvable implementation plan covering the story and identified scenarios. Persist **`workflow_execution_id`** (ULID) here.

Include:

1. **Scope** — story ordinal and scenario ordinals in / out of this run.
2. **Code changes** — files/modules, behaviour deltas, API/UI touchpoints (no vague “implement the story”).
3. **Tests** — whether to add/update SmartTests or API tests in this run, or defer to `/testchimp run QA` (say which).
4. **Risks / open questions** — blockers that need user input.
5. **Checklist** — actionable `- [ ]` items for Execute.
6. **`workflow_execution_id: <ulid>`** in plan frontmatter or body.

**Pause for explicit user approval** before Execute.

### Phase 2 completion gate

- [ ] Plan written with scope, code deltas, test intent, checklist.
- [ ] ULID persisted.
- [ ] User approved.

---

## Phase 3 — Execute

**Goal:** Implement the approved plan in the product codebase, then self-review.

1. Follow **`implement.policy.md`** and repo conventions (minimal diffs; match existing style).
2. Implement behaviour for the story and in-scope scenarios.
3. **Self-review (required before Report)** — check and fix:
   - Gaps vs acceptance criteria / in-scope scenarios
   - Logical errors in changed paths
   - Performance issues (chatty reads/writes, N+1, unnecessary round-trips, sub-optimal queries)
   - Code smells in touched code (match local patterns; no drive-by refactors)
4. Optionally run focused unit/integration/SmartTests if the plan called for them (**Preamble #4** for runner `TESTCHIMP_API_KEY`).
5. After each material mutation, best-effort **`report-agent-action`** (`CREATED` / `UPDATED` on code-backed artifacts when applicable; prefer reporting on **`USER_STORY` / `SCENARIO`** once implementation for that entity is done — see Report).

Do **not** invent story/scenario ids.

### Phase 3 completion gate

- [ ] Checklist items done or `N/A` + justification.
- [ ] Self-review against acceptance criteria, logic, performance, and smells completed (issues fixed or escalated).
- [ ] Open blockers reported to the user.

---

## Phase 4 — Report

**Goal:** Activity timeline, lifecycle status, and workflow execution closed correctly.

1. **`IMPLEMENTED` reports** — For each story and each in-scope scenario whose product behaviour you finished this run, call **`report-agent-action`** with:
   - `action_type`: `IMPLEMENTED`
   - `entity_type`: `USER_STORY` or `SCENARIO`
   - `entity_identity`: numeric ordinal only
   - same `workflow_execution_id`, `workflow_id: implement`, policy / git / actor / branch fields
2. **Lifecycle status** — Unless **`implement.policy.md`** overrides (see **Post-implement lifecycle status**), set status to **`ready`** for each finished story/scenario via MCP/CLI **`update-plan-items-lifecycle-status`**:
   - `--entity-type story|scenario`
   - `--ordinal-id <n>`
   - `--status ready` (or the policy override value)
   - One call per entity when multiple are in scope.
   - Policy may set `skip` / leave unchanged — do not call the tool in that case.
   - Do **not** use `mark-plan-items-implementation-done` here (`done` is for post-QA Validate).
3. **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (required):
   - Reconcile ledger vs `get-workflow-execution` (include actions).
   - Emit any missing create/update/analyze/implement reports.
   - **`ACTION_COMPLETED`** with `entity_type: WORKFLOW`, `entity_identity: implement` (or `ACTION_FAILED` if aborting).

Actions appear on the story/scenario **Activity** tabs and the workflow execution timeline.

### Phase 4 completion gate

- [ ] `IMPLEMENTED` sent for finished story/scenario ordinals.
- [ ] Lifecycle status updated per policy (default `ready`) or explicitly skipped.
- [ ] Ledger reconciled; missing reports emitted.
- [ ] `ACTION_COMPLETED` (or `ACTION_FAILED`) for `WORKFLOW` / `implement`.

---

## Guardrails

- Story/scenario ordinals are platform-provisioned — never invent ids ([`author-plans.md`](./author-plans.md)).
- Prefer MCP tools first; CLI fallback with **Preamble #4** (`TESTCHIMP_API_KEY` + `TESTCHIMP_BACKEND_URL` when configured).
- Keep implement focused on **product implementation**; use `/testchimp run QA` for full author-plans → create-tests → ExploreChimp composites unless the implement policy nests a post-execute workflow.
- Identity and action vocabulary: [`policies-and-traceability.md`](./policies-and-traceability.md) — no `detail_json`.

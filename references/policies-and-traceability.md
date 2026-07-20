# Policies and agent-action traceability

Short reference for workflow policies under **`plans/knowledge/policies/*.policy.md`** and **`report-agent-action`**. Details stay thin; playbooks keep battle-tested steps.

## Purpose of policies

A **policy** is the project’s version-controlled answer to: *how should this workflow run for us?* Skill playbooks supply the battle-tested how-to; the policy supplies **team-specific decisions** so agents (local or cloud) can run without re-asking every time.

When **reading** a policy, look for:

- Scoping (feature branch / default branch / explicit paths or filters)
- Environment / connect rules (`BASE_URL`, local vs CI, ephemeral vs shared)
- Subflow order and which steps to skip (composites)
- Quality bar, exclusions, and overrides of skill defaults
- Anything that must stay stable for non-interactive / repeatable runs

When **authoring** or updating one: capture those decisions in plain markdown under the right `workflow-id`, bump **`version`** when guidance changes, prefer **`<workflow-id>.policy.md`** for the project default, and use custom filenames + **`--policy`** for variants. Do not rewrite playbook steps into the policy — only project choices. Seed from **`ai-test-instructions.md`** when present. See [`create-policy.md`](./create-policy.md).

## Scoping (overarching — all workflows)

Resolve **what to work on** in this order. This rule is **not** workflow-specific; individual playbooks and policy `### Scoping Rules` may **narrow or specialize** it (e.g. Smart regression’s identification steps) but must not contradict it.

1. **Explicit scope** — user (or trigger) named plans paths, scenario/story ordinals, files, plain-English focus, or similar → use that as the scope.
2. **Feature / PR branch** (no explicit scope) — scope = **changes on this branch** (diff vs the merge base / default branch): touched plans, code, and linked tests.
3. **Default branch** (no explicit scope) — scope = **changes since the last run of the same workflow**:
   - Call **`get-last-run-workflow-detail`** (`workflowId`, optional `branchName`, optional `userId`).
   - If a last run exists and is a useful bound, use commits/changes since that run’s git SHA / start.
   - If missing, stale, or ambiguous: **ask the user** whether to focus on the last few commits (and since when) vs a broader window — get consent before proceeding.

Record the chosen scope on the plan (or say it clearly before Execute) so nested subflows reuse it. Composites share **one** scope for the whole run-qa / upkeep execution.

## Policy frontmatter (required)

Every policy file must start with:

```yaml
---
workflow-id: <one of the catalog workflow ids>
version: <semver string, e.g. 1.0.0>
---
```

Optional recommended sections: `### Summary`, `### Pre-Execute Workflows`, `### Post-Execute Workflows`, `### Subflows` (composites), `### Scoping Rules`, then workflow-specific body.

Default composites shipped in the skill: [`assets/policies/run-qa.policy.md`](../assets/policies/run-qa.policy.md), [`assets/policies/upkeep.policy.md`](../assets/policies/upkeep.policy.md). Init seeds these into **`plans/knowledge/policies/`** when missing. Authoring aids (not auto-seeded): [`assets/policies/connect-to-test-env.policy.md`](../assets/policies/connect-to-test-env.policy.md), [`assets/policies/implement.policy.md`](../assets/policies/implement.policy.md). Author more via [`create-policy.md`](./create-policy.md).

## Policy resolution order

1. Explicit **`--policy`** / user-named policy file (under `plans/knowledge/policies/`).
2. Default filename **`<workflow-id>.policy.md`**.
3. Any other `*.policy.md` whose frontmatter **`workflow-id`** matches (prefer oldest/default rules if multiple—platform marks `<workflow-id>.policy.md` as default when present).
4. Fallback: decisions in **`plans/knowledge/ai-test-instructions.md`** (backward compatible when policies are absent).

CLI/MCP: **`get-policy`**, **`list-policies`**, **`upsert-policy`**, **`list-workflow-catalog`**. Env hint: **`POLICY_FILE`** when a host/runner injects the chosen policy path.

After authoring a policy on disk, call **`upsert-policy`** so it is available on the platform immediately (git push also syncs later). See [`create-policy.md`](./create-policy.md) and [`cli.md`](./cli.md).

## ULID before Execute

For Plan → approve → Execute workflows (`run-qa`, `upkeep`, `implement`, standalone mutating flows):

1. During **Plan**, generate one **ULID** as **`workflow_execution_id`**.
2. Persist it in the plan file frontmatter or body (e.g. `workflow_execution_id: <ulid>`).
3. Reuse the **same** ULID for every **`report-agent-action`** in that run — do **not** mint a new id per mutation.

## `report-agent-action` vocabulary

Call after creating/updating/deleting/analyzing/implementing meaningful artifacts. Fields (CLI/MCP; camelCase or flags per [`cli.md`](./cli.md)):

| Field | Notes |
|-------|--------|
| `workflow_id` | Catalog id (`run-qa`, `implement`, `create-tests`, …) |
| `workflow_execution_id` | Stable ULID for the whole run |
| `policy_file` / `policy_version` | From resolved policy frontmatter |
| `git_sha` | Current HEAD |
| `actor_type` | `local-agent` or `cloud-agent` |
| `user_id` | Optional; from MCP env when present |
| `branch_name` | Current git branch |
| `entity_type` | **Closed set** below — use these exact names |
| `test` **or** `entity_identity` | **Mutually exclusive**. See identity rules |
| `action_type` | Closed set below |

**Do not send `detail_json`** — the field is removed from the API. Context lives in entity identity + action type + workflow metadata.

**Where actions show up:** Reported actions appear on the **Activity** tab for the related plan item (story/scenario), **issue**, and **SmartTest** (file-level) in the TestChimp UI, and on the workflow execution timeline.

**First successful report** for a new `workflow_execution_id` **creates** the DB workflow execution (`execution_created: true`); later reports append actions to the same execution.

**Since last run:** **`get-last-run-workflow-detail`** (`workflow_id`, optional `branch_name`, optional `user_id`).

### Closed entity types (`entity_type`)

| `entity_type` | Identity field | Identity value |
|---------------|----------------|----------------|
| `USER_STORY` | `entity_identity` | Positive integer **ordinal only** (e.g. `42` — **no** `US-` / `#` prefix) |
| `SCENARIO` | `entity_identity` | Positive integer **ordinal only** (e.g. `107` — **no** `TS-` / `#` prefix) |
| `SMART_TEST` | `test` (TestLocator) | `folderPath` + `fileName` + `testSuite` + `testName` (`fileName` and `testName` required). **Do not** also send `entity_identity` |
| `POLICY` | `entity_identity` | Policy **filename** matching `*.policy.md` (e.g. `run-qa.policy.md`) |
| `ISSUE` | `entity_identity` | Positive integer **ordinal only** (no `B-` / `#` prefix) |
| `TEST_EXECUTION` | `entity_identity` | Opaque execution / job id from the platform or prompt |
| `TEST_INVOCATION_BATCH` | `entity_identity` | Opaque batch invocation id |
| `EXPLORATION` | `entity_identity` | Opaque exploration id |
| `EVENT` | `entity_identity` | TrueCoverage **event title** (as instrumented / documented) |
| `WORKFLOW` | `entity_identity` | Catalog **`workflow_id`** — **only** with `ACTION_COMPLETED` / `ACTION_FAILED`; must **equal** `workflow_id` |

### Closed action types (`action_type`)

| `action_type` | When |
|---------------|------|
| `CREATED` | New story, scenario, SmartTest, policy, issue, etc. |
| `UPDATED` | Meaningful edit to an existing entity |
| `DELETED` | Removed / retired artifact |
| `ANALYZED` | Read-only analysis that should appear on the Activity timeline (e.g. DeFOSPAM, coverage recon) |
| `IMPLEMENTED` | Requirement implementation finished for a **`USER_STORY`** or **`SCENARIO`** only |
| `ACTION_COMPLETED` | End of a successful workflow run — **requires** `entity_type: WORKFLOW` and `entity_identity` = `workflow_id` (sets execution `completedAt`) |
| `ACTION_FAILED` | Abort / failed run — same `WORKFLOW` identity rules as completed |

After **`IMPLEMENTED`** in the **`implement`** workflow, also call **`update-plan-items-lifecycle-status`** (CLI ≥ **0.1.22**) to set lifecycle status (default **`ready`**, unless policy overrides) — see [`implement-requirement.md`](./implement-requirement.md) and [`cli.md`](./cli.md). That is separate from `report-agent-action`.

`WORKFLOW` is **invalid** for non-completion actions. `IMPLEMENTED` is **invalid** for anything other than `USER_STORY` / `SCENARIO`.

### Cheat sheet — when to report

| You just… | `action_type` | `entity_type` + identity |
|-----------|---------------|--------------------------|
| Created / updated a user story | `CREATED` / `UPDATED` | `USER_STORY` + ordinal |
| Created / updated a scenario | `CREATED` / `UPDATED` | `SCENARIO` + ordinal |
| Finished implementing a story or scenario | `IMPLEMENTED` | `USER_STORY` or `SCENARIO` + ordinal |
| Authored / changed a SmartTest | `CREATED` / `UPDATED` | `SMART_TEST` + TestLocator `test` |
| Wrote / upserted a policy file | `CREATED` / `UPDATED` | `POLICY` + `*.policy.md` filename |
| Filed or updated an issue | `CREATED` / `UPDATED` | `ISSUE` + ordinal |
| Ran DeFOSPAM / coverage analysis worth tracing | `ANALYZED` | story / scenario / other applicable type |
| Fixed failures tied to an execution or batch | `UPDATED` (and/or related SmartTest) | `TEST_EXECUTION` / `TEST_INVOCATION_BATCH` + opaque id |
| Instrument / document a TrueCoverage event | `CREATED` / `UPDATED` | `EVENT` + event title |
| Finished the whole workflow (success) | `ACTION_COMPLETED` | `WORKFLOW` + catalog `workflow_id` |
| Aborted the workflow | `ACTION_FAILED` | `WORKFLOW` + catalog `workflow_id` |

Best-effort during Execute is fine for intermediate mutations; **completion reporting is required** before you treat the run as done — see below.

### Report workflow execution

**Required before completion** of any Plan → Execute workflow (`run-qa`, `upkeep`, `implement`, and other mutating catalog flows that mint a `workflow_execution_id`):

1. **Reconcile the ledger** — Compare what you actually mutated this run (plan checklist, commits, MCP creates/updates) against actions already recorded for this `workflow_execution_id` (`get-workflow-execution` with `include_actions: true`, or the execution returned from earlier reports).
2. **Emit missing `report-agent-action` calls** — For each material create/update/delete/analyze/implement that is not yet on the ledger, send the corresponding report (same ULID, correct entity vocabulary). Do not invent entities you did not touch.
3. **Complete the execution** — Call **`report-agent-action`** with:
   - `action_type`: `ACTION_COMPLETED` (or `ACTION_FAILED` if aborting)
   - `entity_type`: `WORKFLOW`
   - `entity_identity`: the same catalog **`workflow_id`** (e.g. `run-qa`, `implement`)
   - the stable `workflow_execution_id`, plus policy / git / actor / branch fields as usual

Skipping step 3 leaves the execution `RUNNING` in the Workflows UI. Completing without reconciling leaves Activity tabs incomplete for stories, issues, and SmartTests.

## Disabled / Missing Config (agent behavior)

Workflow catalog status may be **Active**, **Disabled**, or **Missing Config**.

- **Disabled** — project intentionally turned the workflow off (e.g. TrueCoverage instrumentation). Do not run it; explain briefly and continue other subflows when in a composite.
- **Missing Config** — required policy is absent. **Blocking only for `connect-to-test-env`**: stop provisioning/authoring that needs an env; discuss with the user and author/seed **`connect-to-test-env.policy.md`** (from ai-test-instructions or [`create-policy.md`](./create-policy.md)). Dependent workflows may also show Missing Config in the UI; agents should fix connect-to-test-env first, then retry.

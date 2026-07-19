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

Default composites shipped in the skill: [`assets/policies/run-qa.policy.md`](../assets/policies/run-qa.policy.md), [`assets/policies/upkeep.policy.md`](../assets/policies/upkeep.policy.md). Init seeds these into **`plans/knowledge/policies/`** when missing. Author more via [`create-policy.md`](./create-policy.md).

## Policy resolution order

1. Explicit **`--policy`** / user-named policy file (under `plans/knowledge/policies/`).
2. Default filename **`<workflow-id>.policy.md`**.
3. Any other `*.policy.md` whose frontmatter **`workflow-id`** matches (prefer oldest/default rules if multiple—platform marks `<workflow-id>.policy.md` as default when present).
4. Fallback: decisions in **`plans/knowledge/ai-test-instructions.md`** (backward compatible when policies are absent).

CLI/MCP: **`get-policy`**, **`list-policies`**, **`list-workflow-catalog`**. Env hint: **`POLICY_FILE`** when a host/runner injects the chosen policy path.

## ULID before Execute

For Plan → approve → Execute workflows (`run-qa`, `upkeep`, standalone mutating flows):

1. During **Plan**, generate one **ULID** as **`workflow_execution_id`**.
2. Persist it in the plan file frontmatter or body (e.g. `workflow_execution_id: <ulid>`).
3. Reuse the **same** ULID for every **`report-agent-action`** in that run — do **not** mint a new id per mutation.

## `report-agent-action` (best-effort on mutating actions)

Call after creating/updating/deleting/analyzing meaningful artifacts (tests, plans, issues, fixes, etc.). Fields (CLI/MCP; camelCase or flags per [`cli.md`](./cli.md)):

| Field | Notes |
|-------|--------|
| `workflow_id` | Catalog id (`run-qa`, `create-tests`, …) |
| `workflow_execution_id` | Stable ULID for the whole run |
| `policy_file` / `policy_version` | From resolved policy frontmatter |
| `git_sha` | Current HEAD |
| `actor_type` | `local-agent` or `cloud-agent` |
| `user_id` | Optional; from MCP env when present |
| `branch_name` | Current git branch |
| `entity_type` | e.g. `test`, `story`, `scenario`, `issue`, `test_execution`, `batch_invocation`, `workflow` |
| `test` **or** `entityIdentity` | **Mutually exclusive** (camelCase on the wire). SmartTests → `test` TestLocator (`folderPath`, `fileName`, `testSuite`, `testName`). Other artifacts → `entityIdentity` as project-scoped **ordinal id** (readable int string). Do **not** use platform UUIDs. Exception: execution/batch ids only when the prompt explicitly provided them. |
| `action_type` | `created` / `updated` / `deleted` / `analyzed` / **`completed`** (`ACTION_COMPLETED`) / **`failed`** (`ACTION_FAILED`). Completing/failing marks the workflow execution done (`completedAtMillis`). Prefer `entity_type: workflow` for those. |
| `detail_json` | Optional short JSON context |

At end of Execute (or when aborting), best-effort report **`ACTION_COMPLETED`** or **`ACTION_FAILED`** so timelines leave `RUNNING`.

**First successful report** for a new `workflow_execution_id` **creates** the DB workflow execution (`execution_created: true`); later reports append actions to the same execution.

**Since last run:** **`get-last-run-workflow-detail`** (`workflow_id`, optional `branch_name`, optional `user_id`).

## Disabled / Missing Config (agent behavior)

Workflow catalog status may be **Active**, **Disabled**, or **Missing Config**.

- **Disabled** — project intentionally turned the workflow off (e.g. TrueCoverage instrumentation). Do not run it; explain briefly and continue other subflows when in a composite.
- **Missing Config** — required policy is absent. **Blocking only for `connect-to-test-env`**: stop provisioning/authoring that needs an env; discuss with the user and author/seed **`connect-to-test-env.policy.md`** (from ai-test-instructions or [`create-policy.md`](./create-policy.md)). Dependent workflows may also show Missing Config in the UI; agents should fix connect-to-test-env first, then retry.

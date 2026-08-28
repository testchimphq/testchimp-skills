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

Resolve **what to work on** in this order. This rule is **not** workflow-specific; individual playbooks and policy `### Scoping Rules` may **narrow or specialize** it (e.g. Smart smoke’s identification steps) but must not contradict it.

0. **Working branch (cloud / automation prompts)** — If the prompt includes a line `Working branch: <name>` (injected by the platform outside the editable Tasks block), **check out that branch before scoping or planning** (`git fetch && git checkout <name>`). Do **not** ask the user which branch to use in `--mode=non-interactive` or other non-interactive cloud runs. If you are already on that branch (typical for local agents), treat the line as confirmatory and continue. After checkout of the **default** branch for an **`implement`** workflow, create a **new feature branch** before coding (same rule as Raise a PR below).
1. **Explicit scope** — user (or trigger) named plans paths, scenario/story ordinals, files, plain-English focus, or similar → use that as the scope.
2. **Feature / PR branch** (no explicit scope) — scope = **changes on this branch** (diff vs the merge base / default branch): touched plans, code, and linked tests.
3. **Default branch** (no explicit scope) — scope = **changes since the last run of the same workflow**:
   - Call **`get-last-run-workflow-detail`** (`workflowId`, optional `branchName`, optional `userId`).
   - For **`run-smart-smoke`**: prefer `workflowId: run-smart-smoke`; if no last run, **fall back once** to `workflowId: run-smart-regression` (one-release legacy id).
   - If a last run exists and is a useful bound, use commits/changes since that run’s git SHA / start.
   - If missing, stale, or ambiguous: **ask the user** whether to focus on the last few commits (and since when) vs a broader window — get consent before proceeding. In **non-interactive** mode, prefer the last-run bound when available; otherwise use a short recent window (e.g. last few commits) rather than blocking.

Record the chosen scope on the plan (or say it clearly before Execute) so nested subflows reuse it. Composites share **one** scope for the whole run-qa / upkeep execution.

## Policy frontmatter (required)

**Workflow policies** must start with:

```yaml
---
workflow-id: <one of the catalog workflow ids>
version: <semver string, e.g. 1.0.0>
---
```

**Global policy** (`plans/knowledge/policies/global.policy.md`) is different: frontmatter uses **`policy-kind: global`** and **`version`** — **no** `workflow-id`. It holds project-wide suite goals (coverage target, prioritization signals, suite size / tag constraints). Fetch via **`get-policy --policy-file-name global.policy.md`** (or `--json-input '{"policyFileName":"global.policy.md"}'`). Default seed: [`assets/policies/global.policy.md`](../assets/policies/global.policy.md).

### Global policy → suite tags (required when authoring tests)

Under **`## Test suite management`**, the project defines **Playwright tags** used to group SmartTests (suite organization — CLI-filterable). The list is usually a fenced **`yaml`** block starting with **`tags:`** (so markdown editors do not flatten nested YAML). **Annotations** are reserved for scenario linking (`type: 'scenario'`). Agents **must** read this list before authoring or updating tests in **`run-qa`**, **`create-tests`**, **`upkeep`**, or any nested test-authorship subflow.

**Why tags, not grouping annotations:** Playwright CLI can filter with `--grep @smoke`. It **cannot** filter by custom annotations such as `{ type: 'group', description: 'smoke' }`. Never emit `group` (or other suite-grouping) annotations.

For **each** tag entry in the policy:

| Field | Meaning |
| --- | --- |
| `value` | Tag name **without** `@` (e.g. `smoke`). Agents emit `tag: '@smoke'`. |
| `instructions` | **When** to apply this tag — follow this text; a test may receive **multiple** tags independently |

**Apply on every new/changed SmartTest:**

1. Read local **`plans/knowledge/policies/global.policy.md`** (or **`get-policy --policy-file-name global.policy.md`**).
2. Prefer **`tags:`**. If `tags:` is missing but legacy **`annotations:`** exists, treat each listed `values` entry (or free-form instruction) as a tag value — still emit Playwright **`tag`**, never `{ type: 'group' }`.
3. For each configured tag, decide whether to apply it using that entry’s **`instructions`**.
4. Add matching Playwright tags on the test options: `tag: '@smoke'` or `tag: ['@smoke', '@p0']`.
5. Keep scenario links as **annotations** only: `{ type: 'scenario', description: '#TS-…' }`.
6. When touching a spec that still has `{ type: 'group', description: '…' }`, migrate those to tags.
7. If **`tags:`** is missing/empty **and** there is no legacy `annotations:` list: no suite tags required (scenario `annotation` links still required).

**Default seed example** (`smoke` / `regression`):

```js
test('critical checkout path', {
  tag: '@smoke',
  annotation: [
    { type: 'scenario', description: '#TS-101' },
  ],
}, async ({ page }) => { /* … */ });
```

Full authoring rules: [`write-smarttests.md`](./write-smarttests.md) § **Suite tags from global policy**.

Optional recommended sections for workflow policies: `### Summary`, `### Pre-Execute Workflows`, `### Post-Execute Workflows`, `### Subflows` (composites), `### Scoping Rules`, then workflow-specific body.

Default composites shipped in the skill: [`assets/policies/run-qa.policy.md`](../assets/policies/run-qa.policy.md), [`assets/policies/upkeep.policy.md`](../assets/policies/upkeep.policy.md). Init seeds these into **`plans/knowledge/policies/`** when missing. Authoring aid (not auto-seeded): [`assets/policies/connect-to-test-env.policy.md`](../assets/policies/connect-to-test-env.policy.md). Author more via [`create-policy.md`](./create-policy.md).

## Policy resolution order

1. Explicit **`--policy`** / user-named policy file (under `plans/knowledge/policies/`).
2. Default filename **`<workflow-id>.policy.md`**.
3. Any other `*.policy.md` whose frontmatter **`workflow-id`** matches (prefer oldest/default rules if multiple—platform marks `<workflow-id>.policy.md` as default when present).
4. Fallback: decisions in **`plans/knowledge/ai-test-instructions.md`** (backward compatible when policies are absent).

CLI/MCP: **`get-policy`**, **`list-policies`**, **`upsert-policy`**, **`list-workflow-catalog`**. Env hint: **`POLICY_FILE`** when a host/runner injects the chosen policy path.

After authoring a policy on disk, call **`upsert-policy`** so it is available on the platform immediately (git push also syncs later). See [`create-policy.md`](./create-policy.md) and [`cli.md`](./cli.md).

## ULID before Execute

For Plan → approve → Execute workflows (`run-qa`, `upkeep`, standalone mutating flows):

1. During **Plan**, resolve **`workflow_execution_id`**:
   - If the invoking prompt already includes **`--workflow-execution-id <ulid>`** (also `--workflow-execution-id=<ulid>` / embedded `workflow-execution-id: <ulid>`), **reuse it** — **never mint a second ULID** for the same run (Workflow Automations mint the id on the platform before the cloud invoke).
   - Otherwise mint one **ULID** with **`npx --yes ulid`** (trim stdout). Do not invent ids or write ad-hoc scripts — see [`agent-quick-answers.md`](./agent-quick-answers.md#mint-workflow_execution_id-ulid).
2. Persist it in the plan file frontmatter (required) at:
   **`<MAPPED_PLANS_ROOT>/knowledge/workflow_plans/<workflow-id>/<workflow_execution_id>.plan.md`**
   **Always write this file on disk** (create directories as needed) before upserting. Platform upsert alone is insufficient — local agents, ChimpHands **Files changed**, and git diffs need the worktree copy.
3. Call **`upsert-plans-support-file`** with that relative path + full content (**BLOCKING** — do not Execute until it succeeds). Content must match the local file.
4. Reuse the **same** ULID for every mutating MCP call and **`report-agent-action`** in that run — do **not** mint a new id per mutation.

**Reading a named plan (platform first):** If the prompt already names a plan file (`plan file: …`, Continue Locally, `/testchimp implement <plan.md>`, or `workflow_plans/**/*.plan.md`), call **`get-plans-support-file`** first and write `content` locally when `found: true`. Fall back to the repo file only if the platform copy is missing. Reuse the existing ULID from the filename/prompt.

## Workflow Automations (platform cloud invoke)

When TestChimp **Workflow Automations** trigger a cloud agent, the prompt always includes **`--workflow-execution-id`** (platform-minted). Mode mapping:

| Situation | Prompt `--mode` | Agent duty |
| --- | --- | --- |
| Autonomous (no plan-approval gate) | `--mode=non-interactive` | Plan → upsert → auto-approve → Execute |
| Plan-approval gate — **first** invoke | omit `--mode`; say **stop after plan upsert** | Plan → upsert → **stop** (no Execute) |
| Plan-approval gate — **Approve** (second invoke) | `--mode=non-interactive` + note plan was **user-approved** + **full plan body** | Execute that approved plan; reuse the same `--workflow-execution-id` |

Do **not** invent a second execution id on either invoke.

## Workflow execution plans (layout + approval)

Canonical plan path (skill ≥ **1.0.7**):

```text
plans/knowledge/workflow_plans/<workflow-id>/<workflow_execution_id>.plan.md
```

Platform stores these as support filetype **`WORKFLOW_EXECUTION_PLAN`**. Knowledge-base embeddings are eventual (same pending queue as stories/scenarios), not immediate on upsert.

**Required frontmatter:**

```yaml
---
workflow_id: <catalog-id>
workflow_execution_id: <ulid>
LastRunOnCommit: <git-sha>
PlanApproved: pending   # pending | yes | no | policy-non-interactive
ApprovedBy:             # set on approval: "auto" | <user id/name> | omit while pending
---
```

## Execution Mode (`--mode` prompt arg)

Parse the **invoking prompt** for a mode flag (any of these forms):

- `--mode=non-interactive`
- `--mode non-interactive`
- `mode=non-interactive`

Default when absent: **interactive** (pause for explicit user approval after Plan + upsert).

### Approval precedence (highest first)

1. **Prompt `--mode=non-interactive`** — skip the chat approval pause (see below).
2. **Policy** `allow-execute-without-approval: true` (frontmatter or `### Execution Mode` body) — skip pause; set `PlanApproved: policy-non-interactive`.
3. **Interactive (default)** — stop and wait for explicit user approval; on consent set `PlanApproved: yes` (optionally `ApprovedBy: <user>`).

### `--mode=non-interactive` agent behavior

Still run **Plan first** — do **not** skip the plan file:

1. Write `knowledge/workflow_plans/<workflow-id>/<workflow_execution_id>.plan.md` with a full checklist.
2. **`upsert-plans-support-file`** (blocking) — same as interactive.
3. **Auto-approve** without waiting for the user:
   - `PlanApproved: yes`
   - **`ApprovedBy: auto`** (required for this mode — the “approved by” frontmatter field)
4. Re-**`upsert-plans-support-file`** with the updated frontmatter.
5. **Execute** the plan immediately.
6. **Raise a PR** when there are commits to review:
   - If on the repo **default** branch, create a feature branch before coding (name it from the workflow + short scope, e.g. `testchimp/upkeep-<short-ulid>`).
   - Commit changes on that branch, push, and open a PR (e.g. `gh pr create`) summarizing what the plan executed.
   - After **create-tests** / nested run-qa **Validate**, upsert the authored-tests batch comment on that PR (see [Authored-tests PR comment](#authored-tests-pr-comment)).
   - If a PR already exists for the branch, push updates to it instead of opening a duplicate.
   - If Execute produced **no** code/plan-repo changes, skip PR creation and note that in the completion report.

`--mode=non-interactive` **wins over** an interactive policy default. It does **not** require `allow-execute-without-approval` on the policy. Nested subflows still inherit the parent plan — no second approval cycle.

**Policy-only non-interactive** (no `--mode` flag): Skip the user pause **only** when the resolved policy **explicitly** permits it:

- Frontmatter: `allow-execute-without-approval: true`
- Or a body section such as:

```markdown
### Execution Mode
- allow-execute-without-approval: true
```

When skipping via policy only, set `PlanApproved: policy-non-interactive` (and omit `ApprovedBy`, or set it only if the policy names an actor). Still upsert the plan file before Execute. PR creation follows the playbook / user request — not mandatory solely because of the policy flag.

If neither prompt mode nor policy allows skipping, **always** require explicit user approval.

**Workflow Automation plan-only (cloud):** If the prompt **omits** `--mode` **and** explicitly says **stop after plan upsert — do not Execute**, write + upsert the plan and **halt** (do not wait for chat approval). A later platform Approve invoke will re-run with `--mode=non-interactive`, the same `--workflow-execution-id`, and the full approved plan body.

**Platform upload:** `upsert-plans-support-file` (`filePath` relative to plans root, `content` = full markdown). Prefer MCP; CLI fallback after Preamble **#4**. Cloud agents rely on upsert for the platform copy — **git commit/push is not a substitute for the blocking upsert**. Conversely, **upsert is not a substitute for writing the local plan file** — always write (or update) the mapped path on disk **and** upsert so ChimpHands Files changed / PR review can show the plan.

**Platform fetch:** `get-plans-support-file` (`filePath` relative to plans root). Use when a prompt names an existing plan (Continue Locally / implement a `.plan.md`) so UI-edited content is used even if git is stale. If `found` is false, read the local file.

Legacy (read-only / migrate opportunistically): `knowledge/branch_test_plans/`, `knowledge/evolve_plans/`.

## Inline `agentTraceability` on mutating CRUDs (preferred)

For **`create-issue`**, **`create-user-story`**, **`create-test-scenario`**, **`update-user-story`**, **`update-test-scenario`**, and **`update-issue-status`**, pass policy/traceability **on the mutating call** via nested **`agentTraceability`** (or flat CLI flags: `--workflow-id`, `--workflow-execution-id`, `--policy-file`, `--policy-version`, `--git-sha`, `--actor-type`, `--branch-name`, `--agent-model`, `--skill-version`, `--cli-version`).

**Required for Activity attachment:** both **`workflow_id`** and **`workflow_execution_id`** (the stable Plan ULID for the whole run). Omitting `workflow_execution_id` does **not** create a workflow execution and does **not** record inline Activity — the server never auto-mints an execution id (that previously spawned orphan RUNNING rows per mutation). Pass the **same** ULID on every mutating call in the run.

The server records the same `workflow_executions` + `AGENT_WORKFLOW_ACTIVITY` rows that `report-agent-action` would — **no separate `report-agent-action` for that mutation**. Do **not** double-call (CRUD + RAA for the same CREATED/UPDATED).

Still use **`report-agent-action`** for **`mark-plan-items-implementation-done`**, **`update-plan-items-lifecycle-status`**, **`upsert-policy`**, **`upsert-plans-support-file`**, SmartTest locator actions, analyze, and **`ACTION_COMPLETED` / `ACTION_FAILED`**.

Optional **`agentModel`**: free-form model id from the agent/CLI only (`--agent-model` or `TESTCHIMP_AGENT_MODEL`). Platform backend reporters leave it unset.

**Skill + CLI versions (include on every report):** Pass **`skillVersion`** from this skill’s `SKILL.md` frontmatter `version` (`--skill-version` or `TESTCHIMP_SKILL_VERSION`). **`cliVersion`** is auto-filled by `@testchimp/cli` from its package version when omitted (`--cli-version` / `TESTCHIMP_CLI_VERSION` override). These appear on workflow execution history in the UI.

## `report-agent-action` (non-CRUD / completion)

Still use for analyze/completion and non-CRUD entities (SmartTest locator actions, `ACTION_COMPLETED` / `ACTION_FAILED`, etc.). Fields (CLI/MCP; camelCase or flags per [`cli.md`](./cli.md)):

| Field | Notes |
|-------|--------|
| `workflow_id` | Catalog id (`run-qa`, `create-tests`, …) or bootstrap id **`init`** (not a catalog card; see below) |
| `workflow_execution_id` | Stable ULID for the whole run |
| `policy_file` / `policy_version` | From resolved policy frontmatter |
| `git_sha` | Current HEAD |
| `actor_type` | `local-agent` or `cloud-agent` |
| `user_id` | Optional; from MCP env when present |
| `branch_name` | Current git branch |
| `agent_model` / nested `traceability` | Optional; agent/CLI only |
| `skill_version` | Skill `SKILL.md` frontmatter `version` (`--skill-version` / `TESTCHIMP_SKILL_VERSION`) |
| `cli_version` | `@testchimp/cli` package version (auto-filled by CLI when omitted) |
| `entity_type` | e.g. `test`, `story`, `scenario`, `issue`, `test_execution`, `batch_invocation`, `workflow` |
| `test` **or** `entityIdentity` | **Mutually exclusive** (camelCase on the wire). SmartTests → `test` TestLocator (`folderPath`, `fileName`, `testSuite`, `testName`). Other artifacts → `entityIdentity` as project-scoped **ordinal id** (readable int string). Do **not** use platform UUIDs. Exception: execution/batch ids only when the prompt explicitly provided them. |
| `action_type` | `created` / `updated` / `deleted` / `analyzed` / **`completed`** (`ACTION_COMPLETED`) / **`failed`** (`ACTION_FAILED`). Completing/failing marks the workflow execution done (`completedAtMillis`). Prefer `entity_type: workflow` for those. |

At end of every **standalone** Execute (or when aborting), report **`ACTION_COMPLETED`** or **`ACTION_FAILED`** so timelines leave `RUNNING` — see **[Report workflow execution](#report-workflow-execution)** (required gate, not optional).

**`init` (bootstrap, not catalog):** During **`/testchimp init`**, after workstation-gate **`get-eaas-config`** succeeds, best-effort report **`ACTION_COMPLETED`** with `workflow_id` / `entityIdentity` **`init`** and a fresh ULID (no policy fields). Omit `user_id` — MCP injects **`TESTCHIMP_USER_ID`** from mcp.json when set. Report failure must not block init. See [`init-testchimp.md`](./init-testchimp.md)#workstation-gate-always-first.

**First successful report** for a client-supplied `workflow_execution_id` **creates** the DB workflow execution (`execution_created: true`); later reports with that **same** id append actions. The server **requires** `workflow_execution_id` on every `report-agent-action` (no auto-mint). **`upsert-plans-support-file` alone does not create a workflow execution** — without RAA / inline `agentTraceability` (with both workflow id + execution id), the platform shows no run.

**Since last run:** **`get-last-run-workflow-detail`** (`workflow_id`, optional `branch_name`, optional `user_id`).

## Report workflow execution

**Required** before treating any **standalone** catalog workflow as done (and for composite parents like `run-qa` / `upkeep` / `implement`). Nested subflows **do not** emit their own `ACTION_COMPLETED` — the parent reuses the same ULID and closes once.

**Applies to every catalog workflow** that mints a `workflow_execution_id` (including thin playbooks: `fix-issue`, `fix-test-execution`, `cleanup`, `execute-tests`, `author-plans`, `run-explorechimp`, `connect-to-test-env`, `run-smart-smoke`, `run-requirement-quality-checks`, `instrument-truecoverage`, `create-policy`, `run-release-check`, `import`, `import-perf-tests`, …). Omitting this step leaves the platform with a plan support file but **no** `workflow_executions` row (or a stuck `RUNNING` timeline).

### Steps (blocking before “done”)

1. **Reconcile ledger** — List material mutations from this run (issue status changes, story/scenario CRUD, SmartTest create/update/delete, policy upsert, analyze, implement, …). Call **`get-workflow-execution`** with `includeActions: true` for this `workflow_execution_id` when available.
2. **Emit missing reports** — For each material mutation not already on the timeline:
   - Prefer **inline `agentTraceability`** on mutating CRUDs (`update-issue-status`, `create-issue`, story/scenario create/update) — do **not** also RAA the same CREATED/UPDATED.
   - Otherwise call **`report-agent-action`** (`CREATED` / `UPDATED` / `DELETED` / `ANALYZED` / `IMPLEMENTED` as appropriate). SmartTests use `test` TestLocator; issues/stories/scenarios use ordinal `entityIdentity` (no `US-`/`TS-`/`#B-` prefix).
3. **Close the run** — **`report-agent-action`** with:
   - `action_type`: **`ACTION_COMPLETED`** (success) or **`ACTION_FAILED`** (abort / hard failure)
   - `entity_type`: **`WORKFLOW`**
   - `entity_identity`: the catalog **`workflow_id`** (e.g. `fix-issue`, `run-qa`)
   - same `workflow_execution_id`, `workflow_id`, policy file/version (when resolved), `git_sha`, `actor_type`, `branch_name`
   - **`skill_version`** from local `SKILL.md` frontmatter (CLI auto-fills `cli_version`)

CLI sketch:

```bash
testchimp report-agent-action \
  --workflow-id fix-issue \
  --workflow-execution-id "<ulid>" \
  --action-type ACTION_COMPLETED \
  --entity-type WORKFLOW \
  --entity-identity fix-issue \
  --git-sha "$(git rev-parse HEAD)" \
  --actor-type LOCAL_AGENT \
  --branch-name "$(git branch --show-current)" \
  --skill-version "<version from SKILL.md frontmatter>"
```

**Plan-only / stop-after-upsert** (Workflow Automation first invoke): do **not** send `ACTION_COMPLETED` — no Execute yet. The Approve re-invoke owns Execute + Report.

**Failure to report:** Treat as a **workflow defect** — retry once; if still failing, tell the user the run finished locally but the platform timeline may be missing (include ULID). Do not silently skip.

## Disabled / Missing Config (agent behavior)

Workflow catalog status may be **Active**, **Disabled**, or **Missing Config**.

- **Disabled** — project intentionally turned the workflow off (e.g. TrueCoverage instrumentation). Do not run it; explain briefly and continue other subflows when in a composite.
- **Missing Config** — required policy is absent. **Blocking only for `connect-to-test-env`**: stop provisioning/authoring that needs an env; discuss with the user and author/seed **`connect-to-test-env.policy.md`** (from ai-test-instructions or [`create-policy.md`](./create-policy.md)). Dependent workflows may also show Missing Config in the UI; agents should fix connect-to-test-env first, then retry.

## Execution source (`LOCAL_AGENT` / `CLOUD_AGENT`)

Every Playwright / Mobilewright spawn from this skill must export **`TESTCHIMP_EXECUTION_SOURCE`** in the **same shell** as Preamble **#4** (with the API key). The reporter stamps ingest with this value so `fix-test-execution` automations do **not** loop on agent debug batches.

- Skill **never** exports `CI`. True pipelines / `testchimp-github-testrunner` set `TESTCHIMP_EXECUTION_SOURCE=CI`.
- **`CLOUD_AGENT`** only when this skill is running on a **remote** host: `GITHUB_ACTIONS`, `CURSOR_AGENT_WORKER_ID` (Cursor cloud worker), or Copilot platform (`COPILOT_USE_PLATFORM` / `COPILOT_WORKSPACE`). Do **not** treat `CURSOR_AGENT`, `CLAUDE_CODE`, `CODEX`, or `OPENHANDS` as cloud — those are set for **local** IDE/CLI agents. Do **not** use `CI=true` as the cloud bit.
- Otherwise **`LOCAL_AGENT`**.

```bash
export TESTCHIMP_EXECUTION_SOURCE=LOCAL_AGENT   # or CLOUD_AGENT
```

Applies to create-tests, run-qa, fix-test-execution, execute-tests, explore, and every other runner spawn.

## Authored-tests PR comment

After **final green Validate** of **new/changed** specs (standalone **create-tests** or nested under **run-qa**), post **one** PR/MR comment with a link to that TestChimp batch. Reviewers click through for steps. Do **not** dump screenshots into the comment.

### Pin the batch (Validate spawn only)

1. Mint a UUID. `export TESTCHIMP_BATCH_INVOCATION_ID=<uuid>` for **that** Playwright spawn only (the final green Validate of authored/updated specs — not every debug spawn, not Phase 5 smoke, not Phase 6 ExploreChimp).
2. After the run, scrape the **last** reporter line from **that** spawn:

`[TestChimp] Batch invocation view: <url>`

3. Keep that URL for the comment. If the line is missing (complete failed), **soft-fail** the comment — do **not** invent `prod.testchimp.io` / `app.testchimp.io`.
4. **`unset TESTCHIMP_BATCH_INVOCATION_ID`** before any later runner spawn (Phase 5, Phase 6, debug re-runs). Leaving it set reuses the authored-tests batch id.

### Upsert the comment

Do this after a PR/MR exists (create with `gh pr create` / `glab mr create` when non-interactive if needed) and **before** run-qa **Phase 7** teardown.

HTML marker (idempotent upsert): `<!-- testchimp-authored-tests:<workflow_execution_id> -->`

Body:

- Short intro: tests authored/updated in this workflow; open in TestChimp to review steps.
- The `batch_view_url` from the reporter (only).
- Optional one-line list of test titles/files (not step dumps).

**GitHub:** `pr=$(gh pr view --json number,url --jq .number)`. List comments: `gh api "repos/{owner}/{repo}/issues/$pr/comments"`. If a comment body contains the marker, `gh api -X PATCH "repos/{owner}/{repo}/issues/comments/{id}" -f body='...'`. Else `gh pr comment "$pr" --body '...'`.

**GitLab:** `glab mr note` (or equivalent) when `glab` is present; upsert by searching notes for the marker.

**Soft-fail:** no open PR/MR, no `gh`/`glab` token, or missing batch URL → note on the workflow plan; do **not** fail the workflow.

Do **not** comment from true CI pipeline runs. This is a skill/agent step after authoring Validate.

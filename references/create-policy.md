# /testchimp create policy

**Workflow id:** `create-policy`

Help the user author a version-controlled **`*.policy.md`** under **`plans/knowledge/policies/`** for a given catalog **`workflow-id`**, so agents (local or cloud) can run that workflow non-interactively.

When the user asks to create a policy, **analyze the code repo** and guide them through creating a policy that fits the **project structure** and **how the team works** — do not invent provision steps or unsupported TestChimp behaviour. Prefer a short guided Q&A over a blank stub.

## Required

1. **Explicit `workflow-id`** — one of the ids from MCP/CLI **`list-workflow-catalog`** (e.g. `connect-to-test-env`, `create-tests`, `run-qa`). If missing, ask. Optional **named file** via the prompt (`named <policy-file>`); default filename **`<workflow-id>.policy.md`**.
2. **Frontmatter** (mandatory):

```yaml
---
workflow-id: <workflow-id>
version: 1.0.0
---
```

Bump **`version`** of the policy when changing guidance so **`report-agent-action`** stays meaningful.

3. **Default filename:** prefer **`<workflow-id>.policy.md`** for the project default. Custom variants: descriptive names (e.g. `connect-to-test-env-staging.policy.md`) with the same `workflow-id` in frontmatter; invoke via **`--policy`**. Do not use another catalog workflow-id as the basename (reserved).

## Agent stance (all workflows)

1. Inspect the repo (CI config, docker-compose / deploy docs, `.env*` patterns, existing `plans/knowledge/ai-test-instructions.md`, test layout).
2. Ask clarifying questions about the **behaviour the team wants agents to adhere to** for that workflow.
3. For feasibility of product capabilities, use skill **`references/`** and [TestChimp docs](https://docs.testchimp.io/) — do not invent unsupported features.
4. Write the policy file; then **push it to the platform immediately** with CLI/MCP **`upsert-policy`** (see below). Git push later also syncs the file, but upsert makes it available on the platform right away.
5. Confirm with **`get-policy` / `list-policies`**.

### After write — platform upsert (required when API key is available)

```bash
testchimp upsert-policy \
  --policy-file-name <filename>.policy.md \
  --content-file plans/knowledge/policies/<filename>.policy.md
```

MCP tool: **`upsert-policy`** with `policyFileName` + `content`. Requires CLI ≥ **0.1.21**.

## Shared body sections

- `### Summary` — when to use this policy vs the default.
- `### Pre-Execute Workflows` / `### Post-Execute Workflows` — optional workflow-id lines (and optional `--policy`).
- `### Scoping Rules` — optional **project overrides** of the skill-wide scoping rule (explicit → feature branch → default/last-run). Do not contradict [`policies-and-traceability.md`](./policies-and-traceability.md#scoping-overarching--all-workflows); only narrow (e.g. always ignore certain paths).

Pull known answers from **`plans/knowledge/ai-test-instructions.md`** when present (especially Environment Provision Strategy) so the first policy is not blank.

---

## `connect-to-test-env` (strict expected sections)

This is the **only** policy with a strict expected checklist — it **blocks** many dependent workflows when missing. Aim to acquire answers for all three areas below, then capture them in the authored file. Skeleton: [`../assets/policies/connect-to-test-env.policy.md`](../assets/policies/connect-to-test-env.policy.md). Playbook: [`connect-to-test-env.md`](./connect-to-test-env.md). Patterns: [`environment-management.md`](./environment-management.md).

### 1. Feature-branch scoped testing

Is PR / feature-branch scoped testing needed? How to procure a test env scoped to the PR?

Typical options (pick one and document concrete steps):

- Spin up the stack **locally**
- Use an **EaaS** provider (e.g. Bunnyshell)
- Follow the team’s **custom instructions** for procurement
- **Skip support** — record explicitly in the policy that feature-branch scoped procurement is skipped, so QA processes that run on feature-branch scopes should **not attempt** connect/provision; tell the user it was skipped (they may later update the policy with details)

### 2. Default (main) branch / shared env

If the team usually tests on the **default branch** after deploying to a shared env (e.g. staging):

- How to **connect** to that test env (base URL and any auth/headers)
- Ensure **`.env-<env>`** is created/updated with **`BASE_URL`** populated for the runner

### 3. CI test executions

If the team wants test executions in **CI**, how are test environments procured on CI?

- Spin up on cloud / runner?
- Use EaaS?
- Connect to a shared test env (**discouraged** — prefer ephemeral or dedicated CI envs)

### Recommended headings for `connect-to-test-env`

```markdown
### Summary
### Pre-Execute Workflows
### Post-Execute Workflows
### Scoping Rules

## Local Agent

### When on a feature branch
### When on default branch

## CI / Cloud
```

Do **not** invent complex playbook logic — record the team’s choices so agents can follow them non-interactively.

---

## Other workflows

Ask relevant questions about agent **adherence** for that workflow, then write the policy accordingly. Examples:

- **`run-explorechimp`** — common issue types that should not be captured; areas to focus more thoroughly on; screens/paths to skip.
- **`create-tests` / `run-smart-regression`** — naming, folder conventions, mocks vs live, flaky-test handling.
- **`cleanup`** — aggressiveness, retention, paths never to delete.
- Composites (**`run-qa` / `upkeep`**) — which subflows to include/skip and order overrides (see default assets).

When the user asks about what is possible, check skill references and [docs.testchimp.io](https://docs.testchimp.io/) before promising behaviour.

## See also

- [`policies-and-traceability.md`](./policies-and-traceability.md) — resolution and ULID / `report-agent-action`
- [`cli.md`](./cli.md) — `upsert-policy`, `get-policy`, `list-policies`

# /testchimp create policy

**Workflow id:** `create-policy`

Help the user author a version-controlled **`*.policy.md`** under **`plans/knowledge/policies/`** for a given catalog **`workflow-id`**, so agents (local or cloud) can run that workflow non-interactively.

## Required

1. **Explicit `workflow-id`** — one of the ids from MCP/CLI **`list-workflow-catalog`** (e.g. `connect-to-test-env`, `create-tests`, `run-qa`). If missing, ask.
2. **Frontmatter** (mandatory):

```yaml
---
workflow-id: <workflow-id>
version: 1.0.0
---
```

Bump **`version`** of the policy when changing guidance so **`report-agent-action`** stays meaningful.

3. **Default filename:** prefer **`<workflow-id>.policy.md`** for the project default. Custom variants: descriptive names (e.g. `connect-to-test-env-staging.policy.md`) with the same `workflow-id` in frontmatter; invoke via **`--policy`**.

## Recommended body (keep thin)

- `### Summary` — when to use this policy vs the default.
- `### Pre-Execute Workflows` / `### Post-Execute Workflows` — optional workflow-id lines (and optional `--policy`).
- `### Scoping Rules` — optional **project overrides** of the skill-wide scoping rule (explicit → feature branch → default/last-run). Do not contradict [`policies-and-traceability.md`](./policies-and-traceability.md#scoping-overarching--all-workflows); only narrow (e.g. always ignore certain paths).
- Workflow-specific sections — e.g. for **`connect-to-test-env`**: Local Agent vs CI/Cloud; feature-branch ephemeral vs shared env; commands, health waits, URL → `BASE_URL` mapping.

Pull known answers from **`plans/knowledge/ai-test-instructions.md`** when present (especially Environment Provision Strategy) so the first policy is not blank.

## Agent stance

- Ask only the clarifying questions needed for **non-interactive** runs; do not invent complex playbook logic.
- After write, confirm path and that **`get-policy` / `list-policies`** can see it once synced.
- Point at [`policies-and-traceability.md`](./policies-and-traceability.md) for resolution and ULID / `report-agent-action`.

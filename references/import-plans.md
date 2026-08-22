# /testchimp import plans

One-off workflow to import existing requirement / plan markdown into the mapped **`plans/`** tree.

## When to use

- During **`/testchimp project init`** when the team has existing specs outside TestChimp layout.
- Standalone: **`/testchimp import plans <folder>`** (synonym: **`/testchimp import plans`** with path in prompt).

## Plan → approve → execute

Same contract as other catalog workflows: ULID `workflow_execution_id`, plan file under **`plans/knowledge/workflow_plans/import-plans/<id>.plan.md`**, **`upsert-plans-support-file`**, user approval, then execute.

## Execute highlights

1. Inventory source folder; map files into `plans/stories/`, `plans/scenarios/`, or `plans/knowledge/` per [`author-plans.md`](./author-plans.md).
2. Normalize YAML frontmatter and scenario/story ordinals where possible.
3. Open a PR (branch prefix **`testchimp-`**) — do not rely on platform sync PR for agent-authored imports.
4. On success, **`update-project-init-status`** with `import_plans: DONE` when run under project init.

Nested under project init counts as **one approval** with the parent plan when user agrees.

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
3. Suggest a commit / PR (branch prefix **`testchimp-`**) — do not rely on platform sync PR for agent-authored imports, and do not block remaining init steps on a merge.
4. On success, **`update-project-init-status`** with `import_plans: PROJECT_INIT_ITEM_STATUS_DONE` when run under project init. Use the **full** enum (never short `DONE`). Verify the returned status reflects the update.

Nested under project init counts as **one approval** with the parent plan when user agrees.

## Platform plans present, local folders empty

If the platform already has plans (`import_plans` is **`PROJECT_INIT_ITEM_STATUS_DONE`**, or **`get-requirement-coverage`** / **`list-test-scenarios-for-scope`** then **`get-user-stories`** / **`get-test-scenarios`** return stories/scenarios) **but** the mapped **`plans/stories`** and **`plans/scenarios`** trees have no `.md` files:

1. **Tell the user** — plans live on the TestChimp project, this checkout does not have the local files. Do **not** silently skip, and do **not** re-create them with **`create-user-story`** / **`create-test-scenario`**.
2. **Offer to pull them down** into the mapped plan folders.
3. If they agree:
   - Discover ordinals: **`list-test-scenarios-for-scope`** `--plans-path plans/scenarios` (and `plans/stories` if needed) and/or **`get-requirement-coverage`** (nested `userStories` / `unmappedScenarios`).
   - Fetch markdown: **`get-user-stories`** / **`get-test-scenarios`** for those ordinals.
   - **Write** each returned **`content`** to **`platformFilePath`** under the mapped plans root (keep `id:` / `story:`). Create parent directories as needed.
4. If they decline, record the skip in the plan and continue. Do not invent local stubs.

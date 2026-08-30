# /testchimp author plans


> **Plan → approve → execute → report (gap / multi-artifact runs):** When this workflow runs **standalone** and the prompt does **not** name a specific existing story/scenario ordinal, write `knowledge/workflow_plans/author-plans/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). **Plan** drafts the stories/scenarios to author (titles, paths, brief intent) — do **not** create platform entities or write story/scenario files until **Execute**. Story/scenario create/update carry **inline `agentTraceability`**. Before finishing standalone, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `author-plans`). Nested under a composite: reuse the parent plan (parent closes). See [`policies-and-traceability.md`](./policies-and-traceability.md).

> **Exception — scoped to an existing ordinal:** If the prompt names a specific **`US-<n>`** or **`TS-<n>`** (e.g. `/testchimp author plans for US-118`, `author plan TS-107`, **`scope out US-212`**, “flesh out US-42”), the work is **scoping / writing up that existing file** — **skip** the meta `workflow_plans/author-plans/*.plan.md` gate. Load the story/scenario, clarify with the user as needed, use repo code context, then update the file + platform. Still mint/reuse a ULID for traceability and **report** completion. See [Scoped write-up (named ordinal)](#scoped-write-up-named-ordinal).

**Synonym:** `/testchimp plan` and **`/testchimp scope out`** (same workflow **`author-plans`**). Use **`scope out US-<n>`** / **`scope out TS-<n>`** when the story or scenario already exists and the user wants to flesh out details (acceptance criteria, edge cases, open questions) — typical when handing off from the Plans viewer.

This document explains how to **read and author** TestChimp **markdown test plans** in the mapped **`plans/`** folder. For SmartTests and scenario **`annotation`** links from code, see **[`write-smarttests.md`](./write-smarttests.md)**.

**Ids (hard rules — BLOCKING):**
- **Never hallucinate** **`US-…`** or **`TS-…`** ids (the ordinals are TestChimp-generated, not freetext).
- **Never create** (even temporarily) story/scenario markdown files with a **blank `id:`**, and **never omit `id:`** from frontmatter. Omitting `id` is the same class of bug as inventing one.
- **Always provision first via MCP / CLI** (`create-user-story` / `create-test-scenario`) to get the real **`ordinalId`**, **then** write the markdown file with **`id: US-…`** / **`id: TS-…` already populated** in the **first** on-disk version.
- **Do not** treat “I linked `story: US-…`” as sufficient for a new scenario — scenarios still need a platform-issued **`id: TS-…`**.
- **Sequential creates only:** Never parallelize **`create-user-story`** / **`create-test-scenario`**. One create → await response → next create. Parallel tool calls can race and return the **same** `ordinalId`.
- **Duplicate ordinal self-check:** After multiple creates in one Execute turn, confirm every returned **`ordinalId`** is unique. On duplicates: do **not** write files; stop and report **`ACTION_FAILED`** (platform allocation error) with the colliding ids.

### Forbidden patterns (agents fail these often)

| Forbidden | Required instead |
|-----------|------------------|
| `Write` a new `plans/scenarios/**/*.md` with only `type` / `title` / `story` (no `id`) | `create-test-scenario` → write with `id: TS-<ordinalId>` + `story: US-<n>` → `update-test-scenario` |
| `Write` a new `plans/stories/**/*.md` without `id: US-…` | `create-user-story` → write with `id: US-<ordinalId>` → `update-user-story` |
| Invent `TS-999` / copy an id from an unrelated file | Use only the **`ordinalId`** returned by create (or an id already present from platform sync) |
| “I’ll add the id after the user reviews the draft file” | Draft titles/paths in the **Plan**; provision + write with id only in **Execute** after approval |
| Create **new** stories/scenarios during Plan (before approval) | Plan lists proposed titles/paths only; MCP create + local write happen in **Execute** |
| Meta-plan gate when the prompt already names `US-<n>` / `TS-<n>` | Skip meta plan; write up that existing file directly ([scoped write-up](#scoped-write-up-named-ordinal)) |
| Parallel `create-test-scenario` / `create-user-story` tool calls | Sequential: create → await → write (optional) → next create; then duplicate-`ordinalId` self-check |

**Why this matters:** Git → platform sync **rejects** story/scenario imports that lack canonical `id:` frontmatter, so id-less files reappear forever as “incoming” diffs and never apply. Creating **new** entities before approval also commits ordinals the user may reject.

**ChimpHands Files changed:** For gap/multi-artifact runs, always **write the workflow plan file on disk** under the mapped plans tree (then upsert) so the session **Files changed** pane shows it while awaiting approval. During Execute (or scoped write-up), write each story/scenario file locally too (not upsert-only).

Further reading: [Test planning as code](https://docs.testchimp.io/test-planning/intro) (philosophy, Git export, default-branch scope for plans).

---

## What lives under `plans/`

On the **TestChimp platform**, the test plan tree is rooted at **`plans`** (even if your repo folder is named differently—e.g. `ui/plans`). API and MCP calls always use **platform paths** starting with `plans/...`.

Typical layout:

```text
plans/
  knowledge/     # Optional: markdown knowledge base (indexed for planning assistance)
  stories/       # User stories (*.md), optional subfolders by area or team
  scenarios/     # Test scenarios (*.md), optional subfolders
```

When user syncs the plans folder from TestChimp platform to Git repo, a `.testchimp-plans` file is created in the mapped folder. This can be used to identify the mapped folder correctly. Note that glob might not find files starting with dot, so use find / ls tools instead.

**Branch scope:** Test planning is **project-level**, not tied to a Git branch. SmartTests and runs are branch-aware; **stories and scenarios are a single product-level plan** (default branch source of truth).

---

## Markdown shape: YAML frontmatter + body

Each story or scenario is a **`.md` file** with a **YAML frontmatter** block between `---` lines, then markdown body.

### User story (`plans/stories/...`)

- **`type: story`** (recommended in frontmatter)
- **`id: US-<n>`** — human-readable id; **`n`** is the project **ordinal** (integer). Example: `id: US-118`
- **`title:`** — short natural-language title
- Common optional fields (when present in project config): **`priority`**, **`status`**, **`labels`**, **`created_date`**, **`due_date`**, **`blocked_by`**
- **Body** — free markdown (often “Summary”, acceptance criteria, notes)

### Test scenario (`plans/scenarios/...`)

- **`type: scenario`**
- **`id: TS-<n>`** — scenario ordinal. Example: `id: TS-107`
- **`title:`** — short natural-language title
- **`story: US-<m>`** — links the scenario to its **parent user story** (ordinal **`m`**). Some tools may accept a bare numeric story ordinal; prefer **`US-<m>`** in files.
- Same optional lifecycle fields as stories where configured.
- **Body** — often structured sections (e.g. Prerequisites, Test Steps, Expected Behaviour) as generated by the platform.
- **Verification strategy** is **not** in markdown frontmatter. It lives in platform lifecycle (`lifecycleFields.verification_strategy` on MCP/CLI wire; `auto` | `manual`, default `auto`). When deciding whether to author SmartTests, fetch it via **`get-spec-lifecycle-details`** (see [`create-tests.md`](./create-tests.md)) — skip **`manual`** scenarios.

**Reading tips:** The **folder path** (e.g. `plans/stories/checkout/`) gives feature context. **Sibling files** show related coverage. **`story:`** on a scenario tells you which user story it validates.

**Fetching from the platform:** Use **`get-test-scenarios`** with **`scenarioOrdinalIds`** (numeric parts of **`TS-<n>`**) and **`get-user-stories`** with **`userStoryOrdinalIds`** (numeric parts of **`US-<n>`**). Each returns full plan **markdown** (`content`), **title**, **platformFilePath**, and (for scenarios) **userStoryOrdinalIds** for linked stories. Use this when authoring tests from a platform **Create Test → Copy test generate prompt** flow. For lifecycle maps (including **`verification_strategy`**), use **`get-spec-lifecycle-details`** instead of reading frontmatter.

---

## Linking SmartTests to scenarios

In Playwright specs, link to a scenario ordinal with a Playwright **`annotation`** on the test options (see **`write-smarttests.md`**):

```js
test('empty messages cannot be sent', {
  annotation: [
    { type: 'scenario', description: '#TS-107' },
  ],
}, async ({ page }) => {
  // steps
});
```

Use the **`#TS-<n>`** from the scenario markdown **`id`**. `description` is **only** that id — no title text. Do **not** author deprecated `// @Scenario:` comments.

---

## Authoring new stories and scenarios (MCP)

Creating a file **only on disk** is **not** enough — and is **wrong** if done before create: the TestChimp project needs **entities** with real ordinals, and the repo file must carry that ordinal from the first byte written. Use MCP tools first (CLI fallback) in this **order**:

### Stories

1. **`create-user-story`** — pass **`platformFilePath`** (e.g. `plans/stories/area/my-feature.md`) and **`title`**. Response includes **`ordinalId`** and **`content`** (canonical stub markdown that already has **`id: US-<ordinalId>`**).
2. **Write** that **`content`** to the repo’s mapped plans path (edit the body as needed; **keep `id:`**). Do not invent frontmatter from scratch.
3. **`update-user-story`** — pass the **full file contents** so the platform stays in sync. **Rejects** markdown missing **`id: US-<n>`** with an actionable error.

### Scenarios

1. Ensure the **parent story** exists and you know its **`US-<n>`** (create the story first if needed).
2. **`create-test-scenario`** — **`platformFilePath`** under `plans/scenarios/...`, **`title`**, **`userStoryOrdinalId`** = **`n`**. Response includes **`ordinalId`** and **`content`** (stub already has **`id: TS-<ordinalId>`** and **`story: US-<n>`**). **Do not skip this call.** **Do not** fire multiple creates in parallel — await each response before the next.
3. **Write** that **`content`** locally (edit body; **keep `id:` and `story:`**).
4. **`update-test-scenario`** with **full markdown**. **Rejects** missing **`id: TS-<n>`** or **`story: US-<n>`** with an actionable error (tells you to call create first).
5. After several creates: confirm **`ordinalId`**s are unique before writing remaining files; on collision, fail the workflow (do not write).

### Pre-write checklist (run before every `Write` to stories/scenarios)

- [ ] `create-user-story` / `create-test-scenario` already returned **`ordinalId`** in this session (or the file already exists with a valid `id:` from platform).
- [ ] Creates in this turn were **sequential** (not parallel), and all returned **`ordinalId`**s in the batch are **unique**.
- [ ] Frontmatter includes **`id: US-<ordinalId>`** or **`id: TS-<ordinalId>`** (non-empty).
- [ ] Scenario frontmatter includes **`story: US-<n>`** for the parent.
- [ ] Immediately after write: call **`update-*-*`** with full content (or schedule it in the same turn before finishing).

**Filenames:** Prefer **kebab-case** and **`.md`**. **Titles** are short sentences; filenames are stable identifiers.

If **`story:`** (or the parent link) changes on a scenario, call **`update-test-scenario`** so the platform updates **DB linking**, not only file text.

- The story files should ALWAYS be created under a subfolder under `<PLANS_ROOT>/stories/`.
- The scenario files should ALWAYS be created under a subfolder under `<PLANS_ROOT>/scenarios/`.

---

## Mode selection (run this first)

| Prompt signal | Mode |
|---------------|------|
| Names a specific **`US-<n>`** and/or **`TS-<n>`** ordinal (optionally with path/title) | **[Scoped write-up](#scoped-write-up-named-ordinal)** — skip meta plan |
| Objective / area / “fill gaps” / no ordinal (or only a folder scope) | **[Gap-driven planning](#testchimp-plan-playbook-gap-driven-planning)** — Plan → approve → Execute |
| Nested under run-qa / upkeep | Reuse parent plan; do not start a second meta-plan cycle |

Recognize ordinals in any common form: `US-118`, `us-118`, `#US-118`, `story US-118`, `TS-107`, `#TS-107`, **`scope out US-118`**, **`scope out TS-107`**. If both a story and scenario are named, prefer writing the scenario (and keep the parent story consistent if needed). If the named ordinal **does not exist** on the platform / in the mapped tree, say so and either fall back to gap-driven planning (propose creating it) or ask the user — do **not** invent the id.

---

## Scoped write-up (named ordinal)

When the user already pointed at an existing story or scenario, the file is the scope — a secondary workflow plan adds no value.

1. **Resolve the target** — Mint (or reuse) a ULID `workflow_execution_id` for traceability. Fetch via **`get-user-stories`** / **`get-test-scenarios`** (ordinal ids) and/or locate the mapped markdown (`id: US-<n>` / `id: TS-<n>`). Prefer platform content when it diverges from a stale local file; write the chosen body to the mapped path before editing if needed.
2. **Clarify with the user** — Ask what’s missing (acceptance criteria, edge cases, actors, env, out-of-scope). Do **not** invent product behavior the user has not confirmed when the stub is thin.
3. **Ground in the repo** — Use relevant code, APIs, UI routes, fixtures, and nearby stories/scenarios so the write-up matches how the product actually works.
4. **Update the file** — Edit the markdown body (keep frontmatter **`id:`** / **`story:`** intact). Call **`update-user-story`** / **`update-test-scenario`** with full content + **inline `agentTraceability`**.
5. **Report** — Standalone: **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `author-plans`). Nested: parent closes.

Do **not** write `knowledge/workflow_plans/author-plans/<ulid>.plan.md` or pause for meta-plan approval in this mode.

---

## `/testchimp plan` playbook (gap-driven planning)

When the user asks for **`/testchimp plan`** (or equivalent: fill gaps in the test plan, add missing stories/scenarios) **without** naming a specific existing `US-` / `TS-` ordinal:

1. Call **`get-requirement-coverage`** with a **`scope.folderPath`** under **`plans`** (e.g. `["plans","stories","checkout"]` or `["plans","scenarios"]`) and set **`includeNonCoveredUserStories`** / **`includeNonCoveredTestScenarios`** as needed.
2. From the response and the recent changes made in the current working branch, decide **missing or thin** stories and scenarios.
3. **Plan (before any create):** Write `knowledge/workflow_plans/author-plans/<workflow_execution_id>.plan.md` listing proposed titles/paths (and brief intent). **Write on disk**, then **`upsert-plans-support-file`** (blocking). Seek approval. Do **not** call `create-user-story` / `create-test-scenario` or write story/scenario markdown until approved.
4. **Execute (after approval):** **Create parent stories before scenarios.** For each new artifact: **MCP create → write file with `id:` already set → MCP update**. Never write story/scenario markdown that omits `id:`. Write on disk under the mapped plans root so ChimpHands **Files changed** / branch CI can show the file.
5. Keep edits **reviewable**: minimal frontmatter, clear titles, consistent folder placement.
6. Make sure that created stories and scenarios are created under sub-folders for better organization. Not directly under the `plans/stories` or `plans/scenarios` but in a sub-folder within those - based on the the relevant area the story / scenario affects.
7. **Standalone only:** **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — **`ACTION_COMPLETED`** with `WORKFLOW` + `author-plans` (nested under run-qa / upkeep: parent closes).

---

## Related references

- **[`SKILL.md`](../SKILL.md)** — command routing and MCP tool list.
- **[`write-smarttests.md`](./write-smarttests.md)** — SmartTests, coverage MCP, scenario **`annotation`** links, platform vs repo paths for **`tests/`**.
- **[`upkeep.md`](./upkeep.md)** — `/testchimp evolve`: **Analyze → Plan → Execute** with phase gates; persisted plans under `<MAPPED_PLANS_ROOT>/knowledge/workflow_plans/upkeep/<workflow_execution_id>.plan.md`.

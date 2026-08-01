---
workflow-id: implement
version: 1.0.4
---

### Summary

Default Implement Requirement policy. Guides agents implementing a user story,
scenario, or **finetuned plan file** (`/testchimp implement <id|path>`): analyze
related scenarios, break work into `TASK_ISSUE`s (story/scenario-linked when
ids are known; severity + category + `TestChimp Implement` label), implement,
mark tasks `FIXED` as they complete, self-review, report `IMPLEMENTED`, set
lifecycle status, then complete the workflow execution.
Override with project coding standards, out-of-scope rules, and any required
review checks.

### Scoping Rules

Primary input is required: **story id**, **scenario id**, or a **plan file path**
(no auto-scope to branch diff). Plan files take priority when supplied. Resolve
story from plan frontmatter (`story: US-n` / `userStoryOrdinalId`) or body
fallback; related scenarios = those whose frontmatter `story:` matches the parent
story id. See skill `references/implement-requirement.md` and
`references/policies-and-traceability.md`.

### Pre-Execute Workflows

### Post-Execute Workflows

### Post-implement lifecycle status

ready

<!-- Allowed: draft | ready | in progress | blocked | done | archived | skip -->
<!-- Default ready = implementation finished, ready for QA. Use skip to leave status unchanged. -->

### Implementation notes

- Prefer minimal diffs; match existing module style and patterns.
- Do not invent story/scenario ordinals; use platform ids only.
- **Plan file input:** When the user points at a plan `.md`, adopt it as the Plan
  baseline (do not rewrite from scratch). Prefer its task titles and scope.
  Asking to implement that plan counts as Plan approval of its content.
- **Task issues (required):** In Plan, break work into concrete task titles with
  **priority** (`critical`/`high`/`medium`/`low`) and **category** (BugCategory
  enum). Do not call `create-issue` before Plan approval, unless the user already
  asked to implement a supplied plan. After approval, for each task call
  `create-issue` with `issueType: TASK_ISSUE`, `labels: ["TestChimp Implement"]`
  (do **not** use `source: testchimp-implement`), `severity` mapped from priority
  (`critical`→`CRITICAL_SEVERITY`, `high`→`HIGH_SEVERITY`, `medium`→`MEDIUM_SEVERITY`,
  `low`→`LOW_SEVERITY`; default `MEDIUM_SEVERITY`), `category` from the Plan
  (default `FUNCTIONAL`), plus workflow traceability. **When a story ordinal is
  known**, pass `linkTargets` including `{ toEntityType: STORY, toEntityId: <storyOrdinal> }`.
  **When scenario ordinal(s) are in scope**, also include
  `{ toEntityType: SCENARIO, toEntityId: <scenarioOrdinal> }` for each. When neither
  story nor scenario id is resolvable, omit `linkTargets` and note that on the
  checklist. As each task’s code work completes, call `update-issue-status` with
  `FIXED`. Abandoned tasks need checklist `N/A` + justification — do not leave
  them silently `ACTIVE`.
- After `IMPLEMENTED` reports: call `update-plan-items-lifecycle-status` once per
  finished story/scenario with the status above (unless `skip`).
- Before finishing: Report workflow execution (reconcile ledger → missing
  `report-agent-action` → `ACTION_COMPLETED` with `WORKFLOW` + `implement`).

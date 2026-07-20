---
workflow-id: implement
version: 1.0.1
---

### Summary

Default Implement Requirement policy. Guides agents implementing a user story or
scenario (`/testchimp implement <story/scenario id>`): analyze related scenarios,
plan code changes, implement, self-review, report `IMPLEMENTED`, set lifecycle
status, then complete the workflow execution. Override with project coding
standards, out-of-scope rules, and any required review checks.

### Scoping Rules

Explicit story/scenario id from the prompt is required (no auto-scope to branch
diff). Related scenarios = those whose frontmatter `story:` matches the parent
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
- After `IMPLEMENTED` reports: call `update-plan-items-lifecycle-status` once per
  finished story/scenario with the status above (unless `skip`).
- Before finishing: Report workflow execution (reconcile ledger → missing
  `report-agent-action` → `ACTION_COMPLETED` with `WORKFLOW` + `implement`).

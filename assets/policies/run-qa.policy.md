---
workflow-id: run-qa
version: 1.0.0
---

### Summary

Default Run QA composite policy. Runs the standard QA subflows for the given scope:
author plans, connect to test environment, create tests (including autonomous
`@testchimp/playwright` upgrade when behind), run smart smoke,
run ExploreChimp, and instrument TrueCoverage.

When `k6/journeys` exists, Phase 5 also writes
`plans/smart-smoke/<branch>/related-perf-tests.json` (sibling of
`related-tests.json`) so CI `k6/scripts/run.sh --impacted` can smoke the
affected journeys. Nested `create-perf-tests` is opt-in (ask, default No).
Do not execute load/volume k6 inside run-qa. Merge-gate CI should skip
(or set `PERF_IMPACTED_STRICT=1`) when the file is missing — portable
`--impacted` otherwise falls through to all journeys.

### Scoping Rules

Use the skill-wide rule (explicit scope → feature-branch changes → default branch since last `run-qa` / ask user). See skill `references/policies-and-traceability.md`.

### Subflows

- author-plans
- connect-to-test-env
- create-tests
- run-smart-smoke
- run-explorechimp
- instrument-truecoverage

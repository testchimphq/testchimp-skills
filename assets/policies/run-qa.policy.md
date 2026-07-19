---
workflow-id: run-qa
version: 1.0.0
---

### Summary

Default Run QA composite policy. Runs the standard QA subflows for the given scope:
author plans, connect to test environment, create tests, run smart regression,
run ExploreChimp, and instrument TrueCoverage.

### Scoping Rules

Use the skill-wide rule (explicit scope → feature-branch changes → default branch since last `run-qa` / ask user). See skill `references/policies-and-traceability.md`.

### Subflows

- author-plans
- connect-to-test-env
- create-tests
- run-smart-regression
- run-explorechimp
- instrument-truecoverage

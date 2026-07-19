---
workflow-id: upkeep
version: 1.0.0
---

### Summary

Default Upkeep composite policy. Maintains the test suite by authoring plans,
connecting to the test environment, fixing coverage gaps, running ExploreChimp,
cleaning up obsolete/duplicate tests, and instrumenting TrueCoverage.

### Scoping Rules

Use the skill-wide rule (explicit scope → feature-branch changes → default branch since last `upkeep` / ask user). See skill `references/policies-and-traceability.md`.

### Subflows

- author-plans
- connect-to-test-env
- fix-coverage-gaps
- run-explorechimp
- cleanup
- instrument-truecoverage

---
policy-kind: global
version: 1.0.0
---

## Coverage target

- percent: 80
- lifecycle_status: ready

## Prioritization signals

- scenario_priority: true
- semantic_coverage: true
- api_contract_coverage: false
- real_user_behaviour_coverage: false

## Test suite management

- max_full_suite_duration_minutes: 120
- max_test_count: 0
- max_new_tests_per_workflow_execution: 0
- annotations:
  - type: group
    value_mode: fixed
    values: [smoke, regression]
    instructions: |
      Use smoke for critical path checks run on every PR.
      Use regression for broader suite coverage outside smoke.

## Notes for agents

When running run-qa / create-tests / upkeep, honor coverage target, prioritization
signals, and suite size limits above. Prefer get-suite-execution-stats for bloat
checks; if over or within ~10% of a non-zero cap, inform the user (soft hint).
For top-N requirement gaps, expand lifecycle_status into get-requirement-coverage
--lifecycle-statuses (ready → ready; draft/Draft+ → draft,ready) plus consider_*
flags and --limit; prefer rankedScenarios (server returns gaps only). Weighted
coverage when scenario_priority is true: high=5, medium=3, low=1; coverage % =
covered_points / total_points.
0 means unlimited for max_full_suite_duration_minutes, max_test_count,
and max_new_tests_per_workflow_execution.

When authoring or updating SmartTests, read `annotations:` above and add matching
Playwright annotations on each test (`type` + `description` value) using that
entry's instructions — e.g. `{ type: 'group', description: 'smoke' }` alongside
scenario links. Do not invent types or fixed values outside this list.

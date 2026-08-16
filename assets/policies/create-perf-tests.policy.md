---
workflow-id: create-perf-tests
version: 1.0.0
allow-execute-without-approval: false
---

### Summary

Project-specific authoring rules for new k6 journeys and composites.
This policy supplies defaults; TestChimp/TrueCoverage signals only select and
relatively weight candidates.

### Scoping Rules

Use explicit files first, then branch impact, then last `create-perf-tests`
run. Ask before adding a journey to any composite.

## Environment and LLM

- llm_default: mock
- llm_mock_latency_profile: mocked-standard
- real_llm_requires_explicit_approval: true
- do_not_silently_install_aimock: true
- isolated_environment_required_for_load_volume: true
- external_dependencies_default: stubbed
- zero_latency_stubs_allowed: false
- real_external_requires_explicit_approval: true
# On create: inventory every SUT outbound dep; mock in harness with realistic
# latency (see references/perf-testing.md § External dependencies).

## Authoring defaults

```yaml
smoke:
  max_vus: 1
  max_duration: 30s
volume:
  max_vus: 1
  staircase_pct: [10, 50, 100]
  step_duration: null
load:
  # Peak concurrent users at the top of the ramping-vus stages (not a
  # constant VU count from t=0).
  default_vus: 10
  think_time_sec: 1
  ramp_step: 30s
  hold_at_peak: 1m
  min_identities_per_vu: 1
```

Load/volume absolute settings stay `null` until the user/team fills
`run-perf-tests.policy.md`. Do not derive values from production observations.

At Plan, recommend **volume** tests for list/search/report/history/export
and large-tenant paths; confirm with the user before authoring.

## Composite membership

Non-interactive default: isolated journeys only. Membership changes require an
explicit plan prompt and approval.

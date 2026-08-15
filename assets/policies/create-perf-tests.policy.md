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
load:
  default_vus: 10
  min_identities_per_vu: 1
```

Load/volume absolute settings stay `null` until the user/team fills
`run-perf-tests.policy.md`. Do not derive values from production observations.

## Composite membership

Non-interactive default: isolated journeys only. Membership changes require an
explicit plan prompt and approval.

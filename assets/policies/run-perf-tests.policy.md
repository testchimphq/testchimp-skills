---
workflow-id: run-perf-tests
version: 1.0.0
allow-execute-without-approval: false
---

### Summary

Project-specific safety and repeatability decisions for k6 performance runs.
This policy supplies limits; TestChimp/TrueCoverage signals only select and
relatively weight journeys.

### Scoping Rules

Use explicit files first, then the generated related-perf selection for branch
changes. Ask before running a composite not named in the approved plan.

## Environment safety

- allowed_environment: <!-- isolated perf/staging environment name -->
- base_url_source: <!-- variable or connect-to-test-env output -->
- health_check: <!-- command/URL and expected result -->
- production_allowed: false
- owner: <!-- team/person approving load -->
- abort_command: <!-- deterministic emergency stop -->

## Approved profile limits

```yaml
smoke:
  max_vus: 1
  max_duration: 30s
load:
  max_vus: null
  max_rps: null
  max_duration: null
volume:
  max_vus: 1
  max_duration: null
  max_records_per_tenant: null
```

`null` means **not configured**, not unlimited. Load/volume must stop until the
user/team supplies values. Do not derive values from production observations.

## Data lifecycle

- seed_command: <!-- command or SEED_URL contract -->
- teardown_command: <!-- required for generated state -->
- namespace: <!-- perf-test namespace/prefix -->
- permitted_dataset_manifests:
  - k6/datasets/load.example.json
  - k6/datasets/volume.example.json

## Dependency modes

- llm_default: mock
- llm_mock_latency_ms: 250
- llm_mock_jitter_ms: 0
- llm_mock_error_rate: 0
- real_llm_requires_explicit_approval: true
- external_dependencies_default: stubbed
- zero_latency_stubs_allowed: false
- real_external_requires_explicit_approval: true
- external_dependencies:
  # - name: <!-- payment | email | idp | partner-api | … -->
  #   mode: stubbed  # stubbed | real (real needs approval)
  #   harness: <!-- env WireMock/stub service | k6/lib/mock-external.js -->
  #   latency_ms: <!-- realistic p50-class; not 0 for load/volume -->
  #   jitter_ms: 0
  #   error_rate: 0
  #   latency_evidence: <!-- REAL E2E timing | ops telemetry | documented typical -->
  []

## Baseline and comparison

- baseline_environment: <!-- must match run -->
- require_matching_profile: true
- require_matching_dataset: true
- require_matching_llm_mode: true
- require_matching_dependency_mocks: true
- threshold_changes_require_approval: true

## Composite membership

Agents must prompt for every add/remove/weight change. Relative weights do not
authorize absolute concurrency or arrival rate.

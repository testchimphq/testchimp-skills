---
workflow-id: upkeep-perf
version: 1.0.0
allow-execute-without-approval: false
---

### Summary

Project-specific maintenance rules for existing k6 journeys, composites,
datasets, and thresholds.

### Scoping Rules

Use explicit files first, then branch impact, then changes since the last
`upkeep-perf` run. Related selection is a candidate list, not an automatic run
list. When API runtime observations are available, rank fresh high-p95/p99
operations with missing/stale journey coverage first, then high-volume and
high-error operations. Missing observations are unknown, not zero.

## Comparison

- require_matching_profile: true
- require_matching_dataset: true
- require_matching_llm_mode: true
- threshold_changes_require_approval: true
- missing_baseline_is_incomparable: true

## LLM and environment

- llm_default: mock
- real_llm_requires_explicit_approval: true
- do_not_silently_install_aimock: true
- isolated_environment_required_for_load_volume: true
- require_matching_dependency_mocks: true
- zero_latency_stubs_allowed: false
# Re-audit outbound deps on touched journeys; keep realistic stub latencies.
# Production runtime observations select operations only; never derive load,
# thresholds, SLOs, or direct regression claims against unmatched k6 runs.

## Composite membership

Agents must prompt for every add/remove/weight change. Relative weights do not
authorize absolute concurrency or arrival rate.

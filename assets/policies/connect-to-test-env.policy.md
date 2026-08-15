---
workflow-id: connect-to-test-env
version: 1.0.0
---

### Summary

How this project procures and connects to test environments for create-tests, smart smoke, ExploreChimp, and related flows.

### Pre-Execute Workflows

### Post-Execute Workflows

### Scoping Rules

Use the skill-wide rule (explicit scope → feature-branch changes → default branch). Narrow here only if needed.

## Local Agent

### When on a feature branch

<!-- Pick one: local spin-up | EaaS (e.g. Bunnyshell) | custom instructions | SKIP (do not attempt feature-scoped QA env procurement; tell the user it was skipped) -->

### When on default branch

<!-- Shared env (e.g. staging): how to connect; ensure .env-<env> has BASE_URL -->

## CI / Cloud

<!-- How CI procures env: cloud spin-up | EaaS | shared (discouraged) -->

## Performance testing (when enabled)

<!--
Required before load/volume (smoke may remain allowed):
- isolated load-safe target + health check (production denied by default)
- owner-approved max VUs/RPS/duration/data cardinality
- seed + teardown contract and namespace
- rate-limit/autoscaling/cost protections, observability, abort command
- external dependency modes; LLM defaults to deterministic mock

Do not derive absolute load from TestChimp/TrueCoverage observations.
-->

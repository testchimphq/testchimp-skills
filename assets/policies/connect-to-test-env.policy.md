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

<!--
REQUIRED for ChimpHands / GITHUB_ACTIONS agents — concrete on-runner (or EaaS MCP) bring-up:

1. Commands to start the stack ON THIS RUNNER (or provision via EaaS), health checks, BASE_URL / backend URLs
2. Env vars for Playwright/Mobilewright (same contract as Local Agent when applicable)
3. Teardown notes if needed

ALSO document (separately) how merge-gate / PR check workflows procure env — do NOT tell agents to
`gh workflow run` those checks as a substitute for (1). ChimpHands is already on a runner; it must
follow (1) then use that stack for create-tests / execute / fix failures.

Update this section when bring-up learnings change; bump version + upsert-policy.
-->

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

---
workflow-id: connect-to-test-env
version: 1.0.0
---

### Summary

How this project procures and connects to test environments for create-tests, smart regression, ExploreChimp, and related flows.

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

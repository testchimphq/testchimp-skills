# /testchimp connect to test environment

**Workflow id:** `connect-to-test-env`

**Synonyms:** `/testchimp provision test environment`

Bring up or connect to the environment used for create-tests, smart regression, ExploreChimp, DAST, etc.

## Policy (required)

This is the **only** workflow that **blocks** when policy is missing (**Missing Config**). Resolve:

1. `--policy` if provided
2. `plans/knowledge/policies/connect-to-test-env.policy.md`
3. Any `*.policy.md` with frontmatter `workflow-id: connect-to-test-env`
4. Fallback: **`plans/knowledge/ai-test-instructions.md`** → **`## Environment Provision Strategy`** (and FAQ)

If no policy and ai-test-instructions lack a usable provision strategy, **stop**, discuss with the user, and author a policy ([`create-policy.md`](./create-policy.md)) before continuing dependent workflows. For authoring, follow the **strict connect-to-test-env checklist** in create-policy (feature branch / default branch / CI) and prefer [`../assets/policies/connect-to-test-env.policy.md`](../assets/policies/connect-to-test-env.policy.md) as a skeleton. After writing the file, call **`upsert-policy`** so the platform clears Missing Config immediately.

See [`policies-and-traceability.md`](./policies-and-traceability.md) and deeper env patterns in [`environment-management.md`](./environment-management.md).

## Scoping (defaults; policy overrides)

- **Feature branch** — prefer PR-scoped ephemeral / preview stack per policy.
- **Default branch** — ephemeral or shared (e.g. staging) per policy; ask when ambiguous.
- **CI / cloud** — follow policy’s CI section (spin-up on runner vs EaaS vs shared).

## Agent steps (thin)

1. Read resolved policy (or ai-test-instructions fallback).
2. Run documented provision / local-up / connect steps; wait for **healthy**.
3. Export or document **`BASE_URL`** / backend URLs for the runner (Preamble **#4** still required for Playwright/Mobilewright).
4. Best-effort **`report-agent-action`** when provisioning creates/updates env artifacts worth tracing.

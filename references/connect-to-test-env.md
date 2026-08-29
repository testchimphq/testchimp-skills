# /testchimp connect to test environment


> **Plan → approve → execute → report:** When this workflow runs **standalone**, write `knowledge/workflow_plans/connect-to-test-env/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). Before finishing standalone, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `connect-to-test-env`). Nested under a composite: reuse the parent plan (parent closes). See [`policies-and-traceability.md`](./policies-and-traceability.md).
**Workflow id:** `connect-to-test-env`

**Synonyms:** `/testchimp provision test environment`

Bring up or connect to the environment used for create-tests, smart smoke,
ExploreChimp, DAST, performance testing, etc.

## Policy (required)

This is the **only** workflow that **blocks** when policy is missing (**Missing Config**). Resolve:

1. `--policy` if provided
2. `plans/knowledge/policies/connect-to-test-env.policy.md`
3. Any `*.policy.md` with frontmatter `workflow-id: connect-to-test-env`
4. Fallback: **`plans/knowledge/ai-test-instructions.md`** → **`## Environment Provision Strategy`** (and FAQ)

If no policy and ai-test-instructions lack a usable provision strategy, **stop**, discuss with the user, and author a policy ([`create-policy.md`](./create-policy.md)) before continuing dependent workflows. For authoring, follow the **strict connect-to-test-env checklist** in create-policy (feature branch / default branch / CI) and prefer [`../assets/policies/connect-to-test-env.policy.md`](../assets/policies/connect-to-test-env.policy.md) as a skeleton. After writing the file, call **`upsert-policy`** so the platform clears Missing Config immediately.

See [`policies-and-traceability.md`](./policies-and-traceability.md) and deeper env patterns in [`environment-management.md`](./environment-management.md).

## Scoping (defaults; policy overrides)

- **Feature branch** — prefer PR-scoped ephemeral / preview stack per policy (**Local Agent** section).
- **Default branch** — ephemeral or shared (e.g. staging) per policy; ask when ambiguous.
- **CI / cloud / ChimpHands** — follow policy’s **`## CI / Cloud`** section (spin-up **on this runner**, EaaS MCP, or documented connect). See below.

## ChimpHands / GitHub Actions (critical)

When `GITHUB_ACTIONS` / `CLOUD_AGENT` / ChimpHands is set, you are **already** on a cloud runner. Env bring-up for authoring, executing, and fixing tests is **`connect-to-test-env`**, not “dispatch another Actions workflow and hope a stack appears.”

1. **Read** `plans/knowledge/policies/connect-to-test-env.policy.md` → **`## CI / Cloud`** (fallback: ai-test-instructions Environment Provision Strategy).
2. **Execute those instructions on this runner** (compose / `local-up` scripts / EaaS MCP / documented URLs). Wait until healthy; export **`BASE_URL`** / backend URLs.
3. **Reuse** that stack for nested work: create-tests, execute-tests, fix-test-execution, smart smoke, ExploreChimp, etc. Do **not** tear down between subflows of the same approved plan.
4. **Do not** substitute bring-up by repeatedly running `gh workflow run` / `gh run watch` on existing merge-gate or E2E workflows (e.g. “E2E PR”, compose CI jobs). Those jobs run **their own** ephemeral stack for a check; they do not hand you a live env for this session unless the policy **explicitly** says otherwise (rare — e.g. attach to a documented preview URL).
5. **WIF / OIDC-only cloud jobs** are separate: only dispatch them when the policy (or user) requires that specific cloud-side work — see [`chimphands-faq.md`](./chimphands-faq.md). That is **not** the default path to get a test env for SmartTests.
6. **Update the policy with learnings** when bring-up steps, health checks, ports, or pitfalls differ from what’s written (or were missing). Patch **`## CI / Cloud`** (and Local Agent if the same contract applies), bump `version`, commit, and call **`upsert-policy`**. Also add short FAQ bullets to `ai-test-instructions.md` when useful. Future ChimpHands sessions should succeed without rediscovery.

If **`## CI / Cloud`** only documents “how PR checks run Playwright” and has **no** agent bring-up steps, treat that as incomplete: derive a working on-runner (or EaaS) procedure from Local Agent / repo scripts, verify it, then **write it into the policy** before continuing dependent workflows.

## Agent steps (thin)

1. Read resolved policy (or ai-test-instructions fallback). Choose **Local Agent** vs **CI / Cloud** by where you are running.
2. Run documented provision / local-up / connect steps; wait for **healthy**.
3. Export or document **`BASE_URL`** / backend URLs for the runner (Preamble **#4** still required for Playwright/Mobilewright).
4. Persist learnings into the policy / ai-test-instructions when steps changed or were discovered (see above).
5. Best-effort **`report-agent-action`** when provisioning creates/updates env artifacts worth tracing.
6. **Standalone only:** **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — **`ACTION_COMPLETED`** with `WORKFLOW` + `connect-to-test-env` (nested: parent closes).

## Performance-test guidance

When nested under `init-perf`, `create-perf-tests`, `run-perf-tests`, or
`upkeep-perf`, the resolved policy must additionally identify:

- an isolated load-safe target and health check; **production is denied by
  default**;
- explicit authorization, owner, and maximum VUs/RPS/duration/data cardinality
  for anything beyond smoke;
- seed and teardown commands/endpoints and test-data namespace;
- rate limits, autoscaling/cost protections, observability, and an abort path;
- whether external dependencies are real, stubbed, or mocked (LLMs default to
  deterministic mock mode).

If these are missing, smoke/inspect may proceed when safe, but load/volume
execution is **Missing Config** and must stop. TrueCoverage or observed REAL
E2E traffic may rank journeys and suggest relative mix only; it must never be
converted into absolute load.

# Test environments (persistent vs ephemeral)

Use this reference when choosing **where** SmartTests authoring happen, provisioning **EaaS**, or resolving **branch-scoped BASE_URL**s. Official product docs: [Configuring branch-specific endpoints](https://docs.testchimp.io/smart-tests/branch-specific-test-execution#configuring-branch-specific-endpoints).

## Two environment types

### Persistent (shared)

- **Typical:** One stable frontend URL plus a shared backend stack. Configure in `.env-<ENV>` (or similar) with `BASE_URL`, `API_URL`, etc.
- **Variation — frontend isolation:** Deploy the PR frontend to a preview URL or run it locally while pointing at a **shared** backend. Suitable for **frontend-only** PRs when backend behavior is unchanged.
- **Pros:** Fast and cheap (no extra provisioning).
- **Cons:** Shared world-state with other testers, agents, and tests → less deterministic. Branch-specific backend changes may not be deployed there yet.

Persistent targets are usually tied to a **stage** (staging, dev, prod). They are deployed after merges/releases, so they are a poor fit for **backend** changes that only exist on a PR branch.

### Ephemeral on demand (isolated)

- **Typical:** Full-stack environment for a **Git branch**, provisioned via **EaaS**. TestChimp integrates with **Bunnyshell** for this workflow.
- **Variation — bespoke provisioning:** Your org provisions PR environments outside TestChimp. Configure resulting URLs via **TestChimp → Project Settings → Branch Management** (URL template and/or per-branch overrides). When **Bunnyshell is not configured** and you need the PR’s resolved `BASE_URL`, use the MCP tool **`get_branch_specific_endpoint_config`** with the Git branch name (see below).

After provision, run a suitable **world-state** script (`*.world.js`, `ensureWorldState`) so the stack reaches a known state before UI/API tests (based on the needed state for the test).

## Choosing a mode

| Situation | Suggested approach |
|-----------|-------------------|
| Frontend-only PR; shared staging is enough | Persistent + preview or local FE → shared BE (fast default). |
| Backend or data-layer changes on the PR | Ephemeral full stack (Bunnyshell) or bespoke branch URL from Branch Management. |
| Post-merge / release testing on a fixed stage | Persistent env vars (`BASE_URL` in `.env-*`, Playwright `baseURL`). |

## EaaS (Bunnyshell) workflow

1. Call **`get_eaas_config`**. Empty `{}` means BunnyShell integration is not set up or has no public fields exposed.
2. When configured, **prefer `provision_ephemeral_environment_and_wait`** (optional `branchName`, `pollIntervalSeconds` default 60, `maxWaitMinutes` default 25). It provisions and polls until the environment is **deployed** with **`component_urls_json`** populated, then returns a single JSON: `outcome` (`success` \| `failed` \| `timeout`), `failure_phase` (`provision` \| `deploy` \| `wait`), `message` for the user, and `component_urls_json` on success. Provisioning often takes **~5–10 minutes**—the MCP server emits progress logs while waiting.
3. **Fallback (only if** the wait tool is missing, errors, or the host kills long MCP calls**):** call **`provision_ephemeral_environment`**, then poll **`get_ephemeral_environment_status`** about **once per minute** for up to **~25 minutes** with the same success criteria (deployed + component URLs or terminal failure).
4. Parse **`component_urls_json`** to set `BASE_URL`, `BACKEND_URL`, and any `*_SERVICE_BACKEND_URL` vars your repo uses for seeds and tests (see [`world-states.md`](./world-states.md)).
5. Use **`destroy_ephemeral_environment`** when done.

### Troubleshooting failed or stuck ephemeral deploy

When **`provision_ephemeral_environment_and_wait`** returns **`failed`** or **`timeout`**, or deploy is stuck:

1. **`list_bunnyshell_environment_events`** — pass the same **`bnsEnvironmentId`**. The tool returns the **BunnyShell response body as-is** (same shape as calling their API). Filter with optional **`eventStatus`** (`fail` is most useful) or **`eventType`** (e.g. deploy-related types). Official BunnyShell event filters: [event list](https://documentation.bunnyshell.com/reference/eventlist).
2. **`list_bunnyshell_workflow_jobs`** — same **`bnsEnvironmentId`**; response body is raw BunnyShell JSON — find a relevant **`workflowJobId`** (field name depends on their payload).
3. **`get_bunnyshell_workflow_job_logs`** — **`bnsEnvironmentId`** + **`workflowJobId`**. Response body is the **raw BunnyShell logs payload** (no TestChimp wrapping or truncation).
4. Fix the underlying issue in the repo (e.g. Helm/YAML, image, resources), **push** to the branch, then re-run **`provision_ephemeral_environment_and_wait`** (or manual provision + status polling fallback).

Kubernetes **pod/container** logs in the BunnyShell UI are not exposed by these MCP tools yet; workflow job logs cover the deploy pipeline.

### User has no Bunnyshell setup yet

1. Pull or install the **[Bunnyshell environments skill](https://github.com/bunnyshell/bunnyshell-environments-skill)** so the agent can help generate `bunnyshell.yaml` and guide provisioning in Bunnyshell.
2. Configure **TestChimp → Project Settings → Integrations → Bunnyshell**:
   - **Bunnyshell token**
   - **Bunnyshell project id** — e.g. `bns projects list --output json` and read the `id` field (requires `bns` CLI installed).
   - **Kubernetes integration id** — e.g. `bns k8s list --output json`, find the row for your cluster, copy `id`.
   - **Git repo path** to the Bunnyshell YAML file (Git integration is a prerequisite).

## Branch Management (no EaaS)

When EaaS is **not** used, teams may configure a **URL template** and optional **per-branch overrides** under Branch Management. Template placeholders include `{BRANCH_NAME}`, `{BRANCH_SLUG}`, `{GIT_REPO_NAME}`, `{PROJECT_NAME}`.

**MCP tool `get_branch_specific_endpoint_config`**

- Pass **`branchName`** (Git branch name, e.g. from the PR).
- Returns the resolved **`baseUrl`** and how it was resolved (`override` vs `template` vs `none`).
- **Use when EaaS is not configured** and you need the branch-specific preview/base URL for tests or CI `BASE_URL`.
- **Implementation detail:** overrides are stored keyed by **internal Git branch id** in the product; the tool accepts **branch name** and resolves server-side—do not require the human or agent to know internal ids.

## Related

- **`/testchimp init`** — follow the phased flow (optional quick smoke -> collaborative plan -> execute), and capture environment strategy plus per-item progress into `plans/knowledge/ai-test-instructions.md` (see [`init-testchimp.md`](./init-testchimp.md)).
- **`/testchimp test`** — [`testing-process.md`](./testing-process.md) for phased workflow and when to load this doc.
- **World states** — [`world-states.md`](./world-states.md) for deterministic data after the environment URL is known.

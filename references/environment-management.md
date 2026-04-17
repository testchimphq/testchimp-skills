# Environment provisioning (Local vs CI)

Use this reference when deciding **where tests run** and **how environments are provisioned** for **per‑PR testing-before-merge**.

This doc intentionally focuses on two workflows only:

- **Local — Test author time** (agents and humans iterating on tests)
- **CI — Test execution time** (PR checks)

Official product docs: [Configuring branch-specific endpoints](https://docs.testchimp.io/smart-tests/branch-specific-test-execution#configuring-branch-specific-endpoints).

## Workflow 1: Local — test author time (agents)

### Preferred default: Docker Compose full stack

Goal: get value quickly without requiring EaaS setup during onboarding, and without paying for remote ephemeral environments for tight local agent loops.

**Agent decisioning (repo discovery first):**

1. Look for an existing local full-stack entrypoint in the repo:
   - `docker-compose.yml` / `docker-compose.*.yml` files, and/or
   - README instructions that mention `docker compose up`, `make up`, `task up`, etc.
2. If it exists and brings up the stack end-to-end, **use it**.
3. If it exists but is partial (only DB, only API, etc.), record that constraint and ask whether to author a complete one - reusing the existing partial ones.
4. If no compose exists, ask whether to author one (only if the stack is realistically runnable on a workstation).

**Caching / build-cost guidance (must):**

- Prefer Docker BuildKit cache for builds:

```bash
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

- For repeat runs, prefer:
  - build once (`docker compose build`) and then
  - start without rebuilding (`docker compose up -d`), avoiding `up --build` unless necessary.

**Pre-steps (must be captured for the project):**

Some stacks require pre-steps (examples): cloud auth, local secrets access, env files, DB migrations, service emulators.

- Identify these by reading repo docs, compose header comments, `.env.example` files, and any `scripts/` setup docs.
- Persist the project-level prerequisites and the single recommended “local up” command in `plans/knowledge/ai-test-instructions.md` under:\n  - `## Environment Provision Strategy` → `### Local - Test Authoring`

**Ergonomics requirement (recommended):**

If there are multiple pre-steps, create a single runnable script entrypoint (conventional example: `scripts/qa/local-up.sh`) that:\n- validates prerequisites,\n- exports or checks required env vars,\n- then runs the compose up sequence.

### Alternative: EaaS (Bunnyshell) for author time

Use EaaS for local authoring only when the stack is too big or too complex to run locally (examples: requires full Kubernetes clusters, heavy data dependencies, or non-trivial service meshes).

If the repo does not already have EaaS configured, initiate the EaaS setup workflow separately instead of blocking onboarding.

## Workflow 2: CI — test execution time (PR)

### Preferred default: EaaS (Bunnyshell)

CI should default to running tests against an ephemeral PR environment provisioned via EaaS so results reflect the PR’s code.

- If `bunnyshell.yaml` exists, use it as the basis for provisioning.
- If it does not exist, ask whether the team wants it created; if yes, follow the EaaS setup workflow.

### Discouraged fallback: persistent environment URL

If the team explicitly chooses to run E2E only post-merge (discouraged, but allowed for “get going quickly” - as a stop gap until EaaS is setup):

- Configure a persistent target URL via `.env-QA` under the tests root (or equivalent), e.g. `BASE_URL=...`.
- Make it explicit in `plans/knowledge/ai-test-instructions.md` that this is a fallback and why it was chosen.

## EaaS (Bunnyshell) workflow

1. Call **`get_eaas_config`**. Empty `{}` means BunnyShell integration is not set up.
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

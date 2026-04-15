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
2. When configured, use **`provision_ephemeral_environment`** (optional `branchName`), then **`get_ephemeral_environment_status`** with `bnsEnvironmentId` until deployed; use **`destroy_ephemeral_environment`** when done.
3. Poll status until URLs/components appear in the response for wiring `BASE_URL` / seed APIs.

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

- **`/testchimp init`** — capture environment strategy into `plans/knowledge/ai-test-instructions.md` (see [`init-testchimp.md`](./init-testchimp.md)).
- **`/testchimp test`** — [`testing-process.md`](./testing-process.md) for phased workflow and when to load this doc.
- **World states** — [`world-states.md`](./world-states.md) for deterministic data after the environment URL is known.

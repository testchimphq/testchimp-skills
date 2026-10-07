# TestChimp CLI (`@testchimp/cli`)

Use the **CLI** when the agent runs **shell commands** (CI, scripts, or hosts without MCP). Use **MCP** when the IDE/agent host exposes MCP tools. Both call the same TestChimp **`/api/mcp/*`** HTTP APIs.

This page lists **every subcommand and flag** as implemented in the CLI (kebab-case flags; request bodies use **camelCase**). **`--json-input`** is available on every tool subcommand below except where noted; it merges **over** flags (JSON wins on conflicts).

**Screen-state atlas** (for **`markScreenState`** / ExploreChimp vocabulary): see § [**Screen-state atlas (SmartTests, traces, ExploreChimp)**](#screen-state-atlas-smarttests-traces-explorechimp) — **`list-screen-states`**, **`upsert-screen-states`**.

**Release catalog** (Release Checks / ExploreChimp targeting a release): **`get-release`** (thin catalog metadata) — see § [**get-release**](#get-release). For **release gating** (per-environment priority×status test stats, open-issue stats, scan summaries, in-scope scenario/issue records) use **`get-release-details`** (CLI ≥ **0.1.18**) — see § [**get-release-details**](#get-release-details).

## Install

```bash
npm install -D @testchimp/cli@0.1.6
# or: npm install -D @testchimp/cli@latest
```

Invoke via `npx @testchimp/cli@latest <subcommand>` or the **`testchimp`** binary from `node_modules/.bin` after a local install.

**Minimum for platform execution reporting:** **`@testchimp/cli` ≥ 0.1.6** (this doc) and **`@testchimp/playwright` ≥ 0.2.0** on the SmartTests package (reporter sends `executionContext` on each test end).

## Authentication and API host (`TESTCHIMP_API_KEY`, `TESTCHIMP_BACKEND_URL`, `TESTCHIMP_INGRESS_URL`)

The CLI reads **`process.env.TESTCHIMP_API_KEY`** and, when set, **`process.env.TESTCHIMP_BACKEND_URL`**. Agent-run shells often **do not** inherit the IDE MCP process environment. Playwright runners additionally use **`TESTCHIMP_INGRESS_URL`** (when set) for CI ingest — export it from the same MCP `env` into runner shells (see **`SKILL.md`** Preamble **#4**).

**Before every CLI invoke** (and on any **401**), resolve env from the project MCP config:

1. Resolve the **same project-scoped MCP config** used for TestChimp (the file where the user placed the key at init, or the cloud `mcp.json` that references `${TESTCHIMP_API_KEY}`). Paths are **host-specific** — see **Finding project MCP config** in **`SKILL.md`** (`.cursor/mcp.json`, `.mcp.json`, root `mcp.json`, etc.). **`.cursor` is an example, not universal.**
2. From the **SmartTests root** (folder containing `.testchimp-tests`), walk **up** the directory tree and check each candidate MCP config file until you find `mcpServers` with a **`testchimp`** server entry (or any server whose `args` include `@testchimp/cli`). If walk-up fails, search the repo for `mcp.json` / `.mcp.json` as described in **`SKILL.md`**.
3. Read from that entry’s **`env`**:
   - **`TESTCHIMP_API_KEY`** (required for auth)
   - **`TESTCHIMP_BACKEND_URL`** when present — **must** be exported for CLI/MCP; do **not** fall back to the package default prod host when this is set (staging / enterprise / self-hosted). Keys are environment-scoped; calling prod with a non-prod key yields **401**.
   - **`TESTCHIMP_INGRESS_URL`** when present — **must** be exported into Playwright/Mobilewright runner shells (CI ingest host; parallel to backend URL in mcp.json)
   - **`TESTCHIMP_PROJECT_ID`** when present (TrueCoverage RUM wiring; not required for CLI auth)
4. **`export`** those variables in the **same shell** that will run `testchimp` or Playwright (e.g. one block: `export TESTCHIMP_API_KEY=... TESTCHIMP_BACKEND_URL=... TESTCHIMP_INGRESS_URL=... TESTCHIMP_EXECUTION_SOURCE=LOCAL_AGENT` then the command). For Playwright/Mobilewright also export **`TESTCHIMP_EXECUTION_SOURCE=LOCAL_AGENT`** or **`CLOUD_AGENT`** (never `CI` from the skill) — see [`policies-and-traceability.md`](./policies-and-traceability.md)#execution-source-local_agent--cloud_agent.
5. **Never print the key** in chat, logs, or echoed commands.

**`TESTCHIMP_BACKEND_URL`:** When set in MCP `env`, it overrides the default API host (see `testchimp --help` footer). When **absent**, the CLI default (SaaS prod) is correct. On **401**, re-check that a configured backend URL was exported before assuming a bad key.

**`TESTCHIMP_INGRESS_URL`:** When set, `@testchimp/playwright` uses it for CI ingest. When absent, the reporter defaults to `https://ingress.testchimp.io` or rewrites SaaS `featureservice*` → `ingress*`.

**OAuth + bot identity (CLI ≥ 0.1.85):** `TESTCHIMP_OAUTH_TOKEN` (an OAuth access token issued by featureservice) is sent as `Authorization: Bearer`; when set, `TESTCHIMP_API_KEY` is optional. When both are sent, the bearer names the user and the key names the project. QA bots: see [QA bots § Project binding](#project-binding-cli--0188) (`--bot <botId>`). `TESTCHIMP_BOT_ID` (1–64 printable ASCII, no spaces) is sent as the `bot-id` header for QA-bot attribution; invalid values are ignored with a single stderr warning. Never print either value.

**401 remediation order:** (1) export `TESTCHIMP_BACKEND_URL` / `TESTCHIMP_INGRESS_URL` from MCP if configured → (2) export `TESTCHIMP_API_KEY` from the same entry → (3) retry. Remote MCP setups: refresh `.testchimp/mcp.json` with `get-project-credentials` → `workspace save-creds` before asking the user.

**`.testchimp/mcp.json` fallback (CLI ≥ 0.1.90):** When neither `TESTCHIMP_API_KEY` nor `TESTCHIMP_OAUTH_TOKEN` is set (and no `--bot` / `TESTCHIMP_BOT_ID`), the CLI itself reads `TESTCHIMP_API_KEY`, `TESTCHIMP_PROJECT_ID`, `TESTCHIMP_BACKEND_URL` and `TESTCHIMP_INGRESS_URL` from the nearest `.testchimp/mcp.json` at or above the current directory (written by TestChimp Studio or `workspace save-creds`) and notes the file on stderr. Exported variables always win. The file must be mode 0600 (Studio and `save-creds` write it that way); other copies are ignored with a stderr warning. Playwright / Mobilewright / k6 do **not** read this file — keep exporting for runners per steps 1–4.

### Remote MCP (OAuth) and runner keys (CLI ≥ 0.1.90)

Remote MCP is an **additional** way to connect; manual `npx` + `env` and Studio setups keep working unchanged.

- **Per-project URL:** `https://mcp.testchimp.io/mcp?projectId=<id>` in the project MCP file (`url` entry, no `env`). Every tool call acts on that project; TestChimp checks the signed-in user is a member. One sign-in covers all of the user's projects. Plain `/mcp` uses the project picked on the consent page. A QA bot's `projectApiKey` argument still wins over the URL.
- **Runner key:** remote entries carry no key, so local runners get it once per repo:

```bash
# get-project-credentials (MCP) → projectId, projectName, projectApiKey, backendUrl, ingressUrl
printf '%s' "<projectApiKey>" | testchimp workspace save-creds --folder <git root> --project-id <projectId> \
  --project-name "<projectName>" --backend-url <backendUrl> --ingress-url <ingressUrl> [--reassign]
```

`workspace save-creds` writes `<folder>/.testchimp/mcp.json` in TestChimp Studio's exact format (mode 0600, other servers kept), adds `.testchimp/` to `.gitignore`, and maps the folder in `~/.testchimp/projects.json`. The key is read from stdin only and never printed. Output: `{projectId, status: written|updated|unchanged, folder, mcpJsonPath, gitignoreUpdated}`. An existing entry for the same project is kept (only a rotated key is refreshed); another project's entry needs `--reassign`.

## Quick invoke

```bash
testchimp --help
testchimp get-requirement-coverage --branch-name main
testchimp create-user-story --platform-file-path plans/stories/auth.md --title "Auth"
testchimp list-screen-states
testchimp upsert-screen-states --json-input @screen-states.json
testchimp <subcommand> -h   # flags for installed package version
```

Subcommand help is the **runtime** source of truth if a flag is added in a newer `@testchimp/cli` than this doc.

## Output contract

- **stdout:** Final JSON response from the API (machine-parseable).
- **stderr:** Human-readable progress for long operations, especially **`provision-ephemeral-environment-and-wait`** (poll / “still waiting” lines). Errors go to stderr with a non-zero exit code.

## Global CLI

| Flag | Description |
|------|-------------|
| `-V`, `--version` | CLI package version. |
| `-h`, `--help` | Help for the root program or a subcommand (`testchimp <cmd> -h`). |

---

## `--json-input` (all tool commands)

| Flag | Description |
|------|-------------|
| `--json-input <json>` | Inline JSON **object** merged on top of other flags; **JSON wins** on key conflicts. |
| `--json-input @path/to/file.json` | Read JSON from disk (leading **`@`**). |

Use when nested fields are not exposed as flags (e.g. coverage **`includeNonCoveredUserStories`**, TrueCoverage **`baseExecutionScope`**), or to send the full body for TrueCoverage commands.

---

## `mcp`

Start the TestChimp MCP server (stdio transport). Typically invoked as `npx -y @testchimp/cli@latest mcp` from MCP config.

**Remote (CLI ≥ 0.1.85):** `testchimp mcp --http [--port <n>] [--host <h>]` serves stateless Streamable HTTP at `POST /mcp` (default port `PORT` env or 8080, host `0.0.0.0`). Every request needs `Authorization: Bearer <OAuth access token>`; the caller's token is forwarded to TestChimp per tool call (the server's own API key is never used). Also serves `GET /.well-known/oauth-protected-resource` and `GET /healthz`. Env: `TESTCHIMP_MCP_PUBLIC_URL`, `TESTCHIMP_OAUTH_ISSUER`, `TESTCHIMP_BACKEND_URL`, `TESTCHIMP_INGRESS_URL`. The CLI repo's `Dockerfile` packages this for Cloud Run.

---

## `get-org-capabilities`

Requires `@testchimp/cli` ≥ **0.1.29**.

**API:** `POST /api/mcp/get_org_capabilities`

Fetch the organization's enabled **capabilities** (not tier/plan name) plus **`freeTrialActive`**. Call this **before** relying on TrueCoverage or API contract coverage insights so playbooks can **soft-skip** gated work instead of failing — see [`instrument-truecoverage.md`](./instrument-truecoverage.md), [`upkeep.md`](./upkeep.md), and [`run-qa.md`](./run-qa.md).

| Flag | Required | Notes |
|------|----------|-------|
| `--json-input …` | No | Body is empty; JSON merge rarely needed. |

**Response (camelCase):**

| Field | Type | Notes |
|-------|------|-------|
| `organizationId` | string | |
| `capabilities` | string[] | Enabled capability names, e.g. `TRUE_COVERAGE`, `API_CONTRACT_COVERAGE`. Treat unlisted capabilities as **off**. |
| `freeTrialActive` | boolean | When `true`, gated capabilities may still be usable under trial even if not listed — do not hard-fail solely on capability absence without also checking this flag. |

**Example:**

```bash
testchimp get-org-capabilities
# stdout: {"organizationId":"...","capabilities":["TRUE_COVERAGE","API_CONTRACT_COVERAGE"],"freeTrialActive":false}
```

**Agent rule:** Always check **`capabilities`**, never infer from a separate "tier" field — this API is the single source of truth for what a workflow may rely on. When a capability is missing **and** `freeTrialActive` is `false`, soft-skip only the gated insight/analysis (mark **N/A** + reason); never abort the surrounding workflow.

**Not capability-gated:** Only the capabilities listed in the response gate anything. **ExploreChimp has no org capability** (there is no `EXPLORECHIMP` value) — never skip or block ExploreChimp because it is absent from `capabilities`. ExploreChimp is limited only by org **credits**; when credits run out, analyze calls return a `…_CREDIT_LIMIT` skip status rather than an HTTP error (see [`run-explorechimp.md`](./run-explorechimp.md#availability-no-org-capability-required)).

---

## `get-suite-execution-stats`

Full-suite execution rollup for **bloat checks** against **`global.policy.md`** (`max_full_suite_duration_minutes`, `max_test_count`). Client-side aggregate of **`list_execution_history`** `testStats` (same timing math as the Tests UI execution-stats pane / `ExecutionTimingSummary`).

**Soft notify (not a hard blocker):** When planning/authoring new tests (`upkeep`, `create-tests`, `run-qa`), compare stats to policy caps. If over **or close** (e.g. within ~10% of a non-zero cap), **inform the user** and prefer prune/consolidate suggestions. Treat **`0`** as unlimited.

**Availability:** Prefer **`@testchimp/cli@latest`** (package ≥ **0.1.30**). If the command/tool is missing, bump MCP to `@latest` and reload.

**API:** `POST /api/mcp/list_execution_history` (tool rolls up `testStats` locally — there is no separate `get_suite_execution_stats` HTTP route)

| Flag | Required | Notes |
|------|----------|-------|
| `--folder-path` / `--file-paths` / `--branch-name` / `--platform` / … | No | Same filters as **`get-execution-history`** |
| `--json-input …` | No | Full filter object |

**Response fields:** `testCount`, `timedTestCount`, `sumSuccessMeanSecs`, `sumFailMeanSecs`, `maxSuccessMeanSecs`, `slowTestCount` (success mean > 30s).

**Agent rule:** Call before planning large suite growth in **`/testchimp upkeep`**. Compare `sumSuccessMeanSecs` / `testCount` to **`global.policy.md`** yourself (this tool only returns stats — do not expect `exceedsLimit`); **notify the user** when limits are exceeded (`0` = unlimited for count caps). See [`upkeep.md`](./upkeep.md).

**Example:**

```bash
testchimp get-suite-execution-stats --folder-path tests
```

---

## Coverage and execution

### `get-requirement-coverage`

**API:** `POST /api/mcp/list_requirement_coverage`

Answers: **which top N scenarios should we cover next?** Agents should expand **`global.policy.md`** Coverage target + Prioritization signals into the flags below and prefer **`rankedScenarios[]`** as the work queue.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--release <s>` | No | `release` | |
| `--environment <s>` | No | `environment` | |
| `--branch-name <s>` | No | `branchName` | Optional Git branch; omit for cross-branch coverage (recommended for `/testchimp test` Analyze). |
| `--platform <web\|ios\|android>` | No | `platform` | Optional filter: latest coverage for that platform only (`web`, `ios`, or `android`). |
| `--record-types <csv>` | No | `recordTypes` | Coverage sources: `smart_test`, `manual`, and/or `perf_test`. Default (omit): `smart_test` only. |
| `--include-manual` | No | `recordTypes` | Convenience: include manual **session** coverage in addition to automated (equivalent to `--record-types smart_test,manual`). Not the default. |
| `--include-perf` | No | `recordTypes` | Convenience: include **PERF_TEST** journey coverage in addition to automated. Opt-in; does not replace SMART_TEST/MANUAL. |
| `--manual-only` | No | `recordTypes` | Convenience: manual-only coverage (equivalent to `--record-types manual`). |
| `--lifecycle-statuses <csv>` | No | `scenarioLifecycleStatuses` | Allowlist. Empty/omit = no status filter (UI Insights). Agent: policy **`ready`** → `ready`; policy **Draft+** / `lifecycle_status: draft` → `draft,ready`. Blank scenario status is treated as `ready`. |
| `--limit <n>` | No | `limit` | After filter+rank, return only top N **gaps** in **`rankedScenarios`**. Server clamps to **200** (also the max when only `consider_*` is set without `--limit`). |
| `--consider-scenario-priority` | No | `considerScenarioPriority` | Rank high → medium → low → unset (from policy `scenario_priority`). |
| `--consider-semantic-coverage` | No | `considerSemanticCoverage` | Pack ranked gaps by scenario-embedding novelty vs scenarios that already have linked SmartTests. Pass when policy `semantic_coverage: true`. |
| `--auto-verification-only` | No | `autoVerificationOnly` | Exclude `verification_strategy=manual`. Server already defaults to **true** when unset. |
| `--include-manual-verification` | No | `autoVerificationOnly: false` | Escape hatch to include manual-verification scenarios (overrides `--auto-verification-only`). |
| `--file-paths <csv>` | No | `scope.filePaths` | Comma-separated paths under **platform tests or plans** root. |
| `--folder-path <path>` | No | `scope.folderPath` | Slash-separated folder under tests or plans root; sent as normalized path segments. |
| `--json-input …` | No | (merge) | e.g. `includeNonCoveredUserStories`, `includeNonCoveredTestScenarios`, or `scope.folderPath` as **array** of segments. |

**`rankedScenarios[]` shape (when `--limit` or any `consider_*` is set):** flat, server-sorted list of **gap** scenarios only (empty coverage, only `NOT_ATTEMPTED`, or partial multi-platform gaps with at least one `NOT_ATTEMPTED`). Fully covered scenarios are omitted. Each row has `scenarioOrdinalId`, `scenarioTitle`, `scenarioLifecycleStatus`, `scenarioPriority`, and `coverageRecords`. Sort: full gaps before partial gaps; then priority when requested; tie-break ordinal ascending. Nested `userStories` / `unmappedScenarios` remain for tree views — agents targeting gaps prefer **`rankedScenarios`** (eligibility = present there).

**Example — top-N gaps from global policy (Ready + priority + semantic flags):**

```bash
testchimp get-requirement-coverage \
  --lifecycle-statuses ready \
  --consider-scenario-priority \
  --consider-semantic-coverage \
  --limit 20 \
  --json-input '{
    "includeNonCoveredUserStories": true,
    "includeNonCoveredTestScenarios": true
  }'
```

### `get-execution-history`

**API:** `POST /api/mcp/list_execution_history`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--release <s>` | No | `release` | |
| `--environment <s>` | No | `environment` | When **omitted**, history is **not** env-scoped (all envs). Prefer omitting for flake analysis / `fix-test-execution`. When set, filters to that env. |
| `--branch-name <s>` | No | `branchName` | |
| `--scenario-id <id>` | No | `scenarioId` | When set, returns runs for tests linked to this scenario (Insights execution history). |
| `--test-id <id>` | No | `testId` | SmartTest id (e.g. from `fetch-execution-report`). Returns top 5 recent runs for that test. No folder/scenario scope required. Requires CLI ≥ **0.1.25**. |
| `--platform <web\|ios\|android>` | No | `platform` | Optional platform filter (`web`, `ios`, `android`). Prefer `dimensionFilters` for device/OS/resolution/orientation. |
| `--file-paths <csv>` | No | `scope.filePaths` | Comma-separated under platform tests or plans root. |
| `--folder-path <path>` | No | `scope.folderPath` | Slash-separated; same normalization as coverage. |
| `--json-input …` | No | (merge) | e.g. `dimensionFilters` (`[{ "dimension": "PLATFORM_EXECUTION_JOB_FILTER_DIMENSION", "values": ["WEB"] }]`), `limit`, `offset`. |

**There is no separate “list failing tests” command.** For **`/testchimp upkeep`** / fix-recent-failures discovery: call with `--folder-path tests` (or scoped paths), group `records[]` by `testId`, keep tests whose **latest** `status` is `SMART_TEST_EXECUTION_FAILED`, then deepen with **`fetch-execution-report --job-id <executionJobId>`** and optional **`--test-id`** history. See [`upkeep.md`](./upkeep.md) § Recently failing tests and [`fix-test-execution.md`](./fix-test-execution.md) §0.

**Example — discover recently failing tests (upkeep):**

```bash
testchimp get-execution-history --folder-path tests
# Then for each latest-failed test's executionJobId:
testchimp fetch-execution-report --job-id "<execution-job-id>"
testchimp get-execution-history --test-id "<test-uuid>"
```

### `fetch-execution-report`

**API:** `POST /api/mcp/fetch_execution_report`

Used by [`fix-test-execution.md`](./fix-test-execution.md). Provide **exactly one** of:

| Flag | Maps to JSON field | Notes |
|------|-------------------|--------|
| `--batch-invocation-id <id>` | `batchInvocationId` | Batch run from the webapp URL. |
| `--job-id <id>` | `jobId` | Single test execution job. |

Returns only **failing** tests: `jobId`, `testId`, `testName`, `testFilePath`, `errors[]`, `traceViewerUrl` (when available).

```bash
testchimp fetch-execution-report --batch-invocation-id "<id>"
testchimp fetch-execution-report --job-id "<id>"
```

### `get-batch-view-url`

**API:** `POST /api/mcp/get_batch_view_url`

Resolve the TestChimp batch execution viewer deeplink for the authenticated project (includes `project_id` from the API key). Prefer this over hand-building URLs so route changes stay server-side.

| Flag | Maps to JSON field | Notes |
|------|-------------------|--------|
| `--batch-invocation-id <id>` | `batchInvocationId` | Batch invocation id from a test run. |

**Response:** `batchViewUrl` — open in chat when reporting run results to the user.

```bash
testchimp get-batch-view-url --batch-invocation-id "<batch-invocation-id>"
```

### `upload-attachment`

**API:** `POST /api/mcp/upload_attachment`

Upload a local file (e.g. agent screenshot evidence) to explore-snaps. Returns a stable **`viewUrl`** (`{app.url}/artifact?gcs_path=...`) to paste in chat; users open it in the app (ChimpHands shows an in-app preview modal).

| Flag | Maps to JSON field | Notes |
|------|-------------------|--------|
| `--file <path>` | `file` (CLI reads disk → `fileBase64` in API body) | Required. |
| `--filename <name>` | `filename` | Optional; defaults to basename of `--file`. |
| `--content-type <type>` | `contentType` | Optional MIME type. |

**Response:** `gcpPath`, `viewUrl`.

```bash
testchimp upload-attachment --file /tmp/evidence.png
```

### Platform execution reporting

**Ingest:** `@testchimp/playwright` reporter attaches **`executionContext`** on each test end (platform from Mobilewright **`projects[].use.platform`** or web project config; device fields from viewport or mobile device annotations). TestChimp stores this on the execution job and denormalized columns for queries.

**Requirement coverage (`get-requirement-coverage`):**

| `platform` | Behavior |
|------------|----------|
| omitted | Rollup per project scaffold: **web** → one coverage row per scenario (WEB); **mobile** → up to **iOS** + **Android** rows; **multi-platform** → **web** + **iOS** + **Android**. Missing platform in time window → `NOT_ATTEMPTED` status for that platform. |
| `web` / `ios` / `android` | Latest job for that platform only (one row per scenario). Invalid platform for project type → empty result (not HTTP 400). |

Coverage records include a **`platform`** field when multiple platforms are returned. Dedup key is **(logical test path + name, platform)**.

**Execution history (`get-execution-history`):**

| Mode | How |
|------|-----|
| Test id | `testId` / `--test-id` = SmartTest UUID (from `fetch-execution-report`). Top 5 recent runs. Prefer omitting `environment`. |
| Folder scope | `scope.folderPath` / `scope.filePaths` (same as coverage). Top 5 recent runs per test. |
| Scenario scope | `scenarioId` = platform scenario UUID (Insights execution history). Omit folder scope or combine per server rules. |
| Platform filter | `--platform web\|ios\|android` **or** `dimensionFilters` with `PLATFORM_EXECUTION_JOB_FILTER_DIMENSION` and values `WEB`, `IOS`, `ANDROID`. |
| Device drill-down | `dimensionFilters` in JSON: `DEVICE_FAMILY`, `OS_VERSION`, `SCREEN_RESOLUTION`, `SCREEN_ORIENTATION` (enum dimension names + string values). OR within a dimension, AND across dimensions. |

**Example — recent history for one failing test (fix-test-execution):**

```bash
testchimp get-execution-history --test-id "<test-uuid>"
```

**Example — iOS-only coverage for a plan folder:**

```bash
testchimp get-requirement-coverage \
  --environment QA \
  --folder-path plans/checkout \
  --platform ios
```

**Example — scenario execution history with platform filter:**

```bash
testchimp get-execution-history \
  --scenario-id "<scenario-uuid>" \
  --environment QA \
  --release default \
  --platform ios \
  --json-input '{"limit":100}'
```

**Example — dimension filters (MCP or `--json-input`):**

```json
{
  "scenarioId": "<scenario-uuid>",
  "environment": "QA",
  "dimensionFilters": [
    { "dimension": "PLATFORM_EXECUTION_JOB_FILTER_DIMENSION", "values": ["IOS"] },
    { "dimension": "DEVICE_FAMILY_EXECUTION_JOB_FILTER_DIMENSION", "values": ["iPhone 15"] }
  ],
  "limit": 100
}
```

### `mark-plan-items-implementation-done`

**API:** `POST /api/mcp/mark_plan_items_implementation_done`

After Validate (run-qa), marks planned items implemented in DB lifecycle fields (does **not** write status into plan markdown):

- **Scenarios** → **`ready`** (idempotent if already ready). Scenarios do **not** use `done`.
- **User stories** → **`done`**.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--scenario-ordinal-ids <csv>` | No* | `scenarioOrdinalIds` | Numeric parts of `TS-<n>`. |
| `--user-story-ordinal-ids <csv>` | No* | `userStoryOrdinalIds` | Numeric parts of `US-<n>`. |
| `--json-input …` | No | (merge) | |

\*At least one of the ordinal id lists should be non-empty.

### `update-plan-items-lifecycle-status`

**API:** `POST /api/mcp/update_plan_items_lifecycle_status`

Sets **`lifecycle_fields.status`** for **one** user story or test scenario (DB only; does not rewrite plan markdown). Used after **`/testchimp implement`** to move items to **`ready`** (unless policy overrides). Requires CLI ≥ **0.1.22**.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--entity-type <type>` | Yes | `entityType` | `story` \| `scenario` (also accepts `user_story` / `USER_STORY` / `SCENARIO`). |
| `--ordinal-id <n>` | Yes | `ordinalId` | Numeric part of `US-<n>` / `TS-<n>`. |
| `--status <status>` | Yes | `status` | `draft` \| `ready` \| `in progress` \| `blocked` \| `done` \| `archived`. |
| `--json-input …` | No | (merge) | |

**Examples:**

```bash
testchimp update-plan-items-lifecycle-status --entity-type story --ordinal-id 181 --status ready
testchimp update-plan-items-lifecycle-status --entity-type scenario --ordinal-id 2205 --status ready
```

Call once per story/scenario when multiple entities were implemented in the same run.

---

## Screen-state atlas (SmartTests, traces, ExploreChimp)

Project **screen / state vocabulary** for **`markScreenState`** checkpoints. Same HTTP APIs as MCP **`list-screen-states`** and **`upsert-screen-states`**. **Agents in shell** should use these commands after **`TESTCHIMP_API_KEY`** is exported (see [Authentication](#authentication-testchimp_api_key)); parse **stdout JSON** for machine use (see [Output contract](#output-contract)).

**When to run:** **before** adding or renaming **`markScreenState`** calls in specs (Validate / Phase 4), per [`write-smarttests.md`](./write-smarttests.md) §7 — fetch atlas first, run the spec **headed** to align names with the live UI, **`upsert-screen-states`** for any new **`(screen, state)`** pairs, then edit the test.

Authoring workflow (headed UI inspection, order of operations): [`write-smarttests.md`](./write-smarttests.md) §7 and **Phase 4** in [`run-qa.md`](./run-qa.md).

### `list-screen-states`

**API:** `POST /api/mcp/list_screen_states`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|-------|
| `--environment <s>` | No | `environment` | Forward-compatible env tag. |
| `--json-input …` | No | (merge) | Rarely needed; use for extra body fields. |

**Example (from SmartTests root or any cwd with key in env):**

```bash
export TESTCHIMP_API_KEY=…   # from MCP config walk-up; never echo
testchimp list-screen-states
# stdout: JSON payload describing existing screens and their state strings — reuse exact strings in markScreenState(...)
```

With **`--environment <s>`** when your project uses env-scoped vocabulary (forward-compatible; optional on v1).

### `get-release`

**API:** `POST /api/mcp/get_release`

**Requires `@testchimp/cli` ≥ `0.1.13`.**

Fetch release catalog details for a version/label in the current project (cut git SHA, prior release + SHA, focus areas, payload). Used when running ExploreChimp or **performance tests** **targeting a release**.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|-------|
| `--version <version>` | **Yes** | `version` | Release catalog label / version string. |
| `--json-input …` | No | (merge) | Optional extra body fields. |

**Example:**

```bash
export TESTCHIMP_API_KEY=…   # from MCP config walk-up; never echo
testchimp get-release --version '1.2.0'
# stdout: JSON McpGetReleaseResponse with full ReleaseDetail
```

### `get-release-details`

**API:** `POST /api/mcp/get_release_details`

Fetch **gate-oriented** release details for a version/label: focus-area scope, per-environment priority×status test aggregations, open-issue stats, release-scan summaries, and detailed in-scope scenario/issue records. Use for CI/agent **release gating** (pass/fail decisions). Thin catalog metadata remains on `get-release`.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|-------|
| `--version <version>` | **Yes** | `version` | Release catalog label / version string. |
| `--json-input …` | No | (merge) | Optional extra body fields. |

**Example:**

```bash
export TESTCHIMP_API_KEY=…   # from MCP config walk-up; never echo
testchimp get-release-details --version '1.2.0'
# stdout: JSON McpGetReleaseDetailsResponse (summary + detailedResults)
```

### `get-security-scan-config`

**API:** `POST /api/mcp/get_security_scan_config`

**Requires `@testchimp/cli` ≥ `0.1.14`.**

| Flag | Required | Maps to JSON field |
|------|----------|-------------------|
| `--id <scanId>` | **Yes** | `scanId` |

**Response (camelCase):**
- Top-level: `scanId`, `status` (enum name string), `releaseLabel`, `environment`, **`dastCheckConfig`** when DAST (preferred), deprecated mirrors `allowActiveScan` / `useEphemeralSandbox`
- `detail` (`ScanDetailProto`): exactly one of **`dastCheckConfig`**, **`sastCheckConfig`**, **`depsCheckConfig`**, **`leaksCheckConfig`** (optional legacy `securityScanDetail`)

**`dastCheckConfig` fields:** `environment` (env tag), `allowActiveScan`, `useEphemeralSandbox` (only meaningful when `allowActiveScan` is true; server clears otherwise), `scope` (`RELEASE_SCOPE` \| `SMOKE` \| `FULL`; default `RELEASE_SCOPE`).

**`sastCheckConfig` fields:** `scope` (`RELEASE_SCOPED` \| `FULL_REPOSITORY`), `rules` (`ESSENTIAL` \| `STANDARD` \| `COMPREHENSIVE`), `severities` (`BugSeverity` list), `baselineGitCommitSha` (required for release-scoped).

**`depsCheckConfig` fields:** `scope` (`RELEASE_DEPENDENCIES` \| `FULL_DEPENDENCY_TREE`), `securityProfile` (`ESSENTIAL` \| `STANDARD` \| `COMPREHENSIVE`), `ignoreVulnerabilitiesWithoutFixes` (default true), `baselineGitCommitSha` (required for release dependencies).

**`leaksCheckConfig` fields:** `scope` (`RELEASE_CHANGES` \| `ALL_REPOSITORY_SECRETS`), `baselineGitCommitSha` (required for release changes).

Agents must **honour** the matching playbook under [`security/`](./security/). Scanners run locally — there are no `run-*-scan` tools; use `report-*-findings` only.

See [`run-release-check.md`](./run-release-check.md).

### `update-scan-progress`

**API:** `POST /api/mcp/update_scan_progress`

**Requires `@testchimp/cli` ≥ `0.1.14`.** Status: `QUEUED` \| `IN_PROGRESS` \| `COMPLETED` \| `EXCEPTION`.
Each scan is a **single** checker type; the category playbook sets `COMPLETED` after a successful `report-*-findings` (or `EXCEPTION` on hard failure).

| Flag | Required | Maps to JSON field |
|------|----------|-------------------|
| `--id <scanId>` | **Yes** | `scanId` |
| `--status <status>` | **Yes** | `status` |

### `report-dast-findings`

**API:** `POST /api/mcp/report_dast_findings`

**Requires `@testchimp/cli` ≥ `0.1.14`.** Reads ZAP Traditional JSON from disk (not argv). Does **not** set scan status — DAST playbook calls `update-scan-progress COMPLETED` after success.

| Flag | Required | Maps to JSON field |
|------|----------|-------------------|
| `--id <scanId>` | **Yes** | `scanId` |
| `--report-file <path>` | **Yes** | (file → `reportJson`) |

### `report-sast-findings`

**API:** `POST /api/mcp/report_sast_findings`

**Requires `@testchimp/cli` ≥ `0.1.15`.** Reads full Semgrep CLI JSON from disk. Does **not** set scan status — SAST playbook calls `update-scan-progress COMPLETED` after success.

| Flag | Required | Maps to JSON field |
|------|----------|-------------------|
| `--id <scanId>` | **Yes** | `scanId` |
| `--report-file <path>` | **Yes** | (file → `reportJson`) |

### `report-secrets-findings`

**API:** `POST /api/mcp/report_secrets_findings`

**Requires `@testchimp/cli` ≥ `0.1.15`.** Reads full Gitleaks JSON from disk. Server redacts secret payloads before storing. Does **not** set scan status — secrets playbook calls `update-scan-progress COMPLETED` after success.

| Flag | Required | Maps to JSON field |
|------|----------|-------------------|
| `--id <scanId>` | **Yes** | `scanId` |
| `--report-file <path>` | **Yes** | (file → `reportJson`) |

### `report-deps-findings`

**API:** `POST /api/mcp/report_deps_findings`

**Requires `@testchimp/cli` ≥ `0.1.15`.** Reads full Trivy JSON from disk. Does **not** set scan status — deps playbook calls `update-scan-progress COMPLETED` after success.

| Flag | Required | Maps to JSON field |
|------|----------|-------------------|
| `--id <scanId>` | **Yes** | `scanId` |
| `--report-file <path>` | **Yes** | (file → `reportJson`) |

See [`run-release-check.md`](./run-release-check.md).

### `upsert-screen-states`

**API:** `POST /api/mcp/upsert_screen_states`

Merge **`screenStates`** into the relational atlas (idempotent). Body uses **camelCase** per tool schema.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|-------|
| `--json-input <json>` | **Yes** (typical) | `screenStates` | Array of `{ "screen": "…", "states": ["…", …] }`. |

**Example (inline JSON):**

```bash
testchimp upsert-screen-states --json-input '{"screenStates":[{"screen":"TestPlanning","states":["explorer_ready","insights_tab_open"]}]}'
```

**Example (body from file — avoids shell quoting issues):**

```bash
testchimp upsert-screen-states --json-input @./screen-states.json
```

`screen-states.json` should be a JSON object containing **`screenStates`**: `[{ "screen": "…", "states": ["…"] }, …]` (camelCase). The command is **idempotent**: safe to re-run when extending **`states`** for an existing **`screen`**.

---

## Plans (user stories and scenarios)

### `get-user-stories`

**API:** `POST /api/mcp/get_user_stories`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--user-story-ordinal-ids <csv>` | **Yes**\* | `userStoryOrdinalIds` | Numeric parts of **`US-<n>`** (e.g. `118` for `US-118`). |
| `--json-input …` | No | (merge) | May supply **`userStoryOrdinalIds`** array instead of flag. |

\*At least one ordinal id is required (via flag or JSON).

**Response:** `userStories[]` with `ordinalId`, `title`, `platformFilePath`, `content` (full markdown). Missing ids appear in `errors[]`.

**Example:**

```bash
testchimp get-user-stories --user-story-ordinal-ids 118,120
```

### `get-test-scenarios`

**API:** `POST /api/mcp/get_test_scenarios`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--scenario-ordinal-ids <csv>` | No\* | `scenarioOrdinalIds` | Numeric parts of **`TS-<n>`** (e.g. `107` for `TS-107`). |
| `--external-ids <csv>` | No\* | `externalIds` | Full TMS ids including prefixes (e.g. `C12345`, `PROJ-101`). Server matches exact `external_id` first, then strips prefixes and matches the **numerical** part. |
| `--json-input …` | No | (merge) | May supply **`scenarioOrdinalIds`** and/or **`externalIds`** arrays. |

\*Provide **at least one** of `--scenario-ordinal-ids` or `--external-ids` (via flag or JSON). Requires `@testchimp/cli` ≥ **0.1.26** for `--external-ids`.

**Response:** `testScenarios[]` with `ordinalId`, `title`, `platformFilePath`, `content` (full markdown), `userStoryOrdinalIds[]`, and when present `externalSource` / `externalSystemId`. Missing ids appear in `errors[]`. Multiple scenarios may match one external id (agent should disambiguate).

**Examples:**

```bash
testchimp get-test-scenarios --scenario-ordinal-ids 107
testchimp get-test-scenarios --external-ids C12345,PROJ-101
```

Use **`get-test-scenarios`** first when a prompt references **`TS-<n>`**; call **`get-user-stories`** for each linked story ordinal returned. During **`/testchimp import`**, use `--external-ids` to resolve TMS tags to TestChimp scenarios.

### `list-test-scenarios-for-scope`

Requires `@testchimp/cli` ≥ **0.1.79**.

**API:** `POST /api/mcp/list_test_scenarios_for_scope`

Light listing of in-scope scenarios (`ordinalId` + `title` only). Provide **exactly one** locator. Do **not** use **`get-test-scenarios`** to discover a set — that tool is a detail fetch by known ordinal / TMS id.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--named-test-run-id <id>` | No\* | `namedTestRunId` | Unique named test-run id. For execution, forward the same value as `TESTCHIMP_TEST_RUN_ID`; do not use the generated batch invocation id. |
| `--release <label>` | No\* | `release` | Release catalog version / label. Empty focus areas = all plans (`plans/stories` + `plans/scenarios`). |
| `--plans-path <path>` | No\* | `plansPath` | Platform plans folder or `.md` file, e.g. `plans/scenarios/checkout` or `plans/scenarios/checkout/login.md`. |
| `--json-input …` | No | (merge) | May supply **`namedTestRunId`**, **`release`**, or **`plansPath`**. |

\*Provide **exactly one** of `--named-test-run-id`, `--release`, or `--plans-path` (via flag or JSON).

**Response:** `scenarios[]` with `ordinalId`, `title`. Empty scope → empty list (not an error). Archived named test runs and missing locators return 400.

**Examples:**

```bash
testchimp list-test-scenarios-for-scope --named-test-run-id 01TESTRUN0000000000000001
testchimp list-test-scenarios-for-scope --release '1.2.0'
testchimp list-test-scenarios-for-scope --plans-path plans/scenarios/checkout
testchimp list-test-scenarios-for-scope --plans-path plans/scenarios/checkout/login.md
```

Use from **`/testchimp execute tests`** for plans / release / named test run scopes, then grep SmartTest annotations for `#TS-<n>`. Release scope sets `TESTCHIMP_RELEASE`; named test-run scope sets `TESTCHIMP_TEST_RUN_ID` without looking up the release (the backend resolves it from the unique run id). See [`execute-tests.md`](./execute-tests.md).

### `get-spec-lifecycle-details`

Requires `@testchimp/cli` ≥ **0.1.30**.

**API:** `POST /api/mcp/get_spec_lifecycle_details`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--scenario-ids <csv>` | No\* | `scenarioIds` | Bare ordinals (canonical) or `TS-107` / `#TS-107`. |
| `--story-ids <csv>` | No\* | `storyIds` | Bare ordinals (canonical) or `US-12` / `#US-12`. |
| `--json-input …` | No | (merge) | May supply **`scenarioIds`** and/or **`storyIds`** string arrays. |

\*Provide **at least one** of `--scenario-ids` or `--story-ids`.

**Response:** `scenarios[]` / `stories[]` each with `ordinalId` and `lifecycleFields` (map). Invalid or missing ids appear in `errors[]`.

**Example:**

```bash
testchimp get-spec-lifecycle-details --scenario-ids 107,108
testchimp get-spec-lifecycle-details --scenario-ids TS-107 --story-ids 12,US-15
```

Use after identifying scenarios for **`/testchimp create tests`**: skip any scenario where `lifecycleFields.verification_strategy` is **`manual`** (missing → treat as **`auto`**).

### `get-requirement-quality-report`

Requires `@testchimp/cli` ≥ **0.1.19**.

**API:** `POST /api/mcp/get_requirement_quality_report`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--subject-type <STORY\|SCENARIO>` | **Yes**\* | `subjectType` | `STORY` for US-&lt;n&gt;, `SCENARIO` for TS-&lt;n&gt;. |
| `--subject-entity-id <id>` | No† | `subjectEntityId` | Platform entity id (story DB id string or scenario UUID). |
| `--ordinal-id <n>` | No† | `ordinalId` | Numeric part of US-&lt;n&gt; / TS-&lt;n&gt;; server resolves entity when id omitted. |
| `--json-input …` | No | (merge) | May supply full body. |

\*Subject type required. †Provide **`subjectEntityId`** or **`ordinalId`** (at least one).

**Response:** `report` (`metrics`, `findings` with `userState`, `subject`, `source`, timestamps) when stored. When never analyzed, still returns a minimal `report.subject` with resolved `subjectEntityId` so a first-run report can be uploaded. Use findings with **`userState`** **`IGNORED`** / **`APPLIED`** for re-run dedupe — do not re-report equivalents.

**Example:**

```bash
testchimp get-requirement-quality-report --subject-type STORY --ordinal-id 42
```

### `report-requirement-quality-findings`

Requires `@testchimp/cli` ≥ **0.1.19**.

**API:** `POST /api/mcp/report_requirement_quality_findings`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--report-file <path>` | No‡ | (loads `report`) | Full **RequirementQualityReport** JSON (camelCase). |
| `--subject-type <STORY\|SCENARIO>` | No | (merge into `report.subject`) | |
| `--subject-entity-id <id>` | No | (merge into `report.subject`) | Required in report unless resolvable via ordinal + get-report. |
| `--ordinal-id <n>` | No | (merge into `report.subject`) | |
| `--json-input …` | No | (merge) | May supply `{"report":{...}}` instead of `--report-file`. |

‡Report body required via **`--report-file`**, **`--json-input`**, or nested **`report`** in JSON.

**Response:** `report` with server-assigned ids, merged findings (IGNORED/APPLIED carry-forward), fingerprints.

**Example:**

```bash
testchimp report-requirement-quality-findings \
  --report-file ./defospam-report.json \
  --subject-type STORY \
  --ordinal-id 42
```

See [`run-requirement-quality-checks.md`](./run-requirement-quality-checks.md) for the **`/testchimp analyze requirement`** agent playbook.

### `get-manual-session-details`

**API:** `POST /api/mcp/get_manual_session_details`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--manual-session-id <id>` | **Yes**\* | `manualSessionId` | Manual session id (same as `job_id` in manual session viewer URL). |
| `--json-input …` | No | (merge) | May supply **`manualSessionId`** instead of flag. |

\*Session id is required (via flag or JSON).

**Response:** `projectId`, `manualSessionId`, `title`, `status`, `environment`, `release`, `branchName`, `steps[]` (`stepId`, `description`, `code`, `screenshotUrl`, `notes[]`), `linkedScenarios[]` (`scenarioOrdinalId`, `scenarioTitle`), `linkedScenarioOrdinalIds[]` (deduplicated). `screenshotUrl` is a short-lived signed URL for GCS paths; omitted for inline `data:` URLs (use `code` / `notes` instead).

**Example:**

```bash
testchimp get-manual-session-details --manual-session-id 01JABCDEF123456789
```

Use when the user pastes a **Copy test generate prompt** / **Copy prompt** (or legacy **Copy script generate prompt**) from the manual session viewer. Then load linked scenarios from the mapped **`plans/scenarios/`** tree or call **`get-test-scenarios --scenario-ordinal-ids`** once with all values from **`linkedScenarioOrdinalIds`**. See [`author-test-from-manual-session.md`](./author-test-from-manual-session.md).

### `get-meeting-transcript`

Requires `@testchimp/cli` ≥ **0.1.81**.

**API:** `POST /api/mcp/get_meeting_transcript`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--meeting-id <id>` | **Yes**\* | `meetingId` | Calendar event id, or URL hash for ad-hoc meetings (same id as the Studio folder name under `~/.testchimp/data/meetings/`). |
| `--summary-only` | No | `summaryOnly` | CLI ≥ **0.1.82**. Return only the post-meeting summary (`transcriptMd` empty). Use first; fetch the full transcript only when the summary is insufficient or not ready. |
| `--json-input …` | No | (merge) | May supply **`meetingId`** / **`summaryOnly`** instead of flags. |

\*Meeting id is required (via flag or JSON).

**Response:** `meetingId`, `title`, `startMillis`, `summaryMd`, `summaryStatus`, `transcriptMd`.

**Example:**

```bash
testchimp get-meeting-transcript --meeting-id "<meeting-id>" --summary-only
testchimp get-meeting-transcript --meeting-id "<meeting-id>"
```

Full playbook: [`meeting-transcripts.md`](./meeting-transcripts.md).

### `get-meeting-set`

Requires `@testchimp/cli` ≥ **0.1.82**.

**API:** `POST /api/mcp/get_meeting_set`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--meeting-set-id <id>` | **Yes**\* | `meetingSetId` | ULID from `/testchimp using meeting-set context <id>` (Meetings page → **Start Chat**). |
| `--json-input …` | No | (merge) | May supply **`meetingSetId`** instead of flag. |

\*Meeting-set id is required (via flag or JSON).

**Response:** `meetingSet` with `filters` (labels, date range, participants, participant domains, search text), `meetings[]` (`meetingId`, `title`, `startMillis`, newest first), `truncated`, `createdAtMillis`, `expiresAtMillis`. Sets expire after 7 days (HTTP 410; ask the user to create a new one).

**Example:**

```bash
testchimp get-meeting-set --meeting-set-id "01J9Z3X5V4ABCDEF0123456789"
```

Then fetch each relevant meeting with `get-meeting-transcript --summary-only`, and the full transcript only when needed. Full playbook: [`meeting-transcripts.md`](./meeting-transcripts.md).

### `list-meetings`

Requires `@testchimp/cli` ≥ **0.1.83**.

**API:** `POST /api/mcp/list_meetings`

Lists and searches **team-wide** Meeting Bots meetings (visibility: all team members), newest first. It uses the same filters as the Meetings page. Filters combine with AND; values within one filter combine with OR.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--from <date>` | No | `startDateMillis` | Inclusive. `YYYY-MM-DD` (local start of day), ISO datetime, or epoch millis. JSON may pass `from` or raw `startDateMillis`. |
| `--to <date>` | No | `endDateMillis` | Inclusive. `YYYY-MM-DD` (local end of day), ISO datetime, or epoch millis. JSON may pass `to` or raw `endDateMillis`. |
| `--label <label>` | No | `labels[]` | Repeatable or comma-separated; case-insensitive. |
| `--participant <emailOrUserId>` | No | `participantKeys[]` | Repeatable or comma-separated. Participant `key` from `list-meeting-filter-options`, or an email. |
| `--domain <domain>` | No | `participantDomains[]` | Repeatable or comma-separated (e.g. `acme.com`). |
| `--search <text>` | No | `searchText` | Full-text over title + transcript (web-search syntax). |
| `--page-size <n>` | No | `pageSize` | Default 50, max 200 (max 25 with `--search`). |
| `--page-token <token>` | No | `pageToken` | `nextPageToken` from the previous page. |
| `--json-input …` | No | (merge) | May supply any field above. |

**Response:** `meetings[]` with `meetingId`, `title`, `startMillis`, `labels`, `participants[]`, `summaryStatus`, `searchSnippet` (search results only; matches wrapped in `⟦ ⟧`), plus `nextPageToken` when more results exist.

**Example:**

```bash
testchimp list-meetings --from 2026-09-01 --to 2026-09-30 --domain acme.com
testchimp list-meetings --label Sales --search "pricing" --page-size 25
```

Then call `get-meeting-transcript --summary-only` per relevant hit. Full playbook: [`meeting-transcripts.md`](./meeting-transcripts.md) § Search meetings.

### `list-meeting-filter-options`

Requires `@testchimp/cli` ≥ **0.1.83**.

**API:** `POST /api/mcp/list_meeting_filter_options`

No flags. Returns the filter values seen on team-wide meetings: `labels[]`, `participants[]` (`key`, `userId`, `email`, `displayName`; pass `key` to `list-meetings --participant`), and `domains[]`.

```bash
testchimp list-meeting-filter-options
```

### `get-issue-details`

Requires `@testchimp/cli` ≥ **0.1.16**.

**API:** `POST /api/mcp/get_issue_details`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--issue-id <id>` | **Yes**\* | `issueId` | Accepts `#B-123`, `B-123`, `#B123`, `B123`, or plain `123`. |
| `--json-input …` | No | (merge) | May supply **`issueId`**. |

\*Issue id is required (via flag or JSON).

**Response:** `issue` with `ordinalId`, `title`, `description`, `status`, `severity`, `issueType`, `bugHash`, `assignee`, `reportedReleaseId`, `linkedEntities[]` (`entityType`, `entityId`, `displayTitle`), `screenshotGcsPath` / `screenshotUrl`, `stepArtifactGcsPath` / `stepArtifactUrl`, `artifactReference`, `attachments[]` (`filename`, `url`, `gcsPath`). GCS paths are signed into short-lived public URLs when possible.

**Example:**

```bash
testchimp get-issue-details --issue-id "#B-123"
testchimp get-issue-details --issue-id 123
```

### `update-issue-status`

Requires `@testchimp/cli` ≥ **0.1.16**.

**API:** `POST /api/mcp/update_issue_status`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--issue-id <id>` | **Yes**\* | `issueId` | Same flexible formats as `get-issue-details`. |
| `--status <status>` | **Yes**\* | `status` | `ACTIVE` \| `IGNORED` \| `FIXED` \| `DUPLICATE` \| `IN_PROGRESS_BUG` \| `ARCHIVED_BUG` \| `BLOCKED`. |
| `--ignore-reason <reason>` | No | `ignoreReason` | When `status=IGNORED`: `INTENDED_BEHAVIOUR` \| `INACCURATE_ASSESSMENT` \| `NOT_IMPORTANT`. |
| `--json-input …` | No | (merge) | May supply fields instead of flags. |

\*Required via flags or JSON.

**Status side effects:** updates the issue in the project DB (same activity logging path as the UI). For `/testchimp fix issue`, set `IN_PROGRESS_BUG` after applying a code fix; set `FIXED` only after user confirmation or after commits are pushed.

**Example:**

```bash
testchimp update-issue-status --issue-id B-123 --status IN_PROGRESS_BUG
testchimp update-issue-status --issue-id 123 --status FIXED
```

### `create-issue`

Requires `@testchimp/cli` ≥ **0.1.17**.

**API:** `POST /api/mcp/create_issue`

**When to use:** File a **new** TestChimp issue in the current project (MCP preferred; CLI fallback). Use when the user asks to create/file a bug, suggestion, observation, or task — or when an agent finds a product defect that is **not** already auto-filed (e.g. ExploreChimp pipeline bugs). **`/testchimp implement`** creates one **`TASK_ISSUE`** per planned task with **`severity`**, **`category`**, label **`TestChimp Implement`**, and **`linkTargets`** to the parent **story** and in-scope **scenario(s)** (see [`implement-requirement.md`](./implement-requirement.md)). Do **not** use this to update an existing issue (use `update-issue-status` / `get-issue-details`) or to fix one (`/testchimp fix issue`).

**Agent rules:**
- **`title` is required** (flag or JSON). Prefer a concrete, actionable title.
- Defaults when omitted: **`status=ACTIVE`**; **`environment`** defaults server-side to QA when unset.
- Prefer **`linkTargets`** (via `--json-input`) to attach stories, scenarios, tests, executions, or batch invocations so the issue is traceable. For implement tasks, include **`STORY`** and/or **`SCENARIO`** with **numeric plan ordinals** as **`toEntityId`** whenever those ids are known (server resolves ordinals to internal entity ids).
- Use simple flags for common creates; use **`--json-input`** for the full curated contract (`linkTargets`, `attachments`, `artifactReference`, enums below).
- **`labels`** are free-form (server lowercases/canonicalizes). **`source`** is optional and stored as label `source:<name>` — use for generic agent ingest ids, **not** for implement tasks.
- **Implement tasks (`/testchimp implement`):** set **`issueType: TASK_ISSUE`**, **`labels: ["TestChimp Implement"]`** (do **not** use `source: testchimp-implement`), **`severity`** from agent priority, **`category`** from agent judgment, and **`linkTargets`** for story + scenario(s) using ordinals.
- Project is resolved from the API key — do not invent project ids.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--title <title>` | **Yes**\* | `title` | Non-empty after trim. |
| `--description <text>` | No | `description` | Markdown supported. |
| `--issue-type <type>` | No | `issueType` | `BUG_ISSUE` \| `SUGGESTION_ISSUE` \| `OBSERVATION_ISSUE` \| `TASK_ISSUE`. |
| `--category <category>` | No | `category` | `FUNCTIONAL` \| `SECURITY` \| `ACCESSIBILITY` \| `PERFORMANCE` \| `VISUAL` \| `NETWORK` \| `USABILITY` \| `COMPATIBILITY` \| `DATA_INTEGRITY` \| `INTERACTION` \| `LOCALIZATION` \| `RESPONSIVENESS` \| `LAYOUT` \| `VISUAL_REGRESSION` \| `MEMORY` \| `PERFORMANCE_REGRESSION` \| `MEMORY_REGRESSION` \| `FORM_VALIDATION_BUG` \| `OTHER`. |
| `--severity <severity>` | No | `severity` | `LOW_SEVERITY` \| `MEDIUM_SEVERITY` \| `HIGH_SEVERITY` \| `CRITICAL_SEVERITY`. |
| `--status <status>` | No | `status` | Same enum as `update-issue-status`. Default **`ACTIVE`**. |
| `--reported-release-id <id>` | No | `reportedReleaseId` | Release label/id. |
| `--due-date-millis <ms>` | No | `dueDateMillis` | UTC epoch millis. |
| `--assignee <userId>` | No | `assignee` | Platform user id. |
| `--labels <csv>` | No | `labels` | Comma-separated → string array. |
| `--source <name>` | No | `source` | Becomes label `source:<name>`. |
| `--environment <name>` | No | `environment` | Env tag (defaults to QA when omitted). |
| `--json-input …` | No | (merge) | Full body including **`linkTargets`**: `[{ "toEntityType": "SCENARIO"\|"STORY"\|"TEST"\|"ISSUE"\|"EXTERNAL"\|"TEST_EXECUTION"\|"BATCH_INVOCATION", "toEntityId": "…" }]`. For **`STORY`** / **`SCENARIO`**, pass the **numeric plan ordinal** (server resolves to internal id). Also `attachments`, `artifactReference`. |

\*Required via `--title` or `--json-input`.

**Response:** `status` (`ok`), `ordinalId`, `issueId` (e.g. `B-42`), and `issue` (`McpIssueDetails` — same shape as `get-issue-details`).

**Examples:**

```bash
# Minimal
testchimp create-issue --title "Checkout button disabled on empty cart"

# Typed bug with severity + category
testchimp create-issue \
  --title "XSS in profile bio" \
  --description "Bio renders unsanitized HTML." \
  --issue-type BUG_ISSUE \
  --category SECURITY \
  --severity HIGH_SEVERITY \
  --source agent-qa

# Full contract (links + optional fields) via JSON
testchimp create-issue --json-input '{
  "title": "Flaky login redirect",
  "description": "Observed after seed user login.",
  "issueType": "BUG_ISSUE",
  "category": "FUNCTIONAL",
  "severity": "MEDIUM_SEVERITY",
  "linkTargets": [
    { "toEntityType": "SCENARIO", "toEntityId": "101" },
    { "toEntityType": "BATCH_INVOCATION", "toEntityId": "01JABCDEF" }
  ],
  "labels": ["login"],
  "source": "testchimp-agent",
  "environment": "QA"
}'

# Implement workflow: task linked to story + scenario, with severity/category/label
testchimp create-issue --json-input '{
  "title": "Add policy upsert API",
  "issueType": "TASK_ISSUE",
  "status": "ACTIVE",
  "severity": "HIGH_SEVERITY",
  "category": "FUNCTIONAL",
  "labels": ["TestChimp Implement"],
  "linkTargets": [
    { "toEntityType": "STORY", "toEntityId": "42" },
    { "toEntityType": "SCENARIO", "toEntityId": "107" }
  ]
}'
# After that task's code work completes:
testchimp update-issue-status --issue-id B-42 --status FIXED
```

MCP: `create-issue` with the same JSON fields (no CLI flag mapping).

### `create-user-story`

**API:** `POST /api/mcp/create_user_story`

**Agent rule:** Call **before** writing any new `plans/stories/**/*.md`. Response includes **`content`** (stub with **`id: US-<ordinalId>`** already set) — **Write that content** to disk, edit the body if needed, then **`update-user-story`**. Never omit `id:`. Updates reject missing `id` with a clear error.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--platform-file-path <path>` | **Yes** | `platformFilePath` | Under **`plans/stories/`**, must end with **`.md`**. |
| `--title <title>` | **Yes** | `title` | |
| `--json-input …` | No | (merge) | |

### `create-test-scenario`

**API:** `POST /api/mcp/create_test_scenario`

**Agent rule:** Call **before** writing any new `plans/scenarios/**/*.md`. Response includes **`content`** (stub with **`id: TS-<ordinalId>`** and **`story: US-<n>`** already set) — **Write that content** to disk, edit the body if needed, then **`update-test-scenario`**. Never omit `id:` (linking `story:` alone is not enough). Updates reject missing `id`/`story` with a clear error.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--platform-file-path <path>` | **Yes** | `platformFilePath` | Under **`plans/scenarios/`**, must end with **`.md`**. |
| `--title <title>` | **Yes** | `title` | |
| `--user-story-ordinal-id <n>` | **Yes** | `userStoryOrdinalId` | Positive integer; numeric part of parent **`US-<n>`**. |
| `--json-input …` | No | (merge) | |

### `update-user-story`

**API:** `POST /api/mcp/update_user_story`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--content <markdown>` | One of content / file / JSON | `content` | Full markdown including YAML frontmatter. |
| `--content-file <path>` | One of content / file / JSON | `content` | Read file as UTF-8. |
| `--json-input …` | No | (merge) | May supply **`content`** instead of flags. |

At least one of **`--content`**, **`--content-file`**, or **`content` inside `--json-input`** is required.

### `update-test-scenario`

**API:** `POST /api/mcp/update_test_scenario`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--content <markdown>` | One of content / file / JSON | `content` | Full markdown including frontmatter. |
| `--content-file <path>` | One of content / file / JSON | `content` | |
| `--json-input …` | No | (merge) | May supply **`content`**. |

Same requirement as **`update-user-story`**: provide content via flag(s) or JSON.

---

## Branch URL and EaaS (BunnyShell)

### `get-eaas-config`

**API:** `POST /api/mcp/get_eaas_config`

| Flag | Required | Notes |
|------|----------|--------|
| `--json-input …` | No | Body is normally empty; JSON merge rarely needed. |

### `get-branch-specific-endpoint-config`

**API:** `POST /api/mcp/get_branch_specific_endpoint_config`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--branch-name <s>` | No | `branchName` | |
| `--json-input …` | No | (merge) | |

### `provision-ephemeral-environment-and-wait`

**API:** orchestrates provision + poll (stderr progress).

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--branch-name <s>` | No | `branchName` | |
| `--poll-interval-seconds <n>` | No | `pollIntervalSeconds` | Number. |
| `--max-wait-minutes <n>` | No | `maxWaitMinutes` | Number. |
| `--json-input …` | No | (merge) | |

### `provision-ephemeral-environment`

**API:** `POST /api/mcp/provision_ephemeral_environment`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--branch-name <s>` | No | `branchName` | |
| `--json-input …` | No | (merge) | |

### `get-ephemeral-environment-status`

**API:** `POST /api/mcp/get_ephemeral_environment_status`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--bns-environment-id <id>` | **Yes** | `bnsEnvironmentId` | |
| `--json-input …` | No | (merge) | |

### `destroy-ephemeral-environment`

**API:** `POST /api/mcp/destroy_ephemeral_environment`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--bns-environment-id <id>` | **Yes** | `bnsEnvironmentId` | |
| `--json-input …` | No | (merge) | |

### `list-bunnyshell-environment-events`

**API:** `POST /api/mcp/list_bunnyshell_environment_events`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--bns-environment-id <id>` | **Yes** | `bnsEnvironmentId` | |
| `--event-type <s>` | No | `eventType` | |
| `--event-status <s>` | No | `eventStatus` | |
| `--page <n>` | No | `page` | Positive integer. |
| `--json-input …` | No | (merge) | |

### `list-bunnyshell-workflow-jobs`

**API:** `POST /api/mcp/list_bunnyshell_workflow_jobs`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--bns-environment-id <id>` | **Yes** | `bnsEnvironmentId` | |
| `--page <n>` | No | `page` | Positive integer. |
| `--json-input …` | No | (merge) | |

### `get-bunnyshell-workflow-job-logs`

**API:** `POST /api/mcp/get_bunnyshell_workflow_job_logs`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--bns-environment-id <id>` | **Yes** | `bnsEnvironmentId` | |
| `--workflow-job-id <id>` | **Yes** | `workflowJobId` | |
| `--json-input …` | No | (merge) | |

---

## TrueCoverage

MCP/CLI TrueCoverage endpoints deserialize the POST body with **Protobuf `JsonFormat`** (same as `/rum/analytics/*` in featureservice). Use **camelCase** JSON keys everywhere (proto sources use `snake_case`; **do not** send `snake_case` in JSON).

- **Proto sources:** `rum_service.proto` (`ListEventsRequest`, `GetEventDetailsRequest`, …), `common.proto` (`TimeWindow`, `TypedValue`).
- **Invocation:** seed common fields with flags (`--environment`, `--relative-window`, `--platform`, `--event-title`, …) and/or pass full bodies with **`--json-input '<json>'`** (JSON wins on merge). **`get-truecoverage-event-metadata-keys`** needs **`--event-title`** or `eventTitle` in JSON. Set **`platform`** inside each **`ExecutionScope`** (same as **`environment`**, **`timeWindow`**, etc.).
- **Time window (required):** nest under **`timeWindow`**. CLI **`--relative-window 604800s`** seeds `timeWindow: { relativeWindow: "604800s" }` on the base scope. In JSON/MCP, use **`"timeWindow":{"relativeWindow":"604800s"}`** (Duration string ending in **`s`**). **Do not** put flat **`relativeWindow`** (or `{ "seconds": … }`) as a sibling of **`environment`** on the scope — `@testchimp/cli` ≥ **0.1.11** rejects that shape.
- **RUM ingest:** client SDKs stamp platform on every batch via HTTP header **`testchimp-rum-platform`** (`1` = web, `2` = iOS, `3` = Android). Analytics scopes filter on the stored enum, not on request-body platform fields on individual events.

### Scope-seeding flags (TrueCoverage analytics tools)

These seed **`baseExecutionScope`** / **`baseScope`** (JSON merges on top; JSON wins):

| Flag | Seeds |
|------|--------|
| `--environment <s>` | `environment` |
| `--relative-window <duration>` | `timeWindow.relativeWindow` (e.g. `604800s`) |
| `--platform <web\|ios\|android>` | `platform` (aliases or `WEB_` / `IOS_` / `ANDROID_EXECUTION_PLATFORM`) |
| `--release <s>` | `release` |
| `--branch-name <s>` | `branchName` |

Also: `--event-title`, `--next-event-title`, `--metric-type` on the tools that need them.

### TrueCoverage subcommand → API route

| Subcommand | API route (POST) | `--json-input` body (proto message) |
|------------|------------------|-------------------------------------|
| `list-rum-environments` | `/api/mcp/list_rum_environments` | Empty object **`{}`**. |
| `get-truecoverage-events` | `/api/mcp/truecoverage_list_events` | **`ListEventsRequest`** |
| `get-truecoverage-event-details` | `/api/mcp/truecoverage_event_details` | **`GetEventDetailsRequest`** |
| `get-truecoverage-child-event-tree` | `/api/mcp/truecoverage_list_child_event_tree` | **`ListChildEventTreeRequest`** |
| `get-truecoverage-event-transition` | `/api/mcp/truecoverage_detailed_event_transition` | **`GetDetailedEventTransitionSummaryRequest`** |
| `get-truecoverage-event-time-series` | `/api/mcp/truecoverage_event_time_series` | **`EventTimeSeriesRequest`** |
| `get-truecoverage-session-metadata-keys` | `/api/mcp/truecoverage_session_metadata_keys` | Empty object **`{}`**. |
| `get-truecoverage-event-metadata-keys` | `/api/mcp/truecoverage_event_metadata_keys` | **`ListEventMetadataKeysRequest`** (or flag; see row below) |

For **`get-truecoverage-event-metadata-keys`**, supply **`eventTitle`** via **`--event-title <title>`** or inside **`--json-input`** as **`{"eventTitle":"…"}`** (merged; JSON wins if both set).

### JSON encoding rules (protobuf JSON mapping)

| Concept | JSON shape |
|--------|------------|
| Field names | **camelCase** (e.g. `branchName`, `baseExecutionScope`, `timeWindow`). |
| Enums | **String** enum name, e.g. **`"EQUALS"`**, **`"SESSION_COUNT"`**, **`"WEB_EXECUTION_PLATFORM"`** (not numeric wire values). |
| `google.protobuf.Timestamp` | **RFC 3339** string, e.g. **`"2024-03-05T00:00:00.000Z"`**. |
| `google.protobuf.Duration` | **String** ending in **`s`**, e.g. **`"604800s"`** (seven days), **`"1.5s"`**. Do **not** rely on `{ "seconds": … }` objects for MCP JSON; use the string form. |
| `oneof` | Only the chosen branch’s field appears (e.g. either **`relativeWindow`** or **`fixedWindow`** under **`timeWindow`**, not both). |
| Optional fields | Omit when unused. |

### Shared types (use inside execution scopes)

#### `TypedValue` (for metadata filter values)

Exactly **one** of:

| Field | Type | Meaning |
|-------|------|--------|
| `stringValue` | string | |
| `intValue` | string (preferred) or number | Protobuf JSON often uses **string** for int64; use strings for large integers. |
| `floatValue` | number | |
| `boolValue` | boolean | |

#### `MetadataFilterOperator` (enum string)

`UNKNOWN_OPERATOR` \| `EQUALS` \| `NOT_EQUALS` \| `GREATER_THAN` \| `LESS_THAN`

#### `MetadataFilter`

| Field | Type | Notes |
|-------|------|--------|
| `key` | string | Session metadata key. |
| `value` | object (`TypedValue`) | |
| `operator` | string (`MetadataFilterOperator`) | |

#### `TimeWindow` (oneof)

| Branch | Type | Notes |
|--------|------|--------|
| `relativeWindow` | **string** (`Duration`) | e.g. **`"2592000s"`** (30 days). |
| `fixedWindow` | object | See below. |

**`fixedWindow`**

| Field | Type |
|-------|------|
| `startTime` | string (`Timestamp`, RFC 3339) |
| `endTime` | string (`Timestamp`, RFC 3339) |

#### `ExecutionScope`

| Field | Type | Notes |
|-------|------|--------|
| `environment` | string | **Required** for meaningful queries — RUM environment tag (e.g. `production`, `QA`). |
| `timeWindow` | object (`TimeWindow`) | **Required** — nest `relativeWindow` / `fixedWindow` **here**. Flat `relativeWindow` on the scope is invalid. |
| `release` | string | Optional filter. |
| `branchName` | string | Optional filter. |
| `metadataFilters` | array of `MetadataFilter` | Optional. |
| `platform` | string (`ExecutionPlatform`) | Optional — **`WEB_EXECUTION_PLATFORM`**, **`IOS_EXECUTION_PLATFORM`**, **`ANDROID_EXECUTION_PLATFORM`**. Filters rows stamped at ingest (RUM header **`testchimp-rum-platform`**). Omit to include all platforms in the scope’s environment/window. |
| `automationEmitsOnly` | boolean | When **`true`** on **`comparisonExecutionScope`** (or coverage-style scopes below), coverage alignment uses only RUM emits that carry **test** identity (`test_id`). **Ignored** for **`baseExecutionScope`** / **`baseScope`** per proto comments. |

### Per-request JSON payloads (`--json-input`)

#### `ListEventsRequest` — `get-truecoverage-events`

| Field | Type | Notes |
|-------|------|--------|
| `baseExecutionScope` | `ExecutionScope` | Baseline funnel / session set. |
| `comparisonExecutionScope` | `ExecutionScope` | Optional second scope (e.g. coverage-aligned). |

#### `GetEventDetailsRequest` — `get-truecoverage-event-details`

| Field | Type | Notes |
|-------|------|--------|
| `baseExecutionScope` | `ExecutionScope` | |
| `comparisonExecutionScope` | `ExecutionScope` | Optional. |
| `eventTitle` | string | **Required** — which event’s detail view. |

#### `ListChildEventTreeRequest` — `get-truecoverage-child-event-tree`

| Field | Type | Notes |
|-------|------|--------|
| `eventTitle` | string | Parent event. |
| `baseScope` | `ExecutionScope` | |
| `coverageScope` | `ExecutionScope` | Used for coverage columns. |

**Note:** `metadataFilters` inside scopes are **ignored** for transition funnel stats (proto).

#### `GetDetailedEventTransitionSummaryRequest` — `get-truecoverage-event-transition`

| Field | Type | Notes |
|-------|------|--------|
| `eventTitle` | string | From event. |
| `nextEventTitle` | string | To event. |
| `baseScope` | `ExecutionScope` | |
| `coverageScope` | `ExecutionScope` | |

**Note:** `metadataFilters` inside scopes are **ignored** (same as child-event tree).

#### `EventTimeSeriesRequest` — `get-truecoverage-event-time-series`

| Field | Type | Notes |
|-------|------|--------|
| `baseExecutionScope` | `ExecutionScope` | |
| `eventTitle` | string | |
| `metricType` | string | **`EventTimeSeriesMetricType`** enum name — see table below. |

**`EventTimeSeriesMetricType`**

`EVENT_TIME_SERIES_METRIC_UNSPECIFIED` \| `SESSION_COUNT` \| `RELATIVE_FREQUENCY` \| `PERCENTAGE_TERMINAL_EVENT` \| `SESSION_POSITION` \| `TIME_TO_NEXT_EVENT` \| `REVERSE_INDEX` \| `TIME_FROM_START` \| `TIME_TO_END` \| `TIME_SINCE_PREVIOUS_EVENT`

#### `ListEventMetadataKeysRequest` — `get-truecoverage-event-metadata-keys`

| Field | Type | Notes |
|-------|------|--------|
| `eventTitle` | string | **Required** (or **`--event-title`**). |

### Examples

Relative window via flags (last 7 days):

```bash
testchimp get-truecoverage-events --environment QA --relative-window 604800s
```

Same via `--json-input`:

```bash
testchimp get-truecoverage-events --json-input '{"baseExecutionScope":{"environment":"QA","timeWindow":{"relativeWindow":"604800s"}}}'
```

Fixed calendar window:

```bash
testchimp get-truecoverage-events --json-input '{"baseExecutionScope":{"environment":"production","timeWindow":{"fixedWindow":{"startTime":"2026-04-01T00:00:00.000Z","endTime":"2026-04-23T23:59:59.000Z"}}},"comparisonExecutionScope":{"environment":"production","timeWindow":{"relativeWindow":"604800s"},"automationEmitsOnly":true}}'
```

Event details:

```bash
testchimp get-truecoverage-event-details --json-input '{"eventTitle":"Checkout completed","baseExecutionScope":{"environment":"QA","timeWindow":{"relativeWindow":"2592000s"}}}'
```

Prod iOS real users vs QA iOS automation:

```bash
testchimp get-truecoverage-events --json-input '{"baseExecutionScope":{"environment":"prod","platform":"IOS_EXECUTION_PLATFORM","timeWindow":{"relativeWindow":"2592000s"}},"comparisonExecutionScope":{"environment":"QA","platform":"IOS_EXECUTION_PLATFORM","timeWindow":{"relativeWindow":"2592000s"},"automationEmitsOnly":true}}'
```

Deeper product context: [instrument-truecoverage.md](./instrument-truecoverage.md).

---

## Workflows and policies (CLI ≥ 0.1.21)

Policies live under **`plans/knowledge/policies/*.policy.md`**. See [`policies-and-traceability.md`](./policies-and-traceability.md) and [`create-policy.md`](./create-policy.md).

### `get-policy`

**API:** `POST /api/mcp/get_policy`

| Flag | Required | Body field | Notes |
|------|----------|------------|-------|
| `--policy-file-name <name>` | Yes* | `policyFileName` | e.g. `connect-to-test-env.policy.md`, **`global.policy.md`**. Server coerces to `*.policy.md` (same rules as `upsert-policy`). |
| `--json-input` | Yes* | `policyFileName` | Alternative to `--policy-file-name`. |

\*Provide **`policyFileName`** via flag or JSON.

**Global policy:** `testchimp get-policy --policy-file-name global.policy.md` — frontmatter is **`policy-kind: global`** (no `workflow-id`). See [`policies-and-traceability.md`](./policies-and-traceability.md).

### `list-policies`

**API:** `POST /api/mcp/list_policies`

| Flag | Required | Body field | Notes |
|------|----------|------------|-------|
| `--json-input` | Optional | `workflowId` | Filter by frontmatter `workflow-id` |

### `upsert-policy`

**API:** `POST /api/mcp/upsert_policy`

Create or update a policy on the platform immediately after writing the file locally (git push also syncs later).

| Flag | Required | Body field | Notes |
|------|----------|------------|-------|
| `--policy-file-name <name>` | Yes* | `policyFileName` | e.g. `connect-to-test-env.policy.md` (`.policy.md` coerced if missing) |
| `--content <markdown>` | Yes* | `content` | Full markdown including frontmatter |
| `--content-file <path>` | Yes* | `content` | Read markdown from disk (alternative to `--content`) |

\*Or provide both fields via `--json-input`.

```bash
testchimp upsert-policy \
  --policy-file-name connect-to-test-env.policy.md \
  --content-file plans/knowledge/policies/connect-to-test-env.policy.md
```

### `get-plans-support-file`

**API:** `POST /api/mcp/get_plans_support_file`  
**Requires:** CLI ≥ **0.1.32**

Fetch a file under the mapped **plans** root from the platform by relative path. Primary use: load a workflow execution plan named in Continue Locally / implement prompts **before** falling back to the local git copy (UI edits may not be committed).

| Flag | Required | Body field | Notes |
|------|----------|------------|-------|
| `--file-path <path>` | Yes* | `filePath` | Relative to mapped plans root (e.g. `knowledge/workflow_plans/run-qa/<ulid>.plan.md`). Leading `plans/` is stripped. |

\*Or provide `filePath` via `--json-input`.

**Coercion (under `knowledge/workflow_plans/`):** same as upsert (`*_plan.md` / bare `*.md` → **`*.plan.md`**).

**Response (JSON camelCase):**

| Field | Notes |
|-------|-------|
| `found` | `false` if no active file at that path |
| `supportFileId` | Platform support file id when found |
| `filePath` | Canonical relative path after coerce (no leading `plans/`) |
| `filetype` | e.g. `WORKFLOW_EXECUTION_PLAN` |
| `content` | Full file content when found |

```bash
testchimp get-plans-support-file \
  --file-path knowledge/workflow_plans/run-qa/01KXYW2NVMQPN4HQMJFC92KQ8P.plan.md
```

**Agent rule:** When a prompt names a plan file, call this **before** reading the repo copy. If `found: true`, write `content` to the mapped local path and treat that as the plan of record. See [`policies-and-traceability.md`](./policies-and-traceability.md) and **SKILL.md** → Workflow execution plans.

### `upsert-plans-support-file`

**API:** `POST /api/mcp/upsert_plans_support_file`  
**Requires:** CLI ≥ **0.1.24**

Create or update any file under the mapped **plans** root on the platform by relative path — **no git commit/push required**. Primary use: upload workflow execution plans after the Plan phase (especially cloud agents).

| Flag | Required | Body field | Notes |
|------|----------|------------|-------|
| `--file-path <path>` | Yes* | `filePath` | Relative to mapped plans root (e.g. `knowledge/workflow_plans/run-qa/<ulid>.plan.md`). Leading `plans/` is stripped. |
| `--content <markdown>` | Yes* | `content` | Full file content including frontmatter |
| `--content-file <path>` | Yes* | `content` | Read from disk (alternative to `--content`) |

\*Or provide both fields via `--json-input`.

**Coercion (under `knowledge/workflow_plans/`):** `*_plan.md` or bare `*.md` filenames are normalized to **`*.plan.md`** and stored as support filetype **`WORKFLOW_EXECUTION_PLAN`**. Prefer writing the canonical name yourself.

**Response (JSON camelCase):**

| Field | Notes |
|-------|-------|
| `supportFileId` | Platform support file id |
| `filePath` | Canonical relative path after coerce (no leading `plans/`) |
| `filetype` | e.g. `WORKFLOW_EXECUTION_PLAN` |
| `created` | `true` if new row, `false` if updated |

```bash
testchimp upsert-plans-support-file \
  --file-path knowledge/workflow_plans/run-qa/01KXYW2NVMQPN4HQMJFC92KQ8P.plan.md \
  --content-file plans/knowledge/workflow_plans/run-qa/01KXYW2NVMQPN4HQMJFC92KQ8P.plan.md
```

**Agent rule:** After writing a workflow plan file, calling this tool is a **blocking** step before Execute. Use the returned `filePath` if coerce changed the name. See [`policies-and-traceability.md`](./policies-and-traceability.md) and **SKILL.md** → Workflow execution plans.

### `list-workflow-catalog`

**API:** `POST /api/mcp/list_workflow_catalog`

Lists catalog workflows with Active / Disabled / Missing Config for the project. Use `--json-input '{}'` when no flags are needed.

Also related (flags vary): **`report-agent-action`**, **`get-last-run-workflow-detail`**, **`list-workflow-executions`**, **`get-workflow-execution`** — see `testchimp <cmd> -h`. `list-workflow-executions` accepts `pendingApprovalOnly` and (CLI ≥ **0.1.91**) `assignedToMeOnly` (executions whose assignee is the calling user: OAuth user, or the bot's owner with `--bot`).

### `update-workflow-execution-assignees` (CLI ≥ **0.1.91**)

**API:** `POST /api/mcp/update_workflow_execution_assignees`. **Mutating.** Sets the assignee and / or CC list of a workflow execution. Executions get an assignee automatically when their plan-approval or approve-to-invoke notification goes out (the initiator if they're on the team, otherwise the first notified recipient; everyone else notified is CC'd). After that, approval and completion notifications go to the assignee and CC instead of the configured recipients.

Needs a user: an OAuth session, or a project API key **with** `--bot <botId>` (acts as the bot's owner). Plain API keys get 403. The caller must be a team member and either the current assignee or an org admin; the admin override needs an OAuth session (not `--bot`). Anyone on the team can assign an execution that has no assignee yet, and a CC'd user can remove themselves. A CC needs an assignee; adds can't take the CC list past 20 users; the assignee is dropped from CC automatically. New assignee and newly CC'd users get the `workflow-execution-assigned` bot event plus email / Slack per their notification settings. Removals notify nobody.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--workflow-execution-id <id>` | Yes | `workflowExecutionId` | |
| `--assignee <emailOrUserId>` | No | `assigneeEmail` / `assigneeUserId` | Values containing `@` are emails |
| `--add-cc <list>` | No | `addCcEmails` / `addCcUserIds` | Comma-separated emails or user ids |
| `--remove-cc <list>` | No | `removeCcUserIds` | Comma-separated user ids |
| `--json-input …` | No | (merge) | |

Returns the updated `WorkflowExecution` (`assigneeUserId`, `ccUserIds`, `assignmentHistory`). 409: the assignment changed since it was read; re-read and retry. Only change assignees after the user has named the person and approved.

```bash
testchimp --bot <botId> update-workflow-execution-assignees --workflow-execution-id 01J... --assignee dana@acme.com --add-cc lee@acme.com
```

---

## API operations coverage (CLI ≥ **0.1.28**; observability-aware guidance ≥ **0.1.80**)

OpenAPI-backed API operation coverage (same payloads as the Operations UI). Prefer **`rootFilePath`** (repo-relative OpenAPI root) as the service resource id. **TestChimp operation id** = platform ULID (`id`), distinct from OAS `operationId`.

When observability ingress is configured, operation list/detail records also expose:

- `obsMappingState`: `API_OBS_NOT_CONFIGURED`, `API_OBS_MAPPED`, or `API_OBS_UNMAPPED_OBSERVED`.
- `runtimeObservation`: latest finalized production daily summary (latest-hour fallback), with `windowStartMillis`, `windowEndMillis`, `requestCount`, `rpm`, `errorCount`, `errorRate`, `p50LatencyMs`, `p95LatencyMs`, `p99LatencyMs`, `status2xxCount` through `status5xxCount`, and `syncStatus`.

Use fresh successful volume/error metrics to rank uncovered API operations. Use p95/p99 latency to prioritize performance-test creation/upkeep. Missing, stale, partial, no-data, or query-failed observations are unknown—not zero. These production signals select work; they do not define k6 load or thresholds.

Playbooks: [`api-testing.md`](./api-testing.md), [`create-tests.md`](./create-tests.md), [`upkeep.md`](./upkeep.md).

### `list-api-operation-services`

**API:** `POST /api/mcp/list_api_operation_services`

```bash
testchimp list-api-operation-services
```

Returns `services[]` with `rootFilePath`, `serviceKey`, `infoTitle`, `operationCount`.

### `list-api-operations`

**API:** `POST /api/mcp/list_api_operations`

| Flag | Description |
|------|-------------|
| `--root-file-path <path>` | Preferred service resource id (repo-relative OpenAPI root). |
| `--service-key <key>` | Internal service key alias. |
| `--include-manual` | Include MANUAL test_mode coverage in previews. |
| `--include-removed` | Include soft-deleted operations. |

```bash
testchimp list-api-operations --root-file-path services/featureservice/openapi/featureservice.json
```

Each operation includes `id` (TestChimp ULID), method/path, `coveringTestsPreview`, `coverageSummary` (scores), and observability fields above when available.

Omit `--root-file-path` / `--service-key` only when intentionally listing **all** services; prefer a root when more than one service is configured.

### `get-api-operation-detail`

**API:** `POST /api/mcp/get_api_operation_detail`

| Flag | Description |
|------|-------------|
| `--id <ulid>` | **Preferred** — TestChimp operation id. |
| `--root-file-path <path>` | Required with `--http-method` + `--path-template`; preferred with `--oas-operation-id`. |
| `--service-key <key>` | Alias for root resolution. |
| `--oas-operation-id <id>` | OpenAPI operationId (prefer scoped by root/service; project-wide fallback if service omitted). |
| `--http-method <METHOD>` | With `--path-template` **and** root/service. |
| `--path-template <path>` | OpenAPI path template. |
| `--include-manual` / `--include-removed` | Same semantics as list. |

```bash
testchimp get-api-operation-detail --id 01HXYZ...
testchimp get-api-operation-detail \
  --root-file-path services/featureservice/openapi/featureservice.json \
  --http-method POST --path-template /api/mcp/list_api_operations
```

Returns request/query/response field trees and response codes with covering-test tags. `operation.runtimeObservation` carries the same latest daily summary when available. The CLI rejects calls with no lookup identity.

### `list-api-operation-interactions`

**API:** `POST /api/mcp/list_api_operation_interactions` (CLI ≥ **0.1.31**)

Bounded newest-first redacted exemplars. Requires `--test-id` and/or `--operation-id`. Default `--interaction-type REAL`. Limit max 100.

```bash
testchimp list-api-operation-interactions --operation-id 01XYZ --interaction-type REAL --limit 100
```

---

## Performance testing (CLI ≥ 0.1.31)

Soft-gate with `get-org-capabilities` → `PERFORMANCE_TESTING`. Compare prints JSON to stdout; the CLI sets exit code `1` when `comparison.regressed` is `true` (or a flat `regressed: true`). A missing/incompatible baseline is an API error, not a silent pass.

```bash
testchimp list-perf-runs --testchimp-id checkout-journey --kind JOURNEY --limit 20
testchimp get-perf-run --run-id 01ABC --include-raw
testchimp list-perf-baselines --testchimp-id checkout-journey
testchimp promote-perf-baseline --run-id 01ABC --env-class CI
testchimp compare-perf-to-baseline --run-id 01ABC --env-class CI --max-p95-regression-percent 10
testchimp list-related-perf-tests --scenario-titles "Checkout,Refund"
```

`get-requirement-coverage --include-perf` (or `--record-types smart_test,perf_test`) opts into `PERF_TEST` journey coverage without changing SMART_TEST/MANUAL defaults.

---

## Semantic similar tests (`/testchimp cleanup`)

Discover semantically similar SmartTest pairs using **TestLocators** (no platform `test_id`). Used by [`cleanup.md`](./cleanup.md).

### `list-semantic-similar-tests`

| Flag | Description |
|------|-------------|
| `--folder-path <path>` | Scope to folder under tests root (slash-separated). |
| `--json-input <json>` | Full request body; merges over flags. |

Example:

```bash
testchimp list-semantic-similar-tests --json-input '{ "scope": { "folderPath": ["auth"] } }'
```

Response records use camelCase TestLocators and `similarTests` with `classification` (`POTENTIAL_DUPLICATE` or `SIMILAR`). Pairs are deduped (A→B only when A.testId < B.testId).

### `mark-semantic-tests-distinct`

Mark two tests as legitimately distinct (symmetric). Agent/API calls use `marked_by_user_id = "0"`.

```bash
testchimp mark-semantic-tests-distinct --json-input '{
  "focusTest": {
    "folderPath": ["auth"],
    "fileName": "login.spec.ts",
    "testSuite": [],
    "testName": "user can log in"
  },
  "distinctTest": {
    "folderPath": ["auth"],
    "fileName": "signin.spec.ts",
    "testName": "login flow"
  }
}'
```

### `mark-tests-for-review`

Report existing SmartTests that an agent patched so humans can re-verify. **Only** from [`fix-test-execution.md`](./fix-test-execution.md) after **test-incorrect** patches — never from `run-qa` / `create-tests`, and never for product-broken cases. Always send per-test `confidence` 0–100 (higher = less need for human review). Do not read project config. Requires `@testchimp/cli` ≥ **0.1.33**.

```bash
testchimp mark-tests-for-review --json-input '{
  "tests": [
    {
      "test": {
        "folderPath": ["e2e", "auth"],
        "fileName": "login.spec.ts",
        "testName": "user can log in"
      },
      "confidence": 72
    }
  ],
  "workflowExecutionId": "<ulid>",
  "branchName": "feat/login"
}'
```

---

## Semantic nearby across entity types (QA Brain)

Requires `@testchimp/cli` ≥ **0.1.27**.

Find embedding-neighbors across Story / Scenario / Test / Issue / Event. Agents never use platform `test_id` — SmartTests use **TestLocator**; stories/scenarios/issues use **ordinal**; events use **title**.

### `list-semantic-nearby`

```bash
# Nearby tests for scenario ordinal 12
testchimp list-semantic-nearby --json-input '{
  "sourceEntityType": "SCENARIO",
  "sourceOrdinalId": 12,
  "targetEntityTypes": ["TEST"],
  "limit": 20
}'

# Nearby scenarios for a SmartTest
testchimp list-semantic-nearby --json-input '{
  "sourceEntityType": "TEST",
  "sourceTest": {
    "folderPath": ["auth"],
    "fileName": "login.spec.ts",
    "testName": "logs in"
  },
  "targetEntityTypes": ["SCENARIO"]
}'
```

Response buckets include `similarity`, `potentialDuplicate` (same-type), and identity fields (`test` / `ordinalId` / `eventTitle`).

### `mark-entity-distinct` / `unmark-entity-distinct`

Same identity rules as nearby. Prefer these for cross-type cleanup; `mark-semantic-tests-distinct` remains the TestLocator-only TEST wrapper.

```bash
testchimp mark-entity-distinct --json-input '{
  "entityType": "TEST",
  "focusTest": { "folderPath": ["auth"], "fileName": "a.spec.ts", "testName": "a" },
  "otherTest": { "folderPath": ["auth"], "fileName": "b.spec.ts", "testName": "b" }
}'
```

---

## ChimpHands (CLI ≥ **0.1.66** for `refresh-git-auth`)

GitHub Actions agent bridge. Subcommands under **`testchimp chimphands`**:

| Subcommand | Purpose |
| --- | --- |
| `run` / `serve` | Session bridge (used by the ChimpHands workflow; agents rarely invoke directly) |
| `report-branch --branch <name> [--pr-url <url>]` | Persist working branch / PR for the UI |
| **`refresh-git-auth`** | Remint ~1h GitHub App installation token and apply for `git`/`gh` — **never prints the token** |

```bash
# After auth failures on a long-lived ChimpHands job:
testchimp chimphands refresh-git-auth
# stdout: {"ok":true,"repositoryFullName":"org/repo","expiresAtMillis":...}
# then retry git push / gh …
```

Requires `TESTCHIMP_API_KEY` (+ `TESTCHIMP_BACKEND_URL` when configured). Branch/commit contract: [`chimphands.md`](./chimphands.md). Troubleshooting: [`chimphands-faq.md`](./chimphands-faq.md).

---

## QA bots (CLI ≥ **0.1.85**)

Used by QA-bot mode ([`bot-playbook.md`](./bot-playbook.md), [`bot-onboarding.md`](./bot-onboarding.md), [`bot-self-update.md`](./bot-self-update.md)). MCP tool names match the top-level commands; `register-bot-profile` / `ack-bot-events` are exposed on the CLI as `testchimp bot register-profile` / `testchimp bot ack`.

### Project binding (CLI ≥ **0.1.88**)

The bot host shares one TestChimp connector (one OAuth token, the user's) across all of a user's bots, so the connector names the **user** only. Each bot names its **project** with its own binding (`projectId`, `projectName`, `botId`, `projectApiKey`), fetched once with `get-bot-credentials` right after the user authorizes the connector for that bot's project, and stored bot-scoped.

- **Preferred path:** QA bots use the CLI (below) for TestChimp calls; it goes straight to featureservice / ingress. The remote MCP is for `get-bot-credentials`, `approve-agentwatch-pairing`, `invite-team-members` and as a fallback.
- **Remote MCP:** every tool takes optional `projectApiKey` and `botId` arguments. They are sent as `TestChimp-Api-Key` / `bot-id` alongside the connector's bearer: the key decides the project (the user must be a member) and the bearer decides the user. A QA bot token without a key gets 403 "no project binding", except on `get-bot-credentials` and `get-bot-compat`. A remote MCP URL's `?projectId=` does not replace the key for bot tokens (naming another project still gets 403); keep sending `projectApiKey`.
- **CLI:** save the binding once per computer, then add `--bot <botId>` to every command. It loads `~/.testchimp/bots/<botId>.json` and sets `TESTCHIMP_API_KEY`, `TESTCHIMP_BOT_ID` and the stored backend / ingress URLs for that command. These override inherited env, and an inherited `TESTCHIMP_OAUTH_TOKEN` is dropped. With only `TESTCHIMP_BOT_ID` set (no key, no token), the CLI loads that bot's binding if it has one. When an API-key caller sends `bot-id`, it acts as that bot's user, so `--user-id` isn't needed.

| Command | Notes |
| --- | --- |
| `get-bot-credentials` / `testchimp bot get-credentials` | `/api/mcp/get_bot_credentials`. Needs a connection approved with **Use this connection as my QA bot** (`bot_binding` scope), else 403. Returns `{projectId, projectName, botId, projectApiKey, userId, settingsUrl}` for the project picked on the consent page. Never print the key |
| `testchimp bot save-binding --bot-id <id> --project-id <id> [--project-name <n>]` | **Mutating (local file)**. Reads the key from stdin (wins over any inherited `TESTCHIMP_API_KEY`), else from `TESTCHIMP_API_KEY` set on that one command; never from an argument. Writes `~/.testchimp/bots/<botId>.json` (directory 0700, file 0600, `$TESTCHIMP_HOME` overrides) with `TESTCHIMP_BACKEND_URL` / `TESTCHIMP_INGRESS_URL` when set. Prints `{botId, projectId, bindingPath}` |
| `testchimp --bot <botId> <command …>` | Runs any command with that bot's binding. Fails with `No TestChimp binding for bot …` when the file is missing |
| `testchimp --bot <botId> bot exec -- <command …>` | Runs another program (Playwright, k6, a runner) with the binding in its env, without printing the key. Exit code is the program's |
| `testchimp bot remove-binding --bot-id <id>` | **Mutating (local file)**. Deletes the binding file |

```bash
printf '%s' "$KEY" | testchimp bot save-binding --bot-id 01JBOT... --project-id "$PROJECT_ID" --project-name "Payments"
testchimp --bot 01JBOT... get-my-tasks
testchimp --bot 01JBOT... bot exec -- npx playwright test --project=chromium
```

### Bot commands

| Command / tool | Route | Notes |
| --- | --- | --- |
| `get-my-tasks [--user-id <id>]` | `/api/mcp/get_my_tasks` | `assignedScenarios`, `assignedIssues`, `testsAwaitingVerification`. OAuth → token's user; API key with a `bot-id` (`--bot`) → that bot's user; plain API key → `--user-id` required |
| `list-tests-awaiting-verification [--user-id] [--limit]` | `/api/mcp/list_tests_awaiting_verification` | Tests whose executions need human verification for the verified badge |
| `get-qa-posture` | `/api/mcp/get_qa_posture` | Releases, issue counts by status/severity, active test runs, tests awaiting verification count |
| `get-bot-compat` / `testchimp bot compat [--skill-version <v>]` | `/api/mcp/get_bot_compat` | `minSkillVersion`, `minCliVersion`, `eventSchemaVersion`; `bot compat` adds `cliUpgradeRequired` / `skillUpgradeRequired` |
| `get-bot-profile` / `testchimp bot get-profile [--bot-id]` | `/api/mcp/get_bot_profile` | Identity, role, capabilities, subscriptions, paused, webhook health |
| `register-bot-profile` / `testchimp bot register-profile` | `/bots/register_profile` | **Mutating** — replaces profile + subscriptions atomically |
| `ack-bot-events` / `testchimp bot ack <eventIds...> [--ack-url]` | ingress `/bot/events/ack` | 1–100 ids; prints `eventId<TAB>status`; non-zero exit on `BOT_ACK_UNKNOWN_EVENT` / `BOT_ACK_NOT_A_TARGET` / `BOT_ACK_MISSING_BOT_ID` |

```bash
testchimp bot register-profile --role DEVELOPER --responsibilities "Payments API" \
  --capability ISSUE_FIX --capability E2E_AUTHORING \
  --subscriptions-json @subscriptions.json        # or inline JSON array
testchimp bot ack 01JEVT1 01JEVT2 --ack-url https://ingress.testchimp.io/bot/events/ack
# 01JEVT1	BOT_ACK_ACKED
# 01JEVT2	BOT_ACK_ALREADY_ACKED
```

`--ack-url` must be https (http only for localhost) and on a TestChimp host or the `TESTCHIMP_INGRESS_URL` host. A 404 from ingress means the deployment does not support bot acks yet.

### AgentWatch credentials (`testchimp bot connect`)

Headless AgentWatch (`npx -y @testchimp/agentwatch …`) acts as the user, so it needs their user id, PAT and the project API key. **QA bots always use `--pair`**: the user's single connector consent already covers it, so there is no second browser page. Plain `bot connect` (manual use without a bot) gets them through OAuth (PKCE, loopback redirect, opt-in `agentwatch` scope shown on the consent page) and one call to `/bots/get_agentwatch_credentials`, then stores them in `~/.testchimp/agentwatch/credentials.json` (0600, keyed by project, `$TESTCHIMP_HOME` overrides) with the backend / ingress URLs. The OAuth refresh token is revoked immediately. No TestChimp Studio install or sign-in is needed.

| Command | Notes |
| --- | --- |
| `testchimp bot connect [--project-id <id>] [--no-browser] [--port <n>] [--timeout-ms <n>]` | **Mutating (local file)**. Prints the approval URL to stderr and opens the browser. Prints `{projectId, userId, email?, botId?, credentialsPath}` (never the keys). `--project-id` fails unless that project was approved. Uses `TESTCHIMP_BACKEND_URL` (ingress from `TESTCHIMP_INGRESS_URL`, else the matching SaaS ingress). Errors: `The user denied access`, `does not match --project-id`, `did not grant the agentwatch scope` (deployment too old), timeout (exit 1) |
| `testchimp bot connect --pair [--project-id <id>]` | **Mutating (local file)**. No browser. Keeps a random verifier in `~/.testchimp/agentwatch/pairing.json` (0600, replaces any earlier one) and prints `{pairingCode, expiresAtMillis}` for the QA bot to approve. Run on the user's computer |
| `testchimp bot approve-pairing <pairingCode>` | **Bot side** (same as MCP `approve-agentwatch-pairing`; QA bots use the MCP tool with their binding arguments, because this needs the connector's OAuth token). Needs the `agentwatch_pair` scope (granted to every connection approved with **Use this connection as my QA bot**), else 403. The pairing is tied to the binding's project and bot. Prints `{projectId, expiresAtMillis}`. The user's PAT never reaches the bot |
| `testchimp bot connect --finish-pair [--timeout-ms <n>]` | **Mutating (local file)**. Redeems the pending pairing with its verifier (polls up to 60 s by default), stores the credentials like browser `connect`, deletes `pairing.json`. Errors: `has not been approved yet`, `expired` / `No pending AgentWatch pairing` (start again), `approved project … not …` (nothing stored), 404 (deployment too old) |
| `testchimp bot disconnect --project-id <id>` | **Mutating (local file)**. Removes that project's entry; prints `{projectId, removed, credentialsPath}` |

Pairings are single use and expire after 10 minutes. The pairing code is SHA-256(verifier), so it is useless without the verifier on the user's computer.

```bash
testchimp bot connect --pair --project-id "$PROJECT_ID"   # user's computer → prints pairingCode
testchimp bot approve-pairing "$PAIRING_CODE"              # bot side (or MCP approve-agentwatch-pairing)
testchimp bot connect --finish-pair                        # user's computer
npx -y @testchimp/agentwatch query --project-id "$PROJECT_ID"
```

### Workspace folder mapping (local, no API route)

Per-user mapping of a local repo folder to a TestChimp project, stored in `~/.testchimp/projects.json` (`$TESTCHIMP_HOME` overrides). This is the same file TestChimp Studio and the headless AgentWatch daemon (`npx -y @testchimp/agentwatch …` or `testchimp-studio agentwatch …`) read. Used by bot onboarding step 6 ([`bot-onboarding.md`](./bot-onboarding.md)).

| Command | Notes |
| --- | --- |
| `testchimp workspace map --project-id <id> --folder <path> [--project-name <name>] [--reassign] [--skip-repo-check]` | **Mutating (local file)**. The folder must be a git work tree. When a credential is set and the project has a connected repo (`get-git-folder-mapping`), the folder must be the repository root and one of its remotes must match. A folder belongs to one project, so pass `--reassign` to move it. Prints the mapping JSON. Errors: `NOT_FOUND`, `NOT_A_GIT_REPO`, `NOT_REPO_ROOT`, `REPO_MISMATCH`, `INVALID_PAYLOAD: folder already mapped to project <id>` (exit 1) |
| `testchimp workspace get --project-id <id>` | Prints `{id, projectId, projectName?, folders:[{id, path, name}], createdAtMillis, lastOpenedAtMillis, browserStartUrl?}`. Exit 1 when unmapped. Read-only |

```bash
testchimp workspace map --project-id "$PROJECT_ID" --folder ~/code/shop --project-name "Shop"
testchimp workspace get --project-id "$PROJECT_ID" | jq -r '.folders[0].path'
```

---

## Team invites (CLI ≥ **0.1.91**)

### `invite-team-members`

**API:** `POST /api/mcp/invite_team_members`. **Mutating** (sends invite emails). Invites teammates to the organisation; members can open every project in it. Used as the last step of project init ([`project-init-testchimp.md` § 7](./project-init-testchimp.md#7-final--invite-team-members)).

Needs an **OAuth user session** (hosted MCP, or a QA bot's connector) whose user is an **org admin**. A project API key can't invite, including with a `bot-id` header, so QA bots call the **MCP tool** with their binding arguments, not `testchimp --bot …`. API-key callers get 403 with the Team Settings link.

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--emails <list>` | Yes | `emails` | Comma-separated; 1–20 per call. Only addresses the user confirmed |
| `--json-input …` | No | (merge) | |

Returns `{results: [{email, outcome, userId?, failureReason?}], teamSettingsUrl}`. `outcome`: `MCP_TEAM_INVITE_OUTCOME_INVITED` (email sent; joins as Viewer), `…_ALREADY_MEMBER`, `…_ALREADY_INVITED` (nothing re-sent), `…_FAILED` (`failureReason`: seat limit with upgrade link, email in another organisation, …). Errors for the whole call: 403 when the session has no user, the user isn't an org admin, or the org is on the single-user Indie plan; 400 for an invalid email or more than 20. Roles (for example Admin) and seats are managed at `teamSettingsUrl`.

```json
{ "emails": ["dana@acme.com", "lee@acme.com"] }
```

---

## Feedback to TestChimp (CLI ≥ **0.1.87**)

### `send-feedback`

**API:** `POST /api/mcp/send_feedback`. "Contact us" for agents: the message goes to the TestChimp team's support inbox with the project, organisation, user / bot id (when known) attached. Works with a project API key or OAuth token. When to use it: [`SKILL.md` § Feedback to TestChimp](../SKILL.md#feedback-to-testchimp).

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--message <text>` | Yes | `message` | What happened, in plain words (≤ 10,000 chars) |
| `--category <c>` | No | `category` | `BUG` \| `USER_STRUGGLE` \| `FEATURE_REQUEST` \| `DOCS_GAP` \| `OTHER` (default) |
| `--context <text>` | No | `context` | What you were doing: workflow, command, error text, CLI / skill versions (≤ 20,000 chars) |
| `--agent-name <name>` | No | `agentName` | Your host, e.g. `Cursor`, `Claude Code`, `Grok QA bot` |
| `--json-input …` | No | (merge) | |

Prints `{"delivered": true}`. Limited to 30 messages per project per hour (HTTP 429 beyond that). Never include secrets, API keys or tokens.

```bash
testchimp send-feedback --category USER_STRUGGLE --agent-name "Cursor" \
  --message "User couldn't tell which env var holds the API key during /testchimp init" \
  --context "init-testchimp.md step 2; CLI 0.1.87; error: 401 Unauthorized"
```

---

## MCP parity (tool names)

MCP tool **names** match CLI **subcommands** (kebab-case), e.g. **`get-requirement-coverage`**, **`upsert-policy`**, **`upsert-plans-support-file`**, **`get-plans-support-file`**, **`create-user-story`**, **`list-rum-environments`**.

## Related

- [init-testchimp.md](./init-testchimp.md) — workstation gate and MCP registration.
- [write-smarttests.md](./write-smarttests.md) — tool shapes and coverage calls.
- [chimphands.md](./chimphands.md) — ChimpHands on CI: session branch + end-of-turn commit.
- [chimphands-faq.md](./chimphands-faq.md) — ChimpHands CI auth and self-heal.

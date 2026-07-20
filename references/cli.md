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

## Authentication and API host (`TESTCHIMP_API_KEY`, `TESTCHIMP_BACKEND_URL`)

The CLI reads **`process.env.TESTCHIMP_API_KEY`** and, when set, **`process.env.TESTCHIMP_BACKEND_URL`**. Agent-run shells often **do not** inherit the IDE MCP process environment.

**Before every CLI invoke** (and on any **401**), resolve env from the project MCP config:

1. Resolve the **same project-scoped MCP config** used for TestChimp (the file where the user placed the key at init). The path is **host-specific** — e.g. Cursor often uses `<repo>/.cursor/mcp.json`; Claude Code, VS Code, and others use their own documented locations. **`.cursor` is an example, not universal.**
2. From the **SmartTests root** (folder containing `.testchimp-tests`), walk **up** the directory tree and check each candidate MCP config file until you find `mcpServers` (or equivalent) with a **`testchimp`** server entry.
3. Read from that entry’s **`env`**:
   - **`TESTCHIMP_API_KEY`** (required for auth)
   - **`TESTCHIMP_BACKEND_URL`** when present — **must** be exported; do **not** fall back to the package default prod host when this is set (staging / enterprise / self-hosted). Keys are environment-scoped; calling prod with a non-prod key yields **401**.
   - **`TESTCHIMP_PROJECT_ID`** when present (TrueCoverage RUM wiring; not required for CLI auth)
4. **`export`** those variables in the **same shell** that will run `testchimp` (e.g. one block: `export TESTCHIMP_API_KEY=... TESTCHIMP_BACKEND_URL=...` then `testchimp ...`).
5. **Never print the key** in chat, logs, or echoed commands.

**`TESTCHIMP_BACKEND_URL`:** When set in MCP `env`, it overrides the default API host (see `testchimp --help` footer). When **absent**, the CLI default (SaaS prod) is correct. On **401**, re-check that a configured backend URL was exported before assuming a bad key.

**401 remediation order:** (1) export `TESTCHIMP_BACKEND_URL` from MCP if configured → (2) export `TESTCHIMP_API_KEY` from the same entry → (3) retry.

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

Start the TestChimp MCP server (stdio transport). **No flags.** Typically invoked as `npx -y @testchimp/cli@latest mcp` from MCP config.

---

## Coverage and execution

### `get-requirement-coverage`

**API:** `POST /api/mcp/list_requirement_coverage`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--release <s>` | No | `release` | |
| `--environment <s>` | No | `environment` | |
| `--branch-name <s>` | No | `branchName` | Optional Git branch; omit for cross-branch coverage (recommended for `/testchimp test` Analyze). |
| `--platform <web\|ios\|android>` | No | `platform` | Optional filter: latest coverage for that platform only (`web`, `ios`, or `android`). |
| `--record-types <csv>` | No | `recordTypes` | Coverage sources to include: `smart_test` (automated) and/or `manual`. Default (omit): `smart_test` only. |
| `--include-manual` | No | `recordTypes` | Convenience: include manual coverage in addition to automated (equivalent to `--record-types smart_test,manual`). |
| `--manual-only` | No | `recordTypes` | Convenience: manual-only coverage (equivalent to `--record-types manual`). |
| `--file-paths <csv>` | No | `scope.filePaths` | Comma-separated paths under **platform tests or plans** root. |
| `--folder-path <path>` | No | `scope.folderPath` | Slash-separated folder under tests or plans root; sent as normalized path segments. |
| `--json-input …` | No | (merge) | e.g. `includeNonCoveredUserStories`, `includeNonCoveredTestScenarios`, or `scope.folderPath` as **array** of segments. |

### `get-execution-history`

**API:** `POST /api/mcp/list_execution_history`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--release <s>` | No | `release` | |
| `--environment <s>` | No | `environment` | |
| `--branch-name <s>` | No | `branchName` | |
| `--scenario-id <id>` | No | `scenarioId` | When set, returns runs for tests linked to this scenario (Insights execution history). |
| `--platform <web\|ios\|android>` | No | `platform` | Optional platform filter (`web`, `ios`, `android`). Prefer `dimensionFilters` for device/OS/resolution/orientation. |
| `--file-paths <csv>` | No | `scope.filePaths` | Comma-separated under platform tests or plans root. |
| `--folder-path <path>` | No | `scope.folderPath` | Slash-separated; same normalization as coverage. |
| `--json-input …` | No | (merge) | e.g. `dimensionFilters` (`[{ "dimension": "PLATFORM_EXECUTION_JOB_FILTER_DIMENSION", "values": ["WEB"] }]`), `limit`, `offset`. |

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
| Folder scope | `scope.folderPath` / `scope.filePaths` (same as coverage). |
| Scenario scope | `scenarioId` = platform scenario UUID (Insights execution history). Omit folder scope or combine per server rules. |
| Platform filter | `--platform web\|ios\|android` **or** `dimensionFilters` with `PLATFORM_EXECUTION_JOB_FILTER_DIMENSION` and values `WEB`, `IOS`, `ANDROID`. |
| Device drill-down | `dimensionFilters` in JSON: `DEVICE_FAMILY`, `OS_VERSION`, `SCREEN_RESOLUTION`, `SCREEN_ORIENTATION` (enum dimension names + string values). OR within a dimension, AND across dimensions. |

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

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--scenario-ordinal-ids <csv>` | No* | `scenarioOrdinalIds` | Numeric parts of `TS-<n>`. |
| `--user-story-ordinal-ids <csv>` | No* | `userStoryOrdinalIds` | Numeric parts of `US-<n>`. |
| `--json-input …` | No | (merge) | |

\*At least one of the ordinal id lists should be non-empty.

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

Fetch release catalog details for a version/label in the current project (cut git SHA, prior release + SHA, focus areas, payload). Used when running ExploreChimp **targeting a release**.

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
| `--scenario-ordinal-ids <csv>` | **Yes**\* | `scenarioOrdinalIds` | Numeric parts of **`TS-<n>`** (e.g. `107` for `TS-107`). |
| `--json-input …` | No | (merge) | May supply **`scenarioOrdinalIds`** array instead of flag. |

\*At least one ordinal id is required (via flag or JSON).

**Response:** `testScenarios[]` with `ordinalId`, `title`, `platformFilePath`, `content` (full markdown), `userStoryOrdinalIds[]`. Missing ids appear in `errors[]`.

**Example:**

```bash
testchimp get-test-scenarios --scenario-ordinal-ids 107
```

Use **`get-test-scenarios`** first when a prompt references **`TS-<n>`**; call **`get-user-stories`** for each linked story ordinal returned.

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

Use when the user pastes a **Copy script generate prompt** from the manual session viewer. Then load linked scenarios from the mapped **`plans/scenarios/`** tree or call **`get-test-scenarios --scenario-ordinal-ids`** once with all values from **`linkedScenarioOrdinalIds`**. See [`author-test-from-manual-session.md`](./author-test-from-manual-session.md).

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

**When to use:** File a **new** TestChimp issue in the current project (MCP preferred; CLI fallback). Use when the user asks to create/file a bug, suggestion, observation, or task — or when an agent finds a product defect that is **not** already auto-filed (e.g. ExploreChimp pipeline bugs). Do **not** use this to update an existing issue (use `update-issue-status` / `get-issue-details`) or to fix one (`/testchimp fix issue`).

**Agent rules:**
- **`title` is required** (flag or JSON). Prefer a concrete, actionable title.
- Defaults when omitted: **`status=ACTIVE`**; **`environment`** defaults server-side to QA when unset.
- Prefer **`linkTargets`** (via `--json-input`) to attach stories, scenarios, tests, executions, or batch invocations so the issue is traceable.
- Use simple flags for common creates; use **`--json-input`** for the full curated contract (`linkTargets`, `attachments`, `artifactReference`, enums below).
- **`source`** is stored as a label `source:<name>` (e.g. agent ingest id). Extra **`labels`** are optional.
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
| `--json-input …` | No | (merge) | Full body including **`linkTargets`**: `[{ "toEntityType": "SCENARIO"\|"STORY"\|"TEST"\|"ISSUE"\|"EXTERNAL"\|"TEST_EXECUTION"\|"BATCH_INVOCATION", "toEntityId": "…" }]`, plus `attachments`, `artifactReference`. |

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
| `--json-input` | Yes (today) | `policyFileName` | e.g. `connect-to-test-env.policy.md`. Server coerces to `*.policy.md` (same rules as `upsert-policy`). |

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

### `list-workflow-catalog`

**API:** `POST /api/mcp/list_workflow_catalog`

Lists catalog workflows with Active / Disabled / Missing Config for the project. Use `--json-input '{}'` when no flags are needed.

Also related (flags vary): **`report-agent-action`**, **`get-last-run-workflow-detail`**, **`list-workflow-executions`**, **`get-workflow-execution`** — see `testchimp <cmd> -h`.

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

---

## MCP parity (tool names)

MCP tool **names** match CLI **subcommands** (kebab-case), e.g. **`get-requirement-coverage`**, **`upsert-policy`**, **`create-user-story`**, **`list-rum-environments`**.

## Related

- [init-testchimp.md](./init-testchimp.md) — workstation gate and MCP registration.
- [write-smarttests.md](./write-smarttests.md) — tool shapes and coverage calls.

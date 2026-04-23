# TestChimp CLI (`@testchimp/cli`)

Use the **CLI** when the agent runs **shell commands** (CI, scripts, or hosts without MCP). Use **MCP** when the IDE/agent host exposes MCP tools. Both call the same TestChimp **`/api/mcp/*`** HTTP APIs.

This page lists **every subcommand and flag** as implemented in the CLI (kebab-case flags; request bodies use **camelCase**). **`--json-input`** is available on every tool subcommand below except where noted; it merges **over** flags (JSON wins on conflicts).

## Install

```bash
npm install -D @testchimp/cli@latest
```

Invoke via `npx @testchimp/cli@latest <subcommand>` or the **`testchimp`** binary from `node_modules/.bin` after a local install.

## Authentication (`TESTCHIMP_API_KEY`)

The CLI reads **`process.env.TESTCHIMP_API_KEY`**. Agent-run shells often **do not** inherit the IDE MCP process environment.

If the key is **not** set in the shell:

1. Resolve the **same project-scoped MCP config** used for TestChimp (the file where the user placed the key at init). The path is **host-specific** — e.g. Cursor often uses `<repo>/.cursor/mcp.json`; Claude Code, VS Code, and others use their own documented locations. **`.cursor` is an example, not universal.**
2. From the **SmartTests root** (folder containing `.testchimp-tests`), walk **up** the directory tree and check each candidate MCP config file until you find `mcpServers` (or equivalent) with a **`testchimp`** server entry.
3. Read **`env.TESTCHIMP_API_KEY`** (and optionally **`env.TESTCHIMP_BACKEND_URL`**) from that entry.
4. **`export`** those variables in the **same shell** that will run `testchimp` (e.g. a single shell block: `export TESTCHIMP_API_KEY=...` then `testchimp ...`).
5. **Never print the key** in chat, logs, or echoed commands.

Optional: **`TESTCHIMP_BACKEND_URL`** — overrides the default API host (see `testchimp --help` footer for current default).

## Quick invoke

```bash
testchimp --help
testchimp get-requirement-coverage --branch-name main
testchimp create-user-story --platform-file-path plans/stories/auth.md --title "Auth"
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
| `--branch-name <s>` | No | `branchName` | Git branch. |
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
| `--file-paths <csv>` | No | `scope.filePaths` | Comma-separated under platform tests or plans root. |
| `--folder-path <path>` | No | `scope.folderPath` | Slash-separated; same normalization as coverage. |
| `--json-input …` | No | (merge) | For any extra fields accepted by the backend. |

---

## Plans (user stories and scenarios)

### `create-user-story`

**API:** `POST /api/mcp/create_user_story`

| Flag | Required | Maps to JSON field | Notes |
|------|----------|-------------------|--------|
| `--platform-file-path <path>` | **Yes** | `platformFilePath` | Under **`plans/stories/`**, must end with **`.md`**. |
| `--title <title>` | **Yes** | `title` | |
| `--json-input …` | No | (merge) | |

### `create-test-scenario`

**API:** `POST /api/mcp/create_test_scenario`

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
- **Invocation:** almost every tool is **`--json-input '<json>'`** only (no other flags), except **`get-truecoverage-event-metadata-keys`** (required **`--event-title`** or `eventTitle` in JSON).

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
| Enums | **String** enum name, e.g. **`"EQUALS"`**, **`"SESSION_COUNT"`** (not numeric wire values). |
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
| `timeWindow` | object (`TimeWindow`) | **Required** for meaningful queries. |
| `release` | string | Optional filter. |
| `branchName` | string | Optional filter. |
| `metadataFilters` | array of `MetadataFilter` | Optional. |
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

Relative window (last 7 days as duration string):

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

Deeper product context: [truecoverage.md](./truecoverage.md).

---

## MCP parity (tool names)

MCP tool **names** match CLI **subcommands** (kebab-case), e.g. **`get-requirement-coverage`**, **`create-user-story`**, **`list-rum-environments`**.

## Related

- [init-testchimp.md](./init-testchimp.md) — workstation gate and MCP registration.
- [write-smarttests.md](./write-smarttests.md) — tool shapes and coverage calls.

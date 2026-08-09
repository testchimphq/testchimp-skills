# API testing and API operation coverage

Use this reference when:

1. **`/testchimp create tests`** (or create-tests nested under run-qa / upkeep) is given an **API operation scope** — see [API operation coverage scopes](#api-operation-coverage-scopes) below.
2. The Plan phase decides a scenario is better automated as a **dedicated API test** under **`api/`** — see [Browser-capture → `api/` workflow](#browser-capture--api-workflow) below.

API tests live under **`api/`** at the SmartTests root (folder with **`.testchimp-tests`**). On **mobile** and **multi-platform** scaffolds, import **`{ test, expect }`** from **`api/fixtures/index.js`** and run with the config’s **`api`** project ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)). Reference payloads live in **`assets/`**.

Create-tests playbook entry: [`create-tests.md`](./create-tests.md). CLI tools: [`cli.md`](./cli.md) § API operations (CLI ≥ **0.1.28**).

---

## API operation coverage scopes

### Goal

**Raise coverage** for the given OpenAPI operation / field / response-code scope — not “write one dedicated API test per gap.”

- Prefer **extend an existing SmartTest or API test** that already touches (or can touch) the operation so the missing shape is exercised (filter on, alternate status, error path, etc.).
- A **UI e2e SmartTest** that invokes the endpoint covers that interaction for API-operation coverage the same as a pure API call.
- Author a **new** test only when no suitable vehicle exists; choose UI vs `api/` by journey fit (user-facing flow → UI; contract/seed-heavy/pure API surface → `api/`).
- One test may close **multiple** gaps in the scope; do not 1:1 map gaps to dedicated API specs.

### Prompt shapes (from Operations UI or agents)

```text
/testchimp create tests for service OpenAPI root <repo-relative-root>
/testchimp create tests for TestChimp operation id <ULID>
/testchimp create tests for TestChimp operation id <ULID> request field </json/pointer>
/testchimp create tests for TestChimp operation id <ULID> query param <name>
/testchimp create tests for TestChimp operation id <ULID> response field </json/pointer> for response code <code>
/testchimp create tests for TestChimp operation id <ULID> response code <code>
```

Also accepted (resolve via CLI): `rootFilePath` + OAS `operationId`, or `rootFilePath` + HTTP method + path template. **TestChimp operation id** is the platform ULID (`api_operations.id`) — not the OpenAPI `operationId`.

| Granularity | Identity |
|---|---|
| Service resource | Repo-relative OpenAPI **root** file path (`rootFilePath`) |
| Operation | Prefer **TestChimp operation id** (ULID); else root + OAS operationId; else root + method + path template |
| Request field | After operation: `request field` + JSON pointer (enum values may appear as pointer segments) |
| Query param | After operation: `query param` + name |
| Response field | After operation: `response field` + JSON pointer + `for response code` + code |
| Response code | After operation: `response code` + code |

### Fetch coverage (required before authoring)

1. **`list-api-operation-services`** — configured roots; empty → OAS not configured (`N/A` / ask user).
2. **`list-api-operations --root-file-path <path>`** — same list payload as the Operations UI (`coverageSummary`, covering-test previews). Prefer low `coverageScore` / zero covering tests. Always pass **`--root-file-path`** when more than one service exists (omitting it returns all services’ ops mixed together).
3. **`get-api-operation-detail --id <ULID>`** (or root + oas / method+path) — request/query/response fields and response codes with covering tests.

### Prompt → CLI mapping

| Prompt fragment | Resolve with |
|---|---|
| `… for service OpenAPI root <path>` | `list-api-operations --root-file-path <path>`; pick high-ROI uncovered ops; detail each via `--id` |
| `… for TestChimp operation id <ULID>` | `get-api-operation-detail --id <ULID>` |
| `… for TestChimp operation id <ULID> request field </pointer>` | Detail by `--id`; focus on `requestFields` entry with that `jsonPointer` (and related uncovered siblings if high ROI) |
| `… query param <name>` | Detail by `--id`; focus on `queryFields` |
| `… response field </pointer> for response code <code>` | Detail by `--id`; focus on matching `responseFields` + that code |
| `… response code <code>` | Detail by `--id`; focus on `responseCodes` entry |
| Optional `Hint: METHOD /path — OpenAPI root …` line | Human-readable only; do **not** treat as the scope identity |

Alternate identities (when ULID absent): `--root-file-path` + `--oas-operation-id`, or `--root-file-path` + `--http-method` + `--path-template` (method+path **requires** root or serviceKey).

Prioritize gaps by: **missing coverage** + **business criticality** + **likely distinct backend branch complexity**. Examples of high-ROI shapes (not only filters): auth/role gates, pagination vs full page, idempotency keys, status-transition enums, error-code paths, optional nested resources that trigger secondary loads, feature-flagged payloads, soft-delete / include-archived toggles.

### Check existing scenarios/stories before authoring (required)

Same rule as upkeep signal-only gaps and [`create-tests.md`](./create-tests.md) § API operation scopes:

1. Search existing scenarios/stories (mapped `plans/`, `get-test-scenarios` / `get-requirement-coverage` / semantic-nearby) for a match to the API signal.
2. Prefer **linking an existing scenario** (and story) when one fits; only propose **new** plan items when none exist.
3. **Explicit user approval** before creating any new story/scenario.
4. Create approved missing items as lifecycle **`ready`** + verification **`auto`**, then author/update SmartTests with scenario annotations. No duplicates / phantom ids.
5. Soft-notify suite size via **`get-suite-execution-stats`** vs `global.policy.md` when over or within ~10% of a non-zero cap.

Then apply the [coverage strategy](#goal) above (update existing → new UI → new `api/` as needed).

---

## Browser-capture → `api/` workflow

Use when converting a validated user flow into a robust Playwright **API** test under **`api/`**.

### Goal

1. Capturing real request/response traffic while running the scenario in the browser.
2. Selecting only the API calls relevant to the scenario outcome.
3. Rebuilding that sequence as deterministic API assertions in **`api/`**.

### Workflow

1. **Define API capture scope first**
   - Check if `plans/knowledge/ai-test-instructions.md` has instructions on regex of api requests to intercept during API test authoring via browser sessions.
   - Derive a request URL regex from the codebase (client API modules, gateway routes, service base paths).
   - Validate the proposed regex with the user before recording traffic.
   - Persist the approved regex and rationale in `plans/knowledge/ai-test-instructions.md` so future runs reuse it.

2. **Decide whether a browser session run is needed**
   - Check whether the scenario is a purely API based journey (eg: the PR builds an API endpoint for consumption by callers - so there is no browser experience. The journey is purely API based). In which case, no need to spin up a browser instance, and can simply call the API to get responses and record them to generate the API test afterwards.
2.a **Run the scenario in a browser session**
   - If the scenario is a browser based journey (an end user human user facing experience), then:
   - Start Playwright browser context as usual for `/testchimp test`.
   - Register request/response interception for the approved regex before executing steps.
   - Execute the scenario in the UI to capture realistic API traffic.

3. **Collect and reduce payloads**
   - Gather relevant request/response pairs from captured traffic.
   - Trim payloads to required fields only (remove large or irrelevant blobs, transient metadata, and sensitive values).
   - Identify which calls are core business flow vs noise (analytics, polling, unrelated background calls).

4. **Author API test in `api/`**
   - Create or update a spec under **`api/`**; import from **`api/fixtures/index.js`** when using merged fixtures.
   - API tests are also just plain Playwright scripts - just executing API calls and no browser interactions.
   - Sequence calls in dependency order - including only the absolutely necessary calls.
   - Extract values from earlier responses and pass them into later requests (ids, tokens, generated resource keys).
   - Keep setup assumptions explicit and aligned with the setup project / **fixtures** and seed endpoints.
5. **Link to Relevant Scenarios**
   - Just like in SmartTests, add Playwright scenario annotations on the API test options: `{ type: 'scenario', description: '#TS-101' }` (description is **only** `#TS-<n>` — no title). Follow the format in [`write-smarttests.md`](./write-smarttests.md). Do **not** author deprecated `// @Scenario:` comments.
6. **Add strong verifications**
   - Assert status codes and key business fields, not just transport success.
   - Verify state transitions and side effects expected by the scenario.
   - Add negative/guard assertions where they materially protect against regressions.

### Important constraints

- `ai.act`, `ai.verify`, and `ai.extract` are **UI interaction helpers** and are **not used** inside API tests.
- Prefer deterministic request construction and explicit assertions for API suites.
- If the project lacks an **`api`** Playwright/Mobilewright project, update **`playwright.config.js`** or **`mobilewright.config.ts`** so **`testDir: 'api'`** (or equivalent) and **`api/fixtures`** are wired — see templates in [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md).

### Execution checklist

- Capture regex approved and persisted in `plans/knowledge/ai-test-instructions.md`.
- API test file added under **`api/`**.
- Optional payload fixtures (if any) stored under **`assets/`**.
- Playwright config includes API project with setup dependency.
- Test passes locally in the intended environment.

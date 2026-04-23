# /testchimp test

This document explains **how to write SmartTests** for agents during the **Execution phase** of `/testchimp test` (phased flow in [`testing-process.md`](./testing-process.md)). SmartTests are "Playwright with intelligent steps". Here are the key points:
- Playwright tests in a **tests** folder mapped in TestChimp platform,
- Ability to include natural language steps for "intent based" test steps in standard Playwright scripts
- scenario linking via in-code structured comments in test (for built-in requirement traceability).
- You can use the testchimp-mcp-client to query about coverage insights to decide what tests need authoring.

For **full** `ai-wright` API details (options, env vars, troubleshooting), see **[`ai-wright-usage.md`](./ai-wright-usage.md)**. The sections below summarize what you need to author tests and point there for depth.

For **`plans/`** markdown (story vs scenario frontmatter, `US-` / `TS-` ids, platform paths, and MCP tools to **create** plan files), see **[`test-planning.md`](./test-planning.md)**.

**Fixtures:** Decide which **fixture dependencies** each UI test needs during **planning**; add or extend **`fixtures/`** (and any missing seed/teardown/read APIs) in **plan / setup**—see **[`testing-process.md`](./testing-process.md)** and **[`fixture-usage.md`](./fixture-usage.md)** (`mergeTests`, master `index`, `testInfo`). When a scenario must assert **backend persistence** or **observable** state after UI steps (not only the DOM), plan **test-only read** endpoints or `request` calls per **[`seeding-endpoints.md`](./seeding-endpoints.md)** (reads also support **read-before-write** idempotency in fixture teardown).

---

## Test writing workflow

1. **Target URL** — Ask for preview URL or local stack URL if unclear. In the `playwright.config.js` we have set  
`baseURL:process.env.BASE_URL,` - so tests should simply specify relative urls, the preview URL should be set as the `BASE_URL` env var so that the test picks up that.

2. **Decide what to write or change** — If **`testchimp-mcp-client`** is configured in the agent environment, call the MCP tools **`get_requirement_coverage`** and **`get_execution_history`** with the request shapes in [Calling the TestChimp MCP tools](#calling-the-testchimp-mcp-tools). Combine responses with the PR diff, commits, and plan files in the repo to choose scenarios and files to touch. If MCP is not available, infer gaps from plans and existing tests.
3. **Per scenario** — Add or update a test; reuse existing page objects, fixtures, and env conventions in the repo.
4. **Drive the real app with Playwright (no invented steps)** — Human input is often required **before** you start (URLs, accounts, feature flags, which environment to hit) **and sometimes during** a run (unexpected MFA, captcha, missing seed data, “which org should I use?”). Do not guess secrets or one-off values (unless you deem any random suitable guessed value should suffice for a specific step).

   - **Discover values in the repo before asking:** Read **`.env-*`** files under the mapped tests folder (e.g. `.env-QA`) for **test-run** variables: `BASE_URL`, auth-related vars, feature toggles, etc. **Do not** store **`TESTCHIMP_API_KEY`** there — it belongs in the **shell** and MCP **`env`** (see skill **Agent guardrails**). Skim **`setup/`** scripts and global setup for how auth state or data is created. Open **existing specs** in the same area to see which env vars, fixtures, and URLs peers use.
   - **Ask early when something crucial is missing** — If authentication details, org/project identifiers, or other data the scenario depends on is not discoverable from the repo or plans, **ask the user before** driving the browser. If you only learn what is missing **while** interacting (e.g. login fails, wrong tenant), **stop and ask** rather than fabricating credentials or steps.
  - **Run in headed mode by default** — Use a **headed** Playwright run during authoring so the user (and agent) can see the browser (unless the user explicitly requests headless). The objective is to **exercise the real journey** and only write steps that were actually proven to work against the live UI.
    - Prefer running with **`--headed`** during authoring, or setting Playwright config **`use.headless = false`** for the local authoring workflow.
    - Keep CI headless unless explicitly needed; headed is mainly for interactive authoring and debugging.
   - **Multi-pass authoring (recommended):**
     1. **First pass — record behavior:** Write the flow as real **`await page…` / `expect(…)`** calls. Where the UI is unclear, add a short **`// intent:`** comment above the line describing what you are trying to do, then the concrete Playwright line. Do not skip browser verification.
     2. **Second pass — harden brittle steps:** Re-read the spec. Where a selector-based step is likely **brittle** or **non-semantic**, replace it with **`ai.act` / `ai.verify` / `ai.extract`**, using the intent comments as guidance for natural-language objective. Remove redundant intent comments; **keep only comments that demarcate major sections** of the test (long flows, distinct phases).
     3. **Third pass — fit the suite:** Wire in **hooks**, **fixtures**, **`process.env`**, **page objects**, shared **timeouts**, and project **imports** (e.g. reporter runtime) so the test matches how neighboring files are structured.

### User takeover (headed) when the agent gets stuck

During interactive authoring, it is valid (and often necessary) to ask the user to temporarily **take over** to complete a journey segment (SSO/MFA, captcha, ambiguous UI, missing context). The key constraint is that the user must perform the actions **inside the same Playwright-controlled browser session** so the agent can incorporate them into the SmartTest.

Recommended takeover loop:

1. **Start capture before asking for takeover**
   - Enable **trace** (at least “retain-on-failure”; during authoring you may keep it on more aggressively).
   - Enable **network capture** if API-test derivation is a goal (request/response logging or HAR).
   - Optionally start **Playwright codegen** when you want high-fidelity step capture. Treat codegen output as a draft: it is often verbose and must be refactored.

2. **Ask user to complete the segment**
   - Tell the user exactly what checkpoint to reach (e.g. “get to the order confirmation screen”).
   - The user interacts with the **headed Playwright window** that the agent opened (not a separate browser).

3. **Convert captured behavior into SmartSteps**
   - Replace brittle literal click/fill chains with **`ai.act`** objectives where appropriate (“Choose an active card”, “Select plan X and continue”).
   - Add stable checkpoints with **`expect(...)`** or **`ai.verify(...)`** for user-visible outcomes.
   - If the objective is API testing, use the captured network data to author API tests (and still keep UI tests as thin smoke when needed).

4. **Validate immediately**
   - Run `npx playwright test` (still in the mapped tests root) to ensure the updated test passes end-to-end.
   - If failures occur, decide: **intended behavior change** (update test + scenario), or **real regression** (call it out; prefer fixing product code over “fixing tests”).
5. **Imports in SmartTest files** ALWAYS add those.
   - `import { ai } from 'ai-wright';`
   - `import '@testchimp/playwright/runtime';`

   The above enables AI steps in tests and TrueCoverage event tracking. Import **`test` / `expect` from your merged [`fixtures/`](./fixture-usage.md) entry** when tests use shared data setup.

6. **Scenario link** — As the **first statement inside the test body**:
   - `// @Scenario: #TS-xxx <Scenario title>`  
   Use the **`#TS-xxx`** id that **already exists** in TestChimp (from plan markdown **`id:`**, or from MCP **`create_test_scenario`** / **`create_user_story`** responses). **Never invent** scenario or story ids: create scenarios (and parent stories if needed) **before** adding this comment so links stay stable and real. Same pattern as: 
   `// @Scenario: #TS-102 Checkout with credit card`.

   **Strict format rules (do not deviate):**
   - Must be a single-line `//` comment
   - Must start with exactly `// @Scenario: `
   - Must include the `#TS-<n>` ordinal id (with the leading `#`)
   - The **first** `// @Scenario:` line must be the **first statement inside the test body** (immediately after the opening `{`).

   **Multiple scenarios in one test:** If a single test legitimately covers **more than one** scenario (e.g. one end-to-end flow that satisfies two acceptance criteria), add **additional** `// @Scenario: #TS-… <title>` lines **inside the same test**, each on its own line, using the same strict format. Place extra comments **before the steps that exercise that scenario**. Do not merge multiple ids into one comment.

   **Example (copy/paste shape):**

   ```js
   test('usage graphs show daily usage by project', async ({ page }) => {
     // @Scenario: #TS-2100 Validate event ingest volume graphs display correctly
     // ...
   });
   ```

   **Example (multiple scenario links in one test):**

   ```js
   test('checkout confirms order and sends receipt', async ({ page }) => {
     // @Scenario: #TS-101 Submit checkout
     await page.goto('/checkout');
     // ... steps for checkout ...

     // @Scenario: #TS-102 Email receipt after purchase
     // ... steps that assert receipt / email ...
   });
   ```

8. **Test naming (Playwright convention)**:
   - Use a **short, human-readable title** describing the behavior (imperative/statement form).
   - **Do not** include scenario ids (`TS-...`, `#TS-...`, `US-...`) or other IDs in the `test('...')` title.
   - **Do not** use underscores or long machine-style names; prefer spaces.

9. **Mix Playwright and AI** — Prefer plain Playwright for stable, fast paths; use **`ai.*`** when the selector-based step looks brittle or intent-driven steps are clearer (see [AI steps](#ai-steps-ai-wright-when-to-use-what)). AI steps use an agent that observes the screen to fulfill the objective, so they are typically **slower** than direct locators - though more flexible to UI variances.

---

## Recommended tests folder layout

SmartTests live under whatever folder the team mapped as **tests** in TestChimp (the on-disk name may differ; structure below applies **inside** that root). A typical layout:

```text
<mapped-tests-root>/
  pages/           # Page objects — reusable per-page helpers
  fixtures/        # mergeTests entry + domain fixtures ([fixture-usage.md](./fixture-usage.md))
  e2e/             # Many teams put specs here (or use other subfolders)
  setup/           # Global setup (see below)
  assets/          # Files used in tests (e.g. uploads)
  .env-QA          # Example env file; more environment types as needed - QA env is auto created by default
  playwright.config.js <-- unlike typical Playwright structure, in TestChimp, the config file lives inside the tests folder.
```

- **`pages/`** — Encapsulate navigation and selectors per page.
- **`fixtures/`** — Shared **`test.extend`** modules merged via **`mergeTests`**; use for per-test seed/teardown via APIs ([`fixture-usage.md`](./fixture-usage.md), [`seeding-endpoints.md`](./seeding-endpoints.md)).
- **`setup/`** — Global setup runs **before** browser tests via Playwright [project dependencies](https://playwright.dev/docs/test-global-setup-teardown#option-1-project-dependencies). Use for expensive one-time work (e.g. auth storage state). Usually excluded from the main test project with `testIgnore` in config.
- **`e2e/`** (and siblings) — SmartTests use **`*.spec.{js,ts}`** under the tests root.
- **`assets/`** — Static files (uploads, etc.).
- **`.env-*`** — Per-environment variables for **exercising the app under test** (e.g. **`BASE_URL`**); **QA** is a common default. Read with `process.env.VAR_NAME`. **Not** for **`TESTCHIMP_API_KEY`** (use shell + MCP config).
- **`playwright.config.js`** — Playwright config; projects using TestChimp add **`@testchimp/playwright`**.

Keep **`@playwright/test`** and **`playwright`** on the **same** version; use npm `overrides` if dependencies pull mismatched Playwright versions. TestChimp requires **`@playwright/test`** **>= 1.59.0** in **`SKILL.md`**. Agents should run the **Playwright toolchain check** in **`SKILL.md` Preamble checks** before authoring or executing SmartTests so the install is real, not assumed.

**Platform paths vs repo paths:** In API and MCP calls, paths are **platform-rooted**: first segment is `tests` or `plans`, then subfolders (e.g. `["tests","checkout"]`). The repo folder mapped to **tests** might be named `ui_tests` — you still pass `tests/checkout/...` in `scope.folderPath` when scoping coverage to that area.

### Running Playwright (agents)

Always execute from the **mapped SmartTests root** (the directory containing **`.testchimp-tests`**):

```bash
cd /path/to/<mapped-tests-folder>
npx playwright test
```

Use **`npx playwright …`** (install/use the project’s Playwright CLI from that folder). Do not assume the folder is literally named `tests` — resolve the path via the marker file.

---

## Calling the TestChimp MCP tools

These tools are provided by the **`testchimp-mcp-client`** package when it is installed and registered as an MCP server (e.g. Cursor `mcp.json`). The agent invokes them as **MCP tools** by name; arguments are JSON-shaped objects matching the schemas below.

**Environment (MCP process):**

| Variable | Required | Purpose |
|----------|----------|---------|
| `TESTCHIMP_API_KEY` | Yes | Authenticates to TestChimp; project is inferred from the key. Set in **`mcp.json`** **`env`** and in the **shell** for local runs — **not** in **`.env-QA`**. |

**Environment (Playwright / ai-wright in the same session):** Export the **same** **`TESTCHIMP_API_KEY`** in the shell when running `npx playwright …` so reporters, **`ai.*`** steps, and MCP-backed flows share one project key. For **ai-wright**, agents should **only** instruct setting **`TESTCHIMP_API_KEY`** (not user PAT / mail-based auth). On **401** responses, configure the key via TestChimp → **Project Settings** → **Key management**.

### Tool: `get_requirement_coverage`

**Purpose:** Requirement / scenario coverage for SmartTests (and plans-scoped resolution when using `plans/...` paths).

**Arguments (all optional unless you need to narrow scope):**

| Field | Type | Description |
|-------|------|-------------|
| `release` | string | Optional release filter. |
| `environment` | string | e.g. `QA` (default behavior on server if omitted is environment-specific). |
| `scope` | object | Narrow by files or folder. |
| `scope.folderPath` | string[] **or** string | Platform-rooted path: array of segments **or** a single slash-separated string (e.g. `"tests/checkout"` → `["tests","checkout"]`). |
| `scope.filePaths` | string[] | Paths to SmartTest files **relative to the platform tests folder root** (e.g. `e2e/checkout.spec.ts`). Prefer this over internal file ids. |
| `includeNonCoveredUserStories` | boolean | Include user stories with no coverage. |
| `includeNonCoveredTestScenarios` | boolean | Include scenarios with no coverage. |
| `branchName` | string | Git branch name (e.g. `main`) when results should respect branch-scoped assets. Prefer this over internal branch ids. |

**Example MCP tool call (conceptual):**

```json
{
  "tool": "get_requirement_coverage",
  "arguments": {
    "environment": "QA",
    "scope": { "folderPath": ["plans", "checkout"] },
    "includeNonCoveredTestScenarios": true
  }
}
```

**Minimal call (whole project default window):**

```json
{
  "tool": "get_requirement_coverage",
  "arguments": {}
}
```

### Tool: `get_execution_history`

**Purpose:** Recent SmartTest execution history for the same scoping model as coverage.

**Arguments:** Same as `get_requirement_coverage` except there are no `includeNonCoveredUserStories` / `includeNonCoveredTestScenarios` fields.

**Example:**

```json
{
  "tool": "get_execution_history",
  "arguments": {
    "environment": "QA",
    "scope": { "folderPath": "tests/e2e/checkout" }
  }
}
```

(`folderPath` as a string is split on `/` into segments.)

## AI steps (`ai-wright`): when to use what

### Standard Playwright (locators, actions, `expect`)

**Pros:**

- Fast runs; predictable, repeatable steps.
- Excellent traces: you see exactly which locator ran.
- Works well with semantic locators: `getByRole`, `getByLabel`, `getByTestId` you own.
- No extra services for basic automation.

**Cons:**

- Selectors break when markup, CSS classes, or DOM depth change without user-visible change.
- Third-party widgets, shadow DOM, and canvas/video are often awkward to target cleanly.
- Brittle patterns: long CSS chains, nth-child gymnastics, text tied to copy that changes often.
- Asserting *how* something looks (layout-only) vs *what* the user sees can force non-semantic selectors.

### AI steps (`ai.act`, `ai.verify`, `ai.extract`)

See **[`ai-wright-usage.md`](./ai-wright-usage.md)** for detailed guidance on writing AI steps.

**Pros:**

- Good when the goal is stable but the DOM path is not (dynamic lists, restyled components, modals).
- Natural-language intent can replace fragile selectors.
- Strong for “does the screen show X?” style checks when DOM structure varies.

**Cons:**

- Slower than pure Playwright; depends on LLM vision.
- Failures can be harder to bisect than a single broken locator.
- Overuse can hide missing test ids or accessibility gaps you should fix in the app.

### Choosing for each step

- **Default to standard Playwright** when you can express the step with **stable, semantic** locators (`getByRole`, `getByLabel`, `getByPlaceholder`, your own `data-testid`) and straightforward assertions.
- **Prefer AI steps** when you judge that a Playwright-selector approach for **that specific step** is likely to be **brittle** (unstable structure, heavy styling hooks, vendor UI) or **non-semantic** (you would be asserting implementation details or layout instead of user-visible behavior).
- Reserve AI steps for those hotspots; keep deterministic Playwright on hot paths so tests stay fast and traces stay precise.

| API | When to use | Role |
|-----|-------------|------|
| **`ai.act(objective, { page, test })`** | Perform **actions** described in natural language when the UI is unstable or easier to specify by **intent** than by selectors. | Dismiss modals, multi-step micro-flows, coarse objectives. |
| **`ai.verify(requirement, { page, test }, options?)`** | **Assert** what appears on screen when DOM assertions are fragile. | Optional `confidence_threshold` (e.g. `85`) for stricter passes. |
| **`ai.extract(requirement, { page, test }, options?)`** | **Read** values from the page into variables. | `return_type`: `'string' \| 'string_array' \| 'int' \| 'int_array'`. |

**Always pass `{ page, test }`** to every `ai.*` call.

**Examples:**

```ts
await ai.act('Click on the top left menu icon', { page, test });

await ai.verify('Verify no error messages are shown', { page, test });

const title = await ai.extract(
  'Name displayed in the dashboard title',
  { page, test },
);
```

---

## More on linking tests to scenarios

- Format: `// @Scenario: <scenario-id> [optional title]` with id from plans (e.g. `#TS-102`).
- Keeps traceability **in the repo** and helps agents and TestChimp associate runs with scenarios.

---

## Example SmartTest (full file)

Illustrative end-to-end shape: env-driven base URL, scenario comment, plain Playwright plus one AI step, and typical imports. Adjust names and selectors to match the repo.

```ts
import { test, expect } from '@playwright/test';
import { ai } from 'ai-wright';
import '@testchimp/playwright/runtime';

test.describe('Checkout (illustrative)', () => {
  test('guest can reach checkout with valid cart', async ({ page }) => {
    // @Scenario: #TS-204 Guest checkout with single item

    await page.goto(`/shop`);
    await page.getByRole('link', { name: 'Add to cart' }).first().click();

    // Intent preserved as ai.act when the cart drawer markup is unstable across releases:
    await ai.act('Open the cart and proceed to checkout', { page, test });

    await expect(page.getByRole('heading', { name: /checkout/i })).toBeVisible();
    await ai.verify('Shipping form is visible with empty fields', { page, test });
  });
});
```

---

## Further reading in this bundle

- **[`ai-wright-usage.md`](./ai-wright-usage.md)** — Full `ai-wright` install, options, env vars, and hybrid vs fully-agentic tradeoffs.
- **[`SKILL.md`](../SKILL.md)** — Overview and command routing for `/testchimp` flows.

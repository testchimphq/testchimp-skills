# /testchimp test

This document explains **how to write SmartTests** for agents during the **Execution phase** of `/testchimp test` (phased flow in [`testing-process.md`](./testing-process.md)). SmartTests are "Playwright with intelligent steps". Here are the key points:
- Playwright tests in a **tests** folder mapped in TestChimp platform,
- Ability to include natural language steps for "intent based" test steps in standard Playwright scripts
- scenario linking via in-code structured comments in test (for built-in requirement traceability).
- You can use the testchimp-mcp-client to query about coverage insights to decide what tests need authoring.

For **full** `ai-wright` API details (options, env vars, troubleshooting), see **[`ai-wright-usage.md`](./ai-wright-usage.md)**. The sections below summarize what you need to author tests and point there for depth.

For **`plans/`** markdown (story vs scenario frontmatter, `US-` / `TS-` ids, platform paths, and MCP tools to **create** plan files), see **[`test-planning.md`](./test-planning.md)**.

**World states:** Decide the **target world-state** (`meta.id`) per UI test during **planning**, include **authoring `*.world.js` scripts** (and any missing seed APIs) in the **plan / setup** work, then during execution **bring the environment to that world-state before** driving the app with **Playwright**—see **[`testing-process.md`](./testing-process.md)**. File shape, `ensureWorldState`, and composition are in **[`world-states.md`](./world-states.md)**.

---

## Test writing workflow

1. **Target URL** — Ask for preview URL or local stack URL if unclear. In the `playwright.config.js` we have set  
`baseURL:process.env.BASE_URL,` - so tests should simply specify relative urls, the preview URL should be set as the `BASE_URL` env var so that the test picks up that.

2. **Decide what to write or change** — If **`testchimp-mcp-client`** is configured in the agent environment, call the MCP tools **`get_requirement_coverage`** and **`get_execution_history`** with the request shapes in [Calling the TestChimp MCP tools](#calling-the-testchimp-mcp-tools). Combine responses with the PR diff, commits, and plan files in the repo to choose scenarios and files to touch. If MCP is not available, infer gaps from plans and existing tests.
3. **Per scenario** — Add or update a test; reuse existing page objects, fixtures, and env conventions in the repo.
4. **Drive the real app with Playwright (no invented steps)** — Human input is often required **before** you start (URLs, accounts, feature flags, which environment to hit) **and sometimes during** a run (unexpected MFA, captcha, missing seed data, “which org should I use?”). Do not guess secrets or one-off values (unless you deem any random suitable guessed value should suffice for a specific step).

   - **Discover values in the repo before asking:** Read **`.env-*`** files under the mapped tests folder (e.g. `.env-QA`) for standard names like `BASE_URL`, auth-related vars, and feature toggles. Skim **`setup/`** scripts and global setup for how auth state or data is created. Open **existing specs** in the same area to see which env vars, fixtures, and URLs peers use.
   - **Ask early when something crucial is missing** — If authentication details, org/project identifiers, or other data the scenario depends on is not discoverable from the repo or plans, **ask the user before** driving the browser. If you only learn what is missing **while** interacting (e.g. login fails, wrong tenant), **stop and ask** rather than fabricating credentials or steps.
   - **Run in headed mode by default** — Use a **headed** Playwright run (if in a graphic support environment such as local dev) so the user can see the browser (unless they explicitly request headless). The goal of the interaction pass is to **record the Playwright commands that actually work** against the live UI.
   - **Multi-pass authoring (recommended):**
     1. **First pass — record behavior:** Write the flow as real **`await page…` / `expect(…)`** calls. Where the UI is unclear, add a short **`// intent:`** comment above the line describing what you are trying to do, then the concrete Playwright line. Do not skip browser verification.
     2. **Second pass — harden brittle steps:** Re-read the spec. Where a selector-based step is likely **brittle** or **non-semantic**, replace it with **`ai.act` / `ai.verify` / `ai.extract`**, using the intent comments as guidance for natural-language objective. Remove redundant intent comments; **keep only comments that demarcate major sections** of the test (long flows, distinct phases).
     3. **Third pass — fit the suite:** Wire in **hooks**, **fixtures**, **`process.env`**, **page objects**, shared **timeouts**, and project **imports** (e.g. reporter runtime) so the test matches how neighboring files are structured.
5. **Imports in SmartTest files** ALWAYS add those.
   - `import { ai } from 'ai-wright';`
   - `import 'playwright-testchimp/runtime';`

   The above enables AI steps in tests and TrueCoverage event tracking. For **`ensureWorldState` / `teardownWorldState`** imports when using world-state steps, see **[`world-states.md`](./world-states.md)**.

6. **Scenario link** — As the **first statement inside the test body**:
   - `// @Scenario: #TS-xxx <Scenario title>`  
   Use the scenario id from the plan markdown (`#TS-xxx`). Same pattern as: 
   `// @Scenario: #TS-102 Checkout with credit card`.

7. **Mix Playwright and AI** — Prefer plain Playwright for stable, fast paths; use **`ai.*`** when the selector-based step looks brittle or intent-driven steps are clearer (see [AI steps](#ai-steps-ai-wright-when-to-use-what)). AI steps use an agent that observes the screen to fulfill the objective, so they are typically **slower** than direct locators - though more flexible to UI variances.

---

## Recommended tests folder layout

SmartTests live under whatever folder the team mapped as **tests** in TestChimp (the on-disk name may differ; structure below applies **inside** that root). A typical layout:

```text
<mapped-tests-root>/
  pages/           # Page objects — reusable per-page helpers
  e2e/             # Many teams put specs here (or use other subfolders)
  setup/           # Global setup (see below)
    world-states/  # *.world.js — named seed states ([world-states.md](./world-states.md))
  assets/          # Files used in tests (e.g. uploads)
  .env-QA          # Example env file; more environment types as needed - QA env is auto created by default
  playwright.config.js <-- unlike typical Playwright structure, in TestChimp, the config file lives inside the tests folder.
```

- **`pages/`** — Encapsulate navigation and selectors per page.
- **`setup/`** — Global setup runs **before** browser tests via Playwright [project dependencies](https://playwright.dev/docs/test-global-setup-teardown#option-1-project-dependencies). Use for seed data, auth state, shared harness. **`setup/world-states/`** holds **`*.world.js`** world-state scripts (see [world-states.md](./world-states.md)). Usually excluded from the main test project with `testIgnore` in config.
- **`e2e/`** (and siblings) — Specs match `*.{spec,test}.{js,ts}` under the tests root except ignored paths like `setup/`.
- **`assets/`** — Static files (uploads, etc.).
- **`.env-*`** — Per-environment variables; **QA** is a common default. Read with `process.env.VAR_NAME`.
- **`playwright.config.js`** — Playwright config; projects using TestChimp add **`playwright-testchimp-reporter`**.

Keep **`@playwright/test`** and **`playwright`** on the **same** version; use npm `overrides` if dependencies pull mismatched Playwright versions. TestChimp requires Playwright 1.59.0+.

**Platform paths vs repo paths:** In API and MCP calls, paths are **platform-rooted**: first segment is `tests` or `plans`, then subfolders (e.g. `["tests","checkout"]`). The repo folder mapped to **tests** might be named `ui_tests` — you still pass `tests/checkout/...` in `scope.folderPath` when scoping coverage to that area.

---

## Calling the TestChimp MCP tools

These tools are provided by the **`testchimp-mcp-client`** package when it is installed and registered as an MCP server (e.g. Cursor `mcp.json`). The agent invokes them as **MCP tools** by name; arguments are JSON-shaped objects matching the schemas below.

**Environment (MCP process):**

| Variable | Required | Purpose |
|----------|----------|---------|
| `TESTCHIMP_API_KEY` | Yes | Authenticates to TestChimp; project is inferred from the key. |

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
import 'playwright-testchimp-reporter/runtime';

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

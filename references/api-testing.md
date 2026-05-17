# API testing for `/testchimp test`

Use this reference when the Plan phase decides a scenario is better automated as an **API test** than a UI SmartTest.

API tests are authored in **`api/`** at the SmartTests root (folder with **`.testchimp-tests`**). On **mobile** and **multi-platform** scaffolds, import **`{ test, expect }`** from **`api/fixtures/index.js`** and run with the config’s **`api`** project ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)). Reference payloads live in **`assets/`**.

---

## Goal

Convert a validated user flow into a robust Playwright API test by:

1. Capturing real request/response traffic while running the scenario in the browser.
2. Selecting only the API calls relevant to the scenario outcome.
3. Rebuilding that sequence as deterministic API assertions in **`api/`**.

## Workflow

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
5. **Link to Relevent Scenarios**
   - Just like in SmartTests, you can add scenario link comments - inside the api tests with: `// @Scenario: #TS-101 Scenario Title` style comments. (Follow the format strictly).
6. **Add strong verifications**
   - Assert status codes and key business fields, not just transport success.
   - Verify state transitions and side effects expected by the scenario.
   - Add negative/guard assertions where they materially protect against regressions.

---

## Important constraints

- `ai.act`, `ai.verify`, and `ai.extract` are **UI interaction helpers** and are **not used** inside API tests.
- Prefer deterministic request construction and explicit assertions for API suites.
- If the project lacks an **`api`** Playwright/Mobilewright project, update **`playwright.config.js`** or **`mobilewright.config.ts`** so **`testDir: 'api'`** (or equivalent) and **`api/fixtures`** are wired — see templates in [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md).

---

## Execution checklist

- Capture regex approved and persisted in `plans/knowledge/ai-test-instructions.md`.
- API test file added under **`api/`**.
- Optional payload fixtures (if any) stored under **`assets/`**.
- Playwright config includes API project with setup dependency.
- Test passes locally in the intended environment.

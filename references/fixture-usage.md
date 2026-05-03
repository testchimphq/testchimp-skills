# Playwright fixtures (`<tests_root>/fixtures`)

Use **Playwright fixtures** (`test.extend`, `mergeTests`) for data setup and teardown that must run **per test**, with the same behavior at **author time** and **CI time**. Fixtures call your **seed**, **teardown**, and **read** HTTP surfaces described in [`seeding-endpoints.md`](./seeding-endpoints.md).

**Standard layout (mandatory for SmartTests):** Under the mapped **tests** root, keep **`tests/fixtures/`** and a master **`fixtures/index.js`** (or `index.ts`). The platform seeds this file for new projects; specs **must** import **`test` / `expect`** from it only (relative path), not from **`@playwright/test`**, so **`installTestChimp`** wraps the same merged **`test`**: **TrueCoverage** CI metadata, the **`markScreenState`** fixture (traces + ExploreChimp when enabled), and reporter alignment stay correct. Requires **`@testchimp/playwright` ≥ 0.1.8**.

**`installTestChimp` vs `installTrueCoverage`:** Prefer **`installTestChimp`** from **`@testchimp/playwright/runtime`** — it is the **supported name** (TrueCoverage plus ExploreChimp wiring and related TestChimp runtime hooks). **`installTrueCoverage`** remains exported as a **deprecated alias** with the **same behavior**; migrate new and touched code to **`installTestChimp`** for clarity.

### When authoring or updating tests

- **Never** add a new SmartTest/API test that assumes Arrange data without either importing an **existing** fixture that already seeds that posture or adding **fixture + seed endpoint** work to the plan or mocks as needed.
- If you extend a fixture, verify the **HTTP contract** still matches the backend: new Arrange fields may require **seed handler updates**, not only client-side fixture changes.
- Keep **one source of truth** between branch plan **Arrange → Fixtures plan / Seed endpoint updates** and the code you implement; update the plan if Execute discovers missing probes or seeds.
- For the full gate checklist, see [`testing-process.md`](./testing-process.md) (**World-state → seed/fixture traceability** and **Batched order**).

---

## Layout

- **`fixtures/`** lives under the mapped **tests** tree as **`tests/fixtures/`** (next to `e2e/`, `setup/`, `playwright.config.*`).
- **One master file** (`fixtures/index.js` or `fixtures/index.ts`) imports **`mergeTests`** from `@playwright/test`, composes domain fixtures, wraps the result with **`installTestChimp`** from **`@testchimp/playwright/runtime`**, and re-exports **`test`** and **`expect`**. **`installTestChimp`** adds the **`markScreenState`** fixture to that merged **`test`** (see [`write-smarttests.md`](./write-smarttests.md#screen--state-markers-markscreenstate)).
- **Domain files** (e.g. `fixtures/auth.fixture.js`, `fixtures/billing.fixture.js`) each use **`import { test as base } from '@playwright/test'`** (or extend another base) **inside the fixture module only** — not in spec files.

**Discoverability:** Add a **short comment above** each fixture extension describing **what application posture** it establishes (entities, flags, roles). Agents can grep `fixtures/` to find the right dependency for a scenario.

---

## Master file pattern (`mergeTests` + `installTestChimp`)

```javascript
// tests/fixtures/index.js — single entry: every spec imports test/expect from here
import { mergeTests } from '@playwright/test';
import { installTestChimp } from '@testchimp/playwright/runtime';
import { test as auth } from './auth.fixture.js';
import { test as billing } from './billing.fixture.js';

export const test = installTestChimp(mergeTests(auth, billing));
export { expect } from '@playwright/test';
```

Specs use **one** import (adjust the relative path from the spec file to `tests/fixtures/index.js`):

```javascript
// e.g. tests/e2e/checkout/foo.spec.js
import { test, expect } from '../../fixtures/index.js';

test('example', async ({ page, markScreenState }) => {
  await page.goto('/app');
  await markScreenState('Home', 'default');
});
```

**Do not** import **`test`** from **`@playwright/test`** in **`*.spec.*`** files — that bypasses **`installTestChimp`** on the merged instance. Optional: side-effect **`import '@testchimp/playwright/runtime'`** still registers on the root Playwright `test` for backward compatibility; the supported pattern is **`installTestChimp`** in this master file only.

---

## `testInfo` for scoped, retry-safe data

Inside fixture factories, use **`testInfo`** to make created data **unique per test** and safe under **retries**:

- Build labels from **`testInfo.testId`**, **`testInfo.titlePath`**, **`testInfo.workerIndex`**, or a suffix from **`testInfo.parallelIndex`** as appropriate for your backend.
- Prefer **idempotent** seed APIs ([`seeding-endpoints.md`](./seeding-endpoints.md)); combine with **read-before-write** in the fixture when useful.

Example shape (illustrative):

```javascript
import { test as base } from '@playwright/test';

export const test = base.extend({
  seededOrg: async ({ request }, use, testInfo) => {
    const label = `e2e-${testInfo.testId}`.replace(/[^a-zA-Z0-9-_]/g, '_');
    // call seed API with label; store ids for teardown
    const ctx = await seedOrgViaApi(request, { label });
    await use(ctx);
    await teardownOrgViaApi(request, ctx);
  },
});
```

---

## Agent “probe” session (authoring against a provisioned env)

To explore the UI **after** the same data posture a real test will use:

1. Add a **temporary** spec that imports **`test` from your relative `fixtures/index.js`** (same merged object as production tests).
2. Declare the **fixture dependencies** the scenario needs in the test signature.
3. After navigation/setup lines, add **`await page.pause()`**.
4. Run: **`npx playwright test path/to/probe.spec.js --headed --debug`** (see [Playwright debugging](https://playwright.dev/docs/debug)). Fixtures run in the normal test lifecycle **before** the pause; use the inspector to resume or step. **Delete** the temp file when done so nothing lingers in the repo.

**Authored tests** should use the **same** `fixtures` entry so execution-time state matches what you validated at author time.

---

## Relationship to `setup/` and global setup

- **`setup/`** Playwright projects (global setup, storage state) remain valid for **one-time** or **expensive** work (e.g. compile artifacts, shared auth file).
- **Per-test** data that must be created and torn down with the test belongs in **`fixtures/`**, not in ad hoc `beforeEach` scattered across specs.

---

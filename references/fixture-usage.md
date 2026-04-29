# Playwright fixtures (`<tests_root>/fixtures`)

Use **Playwright fixtures** (`test.extend`, `mergeTests`) for data setup and teardown that must run **per test**, with the same behavior at **author time** and **CI time**. Fixtures call your **seed**, **teardown**, and **read** HTTP surfaces described in [`seeding-endpoints.md`](./seeding-endpoints.md).

### When authoring or updating tests

- **Never** add a new SmartTest/API test that assumes Arrange data without either importing an **existing** fixture that already seeds that posture or adding **fixture + seed endpoint** work to the plan or mocks as needed.
- If you extend a fixture, verify the **HTTP contract** still matches the backend: new Arrange fields may require **seed handler updates**, not only client-side fixture changes.
- Keep **one source of truth** between branch plan **Arrange → Fixtures plan / Seed endpoint updates** and the code you implement; update the plan if Execute discovers missing probes or seeds.
- For the full gate checklist, see [`testing-process.md`](./testing-process.md) (**World-state → seed/fixture traceability** and **Batched order**).

---

## Layout

- **`fixtures/`** lives at the **SmartTests root** (next to `e2e/`, `setup/`, `playwright.config.*`).
- **One master file** (e.g. `fixtures/index.js` or `fixtures/index.ts`) imports **`mergeTests`** from `@playwright/test`, imports each **domain** module, and exports a single merged **`test`** (and usually **`expect`**).
- **Domain files** (e.g. `fixtures/auth.fixture.js`, `fixtures/billing.fixture.js`) each extend `test` with fixtures for that domain. Keep domains separate so the tree stays navigable.

**Discoverability:** Add a **short comment above** each fixture extension describing **what application posture** it establishes (entities, flags, roles). Agents can grep `fixtures/` to find the right dependency for a scenario.

---

## Master file pattern (`mergeTests`)

```javascript
// fixtures/index.js — single entry: specs import from here
import { mergeTests } from '@playwright/test';
import { test as auth } from './auth.fixture';
import { test as billing } from './billing.fixture';

export const test = mergeTests(auth, billing);
export { expect } from '@playwright/test';
```

Specs use **one** import:

```javascript
import { test, expect } from '../fixtures'; // adjust relative path
```

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

1. Add a **temporary** spec that imports **`test` from `../fixtures`** (same merged object as production tests).
2. Declare the **fixture dependencies** the scenario needs in the test signature.
3. After navigation/setup lines, add **`await page.pause()`**.
4. Run: **`npx playwright test path/to/probe.spec.js --headed --debug`** (see [Playwright debugging](https://playwright.dev/docs/debug)). Fixtures run in the normal test lifecycle **before** the pause; use the inspector to resume or step. **Delete** the temp file when done so nothing lingers in the repo.

**Authored tests** should use the **same** `fixtures` entry so execution-time state matches what you validated at author time.

---

## Relationship to `setup/` and global setup

- **`setup/`** Playwright projects (global setup, storage state) remain valid for **one-time** or **expensive** work (e.g. compile artifacts, shared auth file).
- **Per-test** data that must be created and torn down with the test belongs in **`fixtures/`**, not in ad hoc `beforeEach` scattered across specs.

---

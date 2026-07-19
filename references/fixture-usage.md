# Playwright fixtures (`<tests_root>/fixtures`)

Use **Playwright fixtures** (`test.extend`, `mergeTests`) for data setup and teardown that must run **per test**, with the same behavior at **author time** and **CI time**. Fixtures call your **seed**, **teardown**, and **read** HTTP surfaces described in [`seeding-endpoints.md`](./seeding-endpoints.md).

**Scaffold layouts and where specs/fixtures live:** [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — read **`.testchimp-tests`** first.

## Project type: web vs mobile vs multi-platform

| `.testchimp-tests` | Layout | Fixture barrels |
|--------------------|--------|-----------------|
| empty / `web` | flat `e2e/`, `fixtures/` | **`fixtures/index.js`** only |
| `mobile` (legacy `ios`/`android` → mobile) | `api/`, `mobile/e2e/`, `shared/` | **`api/fixtures/`**, **`mobile/fixtures/`** (`installTestChimp(..., { uiFixture: 'screen' })`) |
| `multi-platform` | above + `web/` | **`api/fixtures/`**, **`mobile/fixtures/`**, **`web/fixtures/`** |

- **Web UI:** `@playwright/test`, **`page`**, ai-wright when needed.
- **Mobile UI:** `@mobilewright/test`, **`screen`** / **`device`** — no ai-wright ([`mobilewright-smarttests.md`](./mobilewright-smarttests.md)).
- **API specs:** `@playwright/test`, **`request`** — import **`api/fixtures/index.js`**.

**`@testchimp/playwright` runtime:** The plugin reads **`testInfo.project.use.platform`** (`ios` | `android`; omitted = web). Set **`use.platform`** on Mobilewright UI projects in config (mobilewright **>= 0.0.37**). Do **not** rely on **`TESTCHIMP_PROJECT_TYPE`** for runtime branching.

Every **`*.spec.*`** imports **`{ test, expect }`** from the **correct barrel** (relative path) — never from `@playwright/test` or `@mobilewright/test` directly — so **`installTestChimp`** wraps the same merged **`test`** (TrueCoverage, **`markScreenState`**, ExploreChimp). Requires **`@testchimp/playwright` ≥ 0.1.8**.

**`installTestChimp` vs `installTrueCoverage`:** Prefer **`installTestChimp`** — **`installTrueCoverage`** is a deprecated alias with identical behavior.

### When authoring or updating tests

- **Never** add a SmartTest/API test that assumes Arrange data without an **existing** fixture or planned **fixture + seed** work.
- Extend fixtures only with matching **HTTP contract** updates on seed/read routes.
- Keep the branch plan **Arrange → Fixtures plan** in sync with code.
- For gates, see [`run-qa.md`](./run-qa.md).

---

## Layout (by scaffold)

### Web-only (`project_type=web` or empty)

```
tests/
  fixtures/index.js          # installTestChimp(mergeTests(...)) — default page
  fixtures/*.fixture.js
  e2e/**/*.spec.*
```

### Mobile / multi-platform

```
tests/
  shared/                      # seed helpers only — NOT specs, NOT test.extend barrels
  api/fixtures/index.js
  api/fixtures/*.fixture.js
  api/**/*.spec.*
  mobile/fixtures/index.js     # installTestChimp(mergeTests(...), { uiFixture: 'screen' })
  mobile/fixtures/*.fixture.js
  mobile/e2e/common|ios|android/**/*.spec.*
  web/fixtures/index.js        # multi-platform only
  web/e2e/**/*.spec.*
```

**`shared/`:** Platform-agnostic modules (e.g. `createSeedUser(request, testInfo)`) imported from domain `*.fixture.js` files under **`api/fixtures/`** or **`mobile/fixtures/`** — see [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md).

---

## Master file pattern (`mergeTests` + `installTestChimp`)

**Web barrel (`fixtures/index.js` or `web/fixtures/index.js`):**

```javascript
import { mergeTests } from '@playwright/test';
import { installTestChimp } from '@testchimp/playwright/runtime';
import { test as auth } from './auth.fixture.js';

export const test = installTestChimp(mergeTests(auth));
export { expect } from '@playwright/test';
```

**API barrel (`api/fixtures/index.js`):**

```javascript
import { mergeTests } from '@playwright/test';
import { installTestChimp } from '@testchimp/playwright/runtime';
import { test as seed } from './seed.fixture.js';

export const test = installTestChimp(mergeTests(seed));
export { expect } from '@playwright/test';
```

**Mobile UI barrel (`mobile/fixtures/index.js`):**

```javascript
import { mergeTests } from '@mobilewright/test';
import { installTestChimp } from '@testchimp/playwright/runtime';
import { test as auth } from './auth.fixture.js';

export const test = installTestChimp(mergeTests(auth), { uiFixture: 'screen' });
export { expect } from '@mobilewright/test';
```

Domain modules use **`test as base`** from the same package as their barrel (**`@playwright/test`** or **`@mobilewright/test`**) — only inside **`*.fixture.js`**, not in specs.

**Spec imports (adjust `../` depth):**

```javascript
// web/e2e/checkout.spec.js (multi-platform)
import { test, expect } from '../fixtures/index.js';

// api/billing.spec.js
import { test, expect } from './fixtures/index.js';

// mobile/e2e/common/login.spec.js
import { test, expect } from '../../fixtures/index.js';

test('login', async ({ screen, markScreenState }) => {
  await markScreenState('Login', 'default');
});
```

---

## Domain fixtures and `testInfo`

Inside fixture factories, use **`testInfo`** for **per-test**, retry-safe labels:

- Build labels from **`testInfo.testId`**, **`testInfo.titlePath`**, **`testInfo.workerIndex`**, or **`testInfo.parallelIndex`**.
- Prefer **idempotent** seed APIs ([`seeding-endpoints.md`](./seeding-endpoints.md)); combine with **read-before-write** when useful.

```javascript
import { test as base } from '@playwright/test'; // @mobilewright/test in mobile/fixtures/*.fixture.js

export const test = base.extend({
  seededOrg: async ({ request }, use, testInfo) => {
    const label = `e2e-${testInfo.testId}`.replace(/[^a-zA-Z0-9-_]/g, '_');
    const ctx = await seedOrgViaApi(request, { label });
    await use(ctx);
    await teardownOrgViaApi(request, ctx);
  },
});
```

**Do not** import **`test`** from **`@playwright/test`** or **`@mobilewright/test`** in **`*.spec.*`** — that bypasses **`installTestChimp`**.

---

## Agent “probe” session (web UI)

1. Temporary spec importing **`test`** from the correct barrel with the scenario’s fixture deps.
2. After setup, **`await page.pause()`** (web only).
3. Run **`npx playwright test path/to/probe.spec.js --headed --debug`**; delete the probe when done.

Production specs use the **same** barrel so posture matches authoring.

---

## Relationship to `setup/` and global setup

- **`setup/`** projects: one-time or expensive work (storage state, global setup).
- **Per-test** create/teardown belongs in **`fixtures/`** (domain `*.fixture.js` + barrel `index.js`), not scattered `beforeEach`.

## Related

- [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — decision tables, run commands, plan checklist
- [`write-smarttests.md`](./write-smarttests.md) — `markScreenState`, scenario links
- [`mobilewright-smarttests.md`](./mobilewright-smarttests.md) — `screen` / `device`, config
- [`instrument-truecoverage.md`](./instrument-truecoverage.md) — RUM + `use.platform`
- [`run-explorechimp.md`](./run-explorechimp.md) — ExploreChimp env vars

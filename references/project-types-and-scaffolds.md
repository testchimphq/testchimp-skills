# TestChimp project types and scaffolds

## Two concepts (do not conflate)

| Concept | Where | Values | Purpose |
|--------|--------|--------|---------|
| **Scaffold type** | `.testchimp-tests` → `project_type=` | `web`, `mobile`, `multi-platform` | Folder tree and which config files exist |
| **Run platform** | Mobilewright `projects[].use.platform` | `ios`, `android` (omit = web) | `@testchimp/playwright` TrueCoverage / ExploreChimp branching per test |

The plugin does **not** read `TESTCHIMP_PROJECT_TYPE` or a platform env var. Set `use.platform` on Mobilewright UI projects (mobilewright **>= 0.0.37** for per-project `installApps`) and pass `installTestChimp(base, { uiFixture: 'screen' })` from `mobile/fixtures/index.js`. Fallback: Mobilewright **0.0.36+** adds `testInfo.annotations` (`device.platform`, `device.id`, …) after device allocation; the plugin uses `device.platform` when `use.platform` is omitted.

Optional agent/CI env `TESTCHIMP_PROJECT_TYPE=web|mobile|multi-platform` documents scaffold intent only; it is not consumed by the runtime.

## Scaffold layouts

### `web`

```
tests/
  .testchimp-tests          # project_type=web
  playwright.config.js
  fixtures/index.js
  setup/global.setup.spec.js
  pages/
  e2e/
  assets/
```

### `mobile`

```
tests/
  .testchimp-tests          # project_type=mobile
  mobilewright.config.ts    # setup, api, ios, android projects
  setup/
  shared/                   # seed helpers (not specs)
  api/fixtures/index.js
  api/*.spec.*
  mobile/fixtures/index.js  # installTestChimp(..., { uiFixture: 'screen' })
  mobile/pages/
  mobile/e2e/common|ios|android/
  assets/
```

### `multi-platform`

Everything in **mobile**, plus:

```
  playwright.config.js      # setup, api, web
  web/fixtures/index.js
  web/pages/
  web/e2e/
```

## Running tests

```bash
# Web
npx playwright test -c playwright.config.js --project chromium

# Multi-platform web + API
npx playwright test -c playwright.config.js --project web
npx playwright test -c playwright.config.js --project api

# Mobile UI (platform from config project use.platform)
npx mobilewright test -c mobilewright.config.ts --project ios
npx mobilewright test -c mobilewright.config.ts --project android

# API on mobile scaffold (Playwright request fixture)
npx mobilewright test -c mobilewright.config.ts --project api
```

## Legacy markers

`project_type=ios` or `project_type=android` → treat as **`mobile`**; do not create ios/android-only flat trees.

---

## Agent authoring guide (where tests and fixtures go)

**Always read `.testchimp-tests` first** and load this doc during **Plan** and **Execute** for `/testchimp test`, `/testchimp evolve`, and SmartTest authoring. Paths below are relative to the **SmartTests root** (folder containing `.testchimp-tests`).

### Scaffold type → configs and runners

| `project_type` | Config file(s) | UI runner | API runner |
|----------------|----------------|-----------|------------|
| `web` (or empty) | `playwright.config.js` | `npx playwright test` — `chromium` (or project name in config) | Same config — `api` project if present, else co-locate under `e2e/` |
| `mobile` | `mobilewright.config.ts` | `npx mobilewright test -c mobilewright.config.ts --project ios\|android` | `npx mobilewright test -c mobilewright.config.ts --project api` |
| `multi-platform` | **both** configs above | Web UI: `playwright.config.js --project web` | `playwright.config.js --project api` **or** mobilewright `--project api` (same `api/` tree) |

### Where to put specs (decision table)

| You are writing… | `web` | `mobile` | `multi-platform` |
|------------------|-------|----------|-------------------|
| **Web UI SmartTest** | `e2e/**/*.spec.{js,ts}` | — | `web/e2e/**/*.spec.{js,ts}` |
| **Mobile UI (ios + android)** | — | `mobile/e2e/common/**/*.spec.*` | `mobile/e2e/common/**/*.spec.*` |
| **Mobile UI (iOS-only)** | — | `mobile/e2e/ios/**/*.spec.*` | `mobile/e2e/ios/**/*.spec.*` |
| **Mobile UI (Android-only)** | — | `mobile/e2e/android/**/*.spec.*` | `mobile/e2e/android/**/*.spec.*` |
| **API / request-only tests** | `api/` or legacy flat `e2e/` | `api/**/*.spec.*` | `api/**/*.spec.*` |
| **Page objects (web)** | `pages/` | — | `web/pages/` |
| **Page objects (mobile)** | — | `mobile/pages/` | `mobile/pages/` |
| **Static payloads** (JSON, images) | `assets/` | `assets/` | `assets/` |
| **Global setup** | `setup/global.setup.spec.*` | `setup/global.setup.spec.*` | `setup/global.setup.spec.*` |

**Do not** put `*.spec.*` under `shared/`, `fixtures/`, or `pages/` — those folders are not test discovery roots.

### Three fixture barrels (mobile / multi-platform)

Specs **must** import `{ test, expect }` from the **correct** barrel — never from `@playwright/test` or `@mobilewright/test` directly.

| Barrel | Base package | `installTestChimp` | Used by specs in |
|--------|--------------|------------------|------------------|
| `fixtures/index.js` | `@playwright/test` | default (`page`) | **`web` only** — `e2e/` |
| `api/fixtures/index.js` | `@playwright/test` | default (`page`) | **`api/`** — request-based tests |
| `mobile/fixtures/index.js` | `@mobilewright/test` | `{ uiFixture: 'screen' }` | **`mobile/e2e/**`** |
| `web/fixtures/index.js` | `@playwright/test` | default (`page`) | **`web/e2e/**`** (multi-platform only) |

**Import path examples** (adjust `../` depth to your spec depth):

```javascript
// web/e2e/checkout.spec.js (multi-platform)
import { test, expect } from '../fixtures/index.js';

// api/billing.spec.js
import { test, expect } from './fixtures/index.js';

// mobile/e2e/common/login.spec.js
import { test, expect } from '../../fixtures/index.js';
```

### `shared/` — seed helpers, not tests

Use **`shared/`** for **platform-agnostic JavaScript modules** consumed by fixtures or seed routes — **not** Playwright specs.

| Put here | Examples |
|----------|----------|
| **Yes** | `shared/create-seed-user.js`, `shared/build-auth-headers.js`, shared constants for seed payloads |
| **No** | `*.spec.js`, `test.extend` modules that should live under a `fixtures/` barrel |

**Pattern:** Domain fixtures in `api/fixtures/*.fixture.js` (or `mobile/fixtures/`, `web/fixtures/`) call helpers from `shared/` inside `test.extend` factories that hit **seed/teardown/read** HTTP endpoints ([`seeding-endpoints.md`](./seeding-endpoints.md)).

```javascript
// api/fixtures/user.fixture.js
import { test as base } from '@playwright/test';
import { createSeedUser } from '../../shared/create-seed-user.js';

export const test = base.extend({
  seedUser: async ({ request }, use, testInfo) => {
    const user = await createSeedUser(request, testInfo);
    await use(user);
    // teardown via read-before-write or dedicated route
  },
});
```

Merge domain fixtures in the barrel’s `index.js` with `mergeTests`, then wrap once with `installTestChimp`.

### Platform-agnostic vs platform-specific tests (mobile)

| Intent | Folder | Playwright project |
|--------|--------|-------------------|
| Same flow on **both** iOS and Android | `mobile/e2e/common/` | `ios` and `android` (both match `common/`) |
| iOS-only UI (e.g. Apple Pay sheet) | `mobile/e2e/ios/` | `ios` only |
| Android-only UI (e.g. back gesture) | `mobile/e2e/android/` | `android` only |

Configs set `projects[].use.platform` to `ios` or `android`; `@testchimp/playwright` reads that for TrueCoverage / ExploreChimp ([`truecoverage.md`](./truecoverage.md)) and reports **`executionContext.platform`** on each test end (≥ **0.2.0**).

### Requirement coverage and execution history by platform

| Scaffold | Coverage rollup when `platform` is omitted on `get-requirement-coverage` |
|----------|-----------------------------------------------------------------------------|
| `web` | One record per scenario (WEB). |
| `mobile` | Up to **iOS** + **Android**; `NOT_ATTEMPTED` when no run in scope for a platform. |
| `multi-platform` | Up to **web** + **iOS** + **Android** with the same gap semantics. |

Agents compare gaps **per platform** (e.g. covered on iOS, not Android). CLI/MCP: [`cli.md`](./cli.md) § Platform execution reporting; MCP tool shapes: [`write-smarttests.md`](./write-smarttests.md).

### API tests in multi-platform / mobile

- Author under **`api/`** at the SmartTests root (not `tests/api` unless your mapped folder is literally nested — use paths **under the marker**).
- Use **`api/fixtures/index.js`** and the **`request`** fixture (Playwright API testing).
- **No** `page` / `screen` required unless you deliberately mix UI + API in one spec (avoid for new work).
- Run with **`playwright.config.js --project api`** (multi-platform / web) or **`mobilewright.config.ts --project api`** (mobile-only scaffold).

### Web-only projects (flat layout)

Legacy/simple **`web`** scaffold keeps a **single** `fixtures/index.js` and flat `e2e/`, `pages/`. Do **not** introduce `mobile/` or `web/` subfolders unless migrating to multi-platform.

### Plan-phase checklist (per proposed test)

When listing tests in the branch plan ([`testing-process.md`](./testing-process.md)), record for each:

1. **Scaffold path** — exact folder + filename (from table above).
2. **Fixture barrel** — which `fixtures/index.js` the spec will import.
3. **Fixture dependencies** — e.g. `seedUser`, `authenticatedPage` / `screen` + domain fixtures.
4. **`shared/` helpers** — new modules needed vs reuse.
5. **Runner command** — which config + `--project` for Validate.

---

## Config templates (repo assets)

| Asset | Purpose |
|-------|---------|
| `assets/template_playwright.config.js` | Web-only scaffold |
| `assets/template_mobile_mobilewright.config.ts` | Mobile: setup + api + ios + android |
| `assets/template_multi_platform_playwright.config.js` | Web + api projects |
| `assets/template_multi_platform_mobilewright.config.ts` | Native: same mobile matrix |
| `assets/template_fixtures.index.api.js` | Starter `api/fixtures/index.js` |
| `assets/template_fixtures.index.mobile.js` | Starter `mobile/fixtures/index.js` |

Deprecated: `template_ios_mobilewright.config.ts`, `template_android_mobilewright.config.ts` (per-platform roots).

Platform creates folder rows via Featureservice OOBE; agents **create files** in those folders — no packaged `scaffold_*` directory tree in this skill repo.

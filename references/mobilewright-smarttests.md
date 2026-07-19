# SmartTests on mobile (Mobilewright)

Use this reference when **`.testchimp-tests`** has **`project_type=mobile`**, **`multi-platform`**, or legacy **`ios`/`android`**. Layout and paths: [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md). Upstream: [mobile-next/mobilewright](https://github.com/mobile-next/mobilewright).

## Stack vs web

| Concern | Web | Mobile |
|--------|-----|--------|
| Test runner in fixture barrels | `@playwright/test` | `@mobilewright/test` in **`mobile/fixtures/`** |
| Primary UI fixture | `page` | `screen`, `device` |
| Config | `playwright.config.js` | `mobilewright.config.ts` (`setup`, `api`, `ios`, `android`) |
| AI steps (ai-wright) | Supported | **Not supported** |
| TrueCoverage | `@testchimp/rum-js` + `installTestChimp` on web barrel | TestChimpRum in app + **`installTestChimp(..., { uiFixture: 'screen' })`** on **`mobile/fixtures/index.js`**; **`projects[].use.platform`** (`ios`/`android`) — [`instrument-truecoverage.md`](./instrument-truecoverage.md) |
| ExploreChimp | `markScreenState` + `page` | Same fixture on **`screen`** — [`run-explorechimp.md`](./run-explorechimp.md) |
| Traceability | `// @Scenario: #TS-…` | Same |

## Where to put tests

| Intent | Folder |
|--------|--------|
| Both iOS and Android | `mobile/e2e/common/` |
| iOS-only | `mobile/e2e/ios/` |
| Android-only | `mobile/e2e/android/` |
| API / request-only | `api/` (import **`api/fixtures/index.js`**) |
| Shared seed factories | `shared/` (not specs) |

**Multi-platform** web UI lives under **`web/e2e/`** with **`web/fixtures/index.js`** — not in `mobile/`.

## Dependencies

```bash
npm install mobilewright @mobilewright/test @testchimp/playwright
```

Keep **`mobilewright`** and **`@mobilewright/test`** on the **same version** (>= **0.0.37** for per-project `installApps`). Verify: `npm ls @mobilewright/test mobilewright`.

## Config: apps and platform

- **`installApps`:** APK (Android) / IPA or `.app` (iOS) paths in **`mobilewright.config.ts`**.
- **`bundleId`:** app under test.
- **`projects[].use.platform`:** `ios` or `android` on UI projects — required for `@testchimp/playwright` TrueCoverage/ExploreChimp per test.

Templates: [`../assets/template_mobile_mobilewright.config.ts`](../assets/template_mobile_mobilewright.config.ts), [`../assets/template_multi_platform_mobilewright.config.ts`](../assets/template_multi_platform_mobilewright.config.ts).

## Authoring rules

1. **Specs** import **`{ test, expect }`** only from **`mobile/fixtures/index.js`** (relative path) — never raw `@mobilewright/test`.
2. Use **`screen`** / **`device`** for UI — not web **`page.goto`** patterns.
3. **`await markScreenState('Screen', 'state')`** at stable UI boundaries.
4. **No** ai-wright on mobile.
5. Same Arrange / Act / Assert and fixture/seed patterns as web; cross-platform helpers in **`shared/`**.

## Running tests

From the **SmartTests root** (`.testchimp-tests`):

```bash
npx mobilewright test -c mobilewright.config.ts --project ios
npx mobilewright test -c mobilewright.config.ts --project android
npx mobilewright test -c mobilewright.config.ts --project api
```

See [`environment-management.md`](./environment-management.md) for device/simulator setup.

## Related

- [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)
- [`fixture-usage.md`](./fixture-usage.md)
- [`write-smarttests.md`](./write-smarttests.md)
- [`run-explorechimp.md`](./run-explorechimp.md)

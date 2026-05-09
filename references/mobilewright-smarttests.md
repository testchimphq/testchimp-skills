# SmartTests on mobile (Mobilewright)

Use this reference when **`.testchimp-tests`** (or project settings) indicate a **mobile** project (`project_type=android` or `project_type=ios`). Authoritative upstream docs: [mobile-next/mobilewright](https://github.com/mobile-next/mobilewright).

## Stack vs web

| Concern | Web (default) | Mobile |
|--------|----------------|--------|
| Test runner package in fixtures / setup | `@playwright/test` | `@mobilewright/test` |
| Primary UI fixture | `page` | `screen` (and related mobile fixtures such as `device` per Mobilewright) |
| Config file (typical scaffold) | `playwright.config.js` | `mobilewright.config.ts` |
| AI steps (`ai.act` / `ai.verify` / `ai.extract`) | Supported via **ai-wright** | **Not supported** — ai-wright does not support Mobilewright yet |
| TrueCoverage (RUM + coverage loop) | In scope by default per [`truecoverage.md`](./truecoverage.md) | **Not supported yet** — do not plan RUM/TrueCoverage for the native app under this skill |
| ExploreChimp | Supported with `markScreenState` | Supported — set **`TESTCHIMP_PROJECT_TYPE`** to **`android`** or **`ios`** on **every** run; browser projects use **`web`** ([`exploratory_runs.md`](./exploratory_runs.md)) |
| Requirement traceability | `// @Scenario: #TS-…` in tests | Same as web |

## Dependencies

From the SmartTests package root (same place as other test deps):

```bash
npm install mobilewright
npm install @mobilewright/test
npm install @testchimp/playwright
```

Keep **`mobilewright`** and **`@mobilewright/test` on the same version** (see comments in template configs under [`../assets/`](../assets/)). Verify with `npm ls @mobilewright/test mobilewright`.

## Config: app binary path

Scaffolded **`mobilewright.config.ts`** includes **`installApps`** with a placeholder path:

- **Android:** replace with the path to your **`.apk`** (local emulator builds often use a debug APK from Gradle output; CI with cloud devices may use a release APK).
- **iOS:** replace with the path to your **`.ipa`** or simulator **`.app`** as required by your workflow (see Mobilewright docs and your build pipeline).

Also set **`bundleId`** to the app under test.

## Authoring rules

1. **Specs** import **`{ test, expect }`** only from **`tests/fixtures/index.js`** (relative path), same as web. The platform scaffold uses **`@mobilewright/test`** as the base **`test`** inside that file for mobile projects.
2. **Use `screen` (and `device`, etc.)** for UI automation per Mobilewright — not **`page.goto`**-style web patterns unless the upstream API explicitly exposes them.
3. **Use `await markScreenState('ScreenName', 'stateName')`** at stable points (same traceability / ExploreChimp model as web).
4. **Do not** add **`import { ai } from 'ai-wright'`** or **`ai.act` / `ai.verify` / `ai.extract`** steps on mobile projects.
5. **Prefer** selector-based or Mobilewright-documented APIs for interactions; follow the same Arrange / Act / Assert and fixture/seed patterns as web for world-state.

## Running tests

- Run from the **SmartTests root** (folder with **`.testchimp-tests`**).
- Use the repo’s documented command; typical pattern is **`npx playwright test`** with config pointing at **`mobilewright.config.ts`** (for example **`npx playwright test -c mobilewright.config.ts`** if no npm script wraps it).
- For environment/doctor/simulator setup, see [`environment-management.md`](./environment-management.md) § Mobile.

## Related

- [`fixture-usage.md`](./fixture-usage.md) — mergeTests + `installTestChimp` for web vs mobile bases
- [`write-smarttests.md`](./write-smarttests.md) — scenario links, `markScreenState`, mobile limitations
- [`exploratory_runs.md`](./exploratory_runs.md) — **`TESTCHIMP_PROJECT_TYPE`**

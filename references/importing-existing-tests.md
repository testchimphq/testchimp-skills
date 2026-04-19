# Importing and aligning existing Playwright tests (SmartTests)

This reference is for **`/testchimp init`** and any workflow that must decide whether a repo is **greenfield** SmartTests vs **existing Playwright**. It complements [`init-testchimp.md`](./init-testchimp.md) Key Area 1 and Key Area 5.

**Core idea:** SmartTests are **standard Playwright** with TestChimp additions (traceability, AI steps, world-states, reporting). The **mapped tests folder** in Git is the single root for `npx playwright test`; **`playwright.config.*` lives inside that folder**, not at an arbitrary repo root—a common drift to fix.

---

## Definitions

### “Existing tests” means Playwright only

- **Existing tests** = at least one legitimate **`*.spec.{js,ts}`** file (TestChimp SmartTests naming) under the **SmartTests root** (the folder that contains `.testchimp-tests`).
- **Exclude** everything under **`setup/**`** from the “do we have a real suite?” count (the platform scaffold includes e.g. `global.setup.spec.*` there).

### Greenfield vs has existing Playwright

- **Greenfield:** the mapped SmartTests folder has **no** real specs beyond scaffold under `setup/` (litmus: no `*.spec.{js,ts}` outside `setup/`).
- **Has existing Playwright tests:** at least one **`*.spec.{js,ts}`** outside `setup/` as above.

### Out of scope for this skill

Migrating **non-Playwright** suites (Selenium, Cypress, WebdriverIO, etc.) into SmartTests is a **separate** task for an agent; it is **not** part of the TestChimp skill flows.

---

## Mapping scenarios (after Git mapping in TestChimp)

By init time, the user has already chosen a folder to map as **tests** in TestChimp; the repo may have `.testchimp-tests` and scaffold files.

1. **Mapped folder = existing Playwright tree**  
   `.testchimp-tests` sits next to legacy specs. Align structure to TestChimp expectations: config inside folder, `playwright-testchimp` reporter, `setup` project + `setup/world-states/`, optional SmartTest imports (below).

2. **Mapped folder = new blank SmartTests folder**  
   `.testchimp-tests` in a **new** folder; **another** directory still holds old Playwright tests. **Ask** whether to **move** legacy `*.spec.{js,ts}` (and related helpers) into the mapped folder. If yes: **plan** moves in Phase 2; **execute** in Phase 3 after approval. Leaving tests outside the mapped folder breaks platform path / coverage expectations for that mapping.

3. **Already-configured SmartTests folder**  
   The folder with `.testchimp-tests` also has `playwright.config.*` listing **`playwright-testchimp/reporter`** in `reporter`. Treat as **prior TestChimp wiring** (teammate already set up, or reconnect). **Report** this in discovery; avoid duplicating scaffold or overwriting without cause.

---

## What TestChimp adds on top of Playwright (incremental)

Teams can adopt these gradually on an existing suite:

| Addition | Purpose |
|----------|---------|
| `// @Scenario` comments | Link specs to test-plan scenarios (traceability). |
| `import { ai } from 'ai-wright'` | Natural-language **`ai.act` / `ai.verify` / `ai.extract`** steps. |
| `playwright-testchimp/runtime` | **`defineWorldState` / `ensureWorldState`** for setup/teardown in hooks. |
| `import 'playwright-testchimp/runtime'` in **every** `*.spec.{js,ts}` | Enables runtime integration (e.g. TrueCoverage test-identity metadata during runs). Include in each spec file. |
| `playwright-testchimp/reporter` in config | Execution reporting to TestChimp. |

---

## Structural expectations (fix common drift)

- **`playwright.config.*` must live inside the mapped SmartTests folder** (the directory containing `.testchimp-tests`), not at monorepo root.
- **Run tests from that folder:**

```bash
cd /path/to/<mapped-tests-folder>
npx playwright test
```

- Use the skill template as the baseline: [`assets/template_playwright.config.js`](../assets/template_playwright.config.js) — **`setup`** project first, **`chromium`** (or browsers) with **`dependencies: ['setup']`**, **`testIgnore: ['**/setup/**']`**, and **`setup/world-states/`** for world-state scripts.

---

## Enabling TestChimp runtime and reporting

1. **`playwright-testchimp`** installed at the SmartTests **package root** (same `package.json` as `@playwright/test` for that folder).
2. In **`playwright.config.*`**, `reporter` includes **`['playwright-testchimp/reporter', { ... }]`**.
3. **`import 'playwright-testchimp/runtime'`** at the top of **each** `*.spec.{js,ts}` file (per TestChimp integration expectations).
4. **`setup/`** as a Playwright project that runs before main tests (see template); ensure **`setup/world-states/`** exists (create if missing).

---

## CI

- The workflow must **`cd` into the mapped tests folder** before **`npx playwright test`** (same as local). See [Run SmartTests in CI (Playwright)](https://docs.testchimp.io/smart-tests/run-in-ci-playwright).
- Set **`TESTCHIMP_API_KEY`** in CI secrets/env so the reporter and runtime smarts authenticate (see **`SKILL.md`** preamble for resolving the key from MCP config when authoring locally).

---

## Init workflow: plan vs execute

- **Phase 2 (plan):** If discovery finds **existing Playwright** outside the mapped folder, or **dual-folder** layout, include an explicit **import / alignment** subsection: moves, config path fixes, adding reporter + deps, `setup/world-states`, and adding `import 'playwright-testchimp/runtime'` to specs as agreed.
- **Phase 3 (execute):** Perform agreed **file moves** and **config edits** only after the user approves the plan—do not move tests silently.

---

## Related references

- [`init-testchimp.md`](./init-testchimp.md) — phased init, Key Area 1 & 5.
- [`write-smarttests.md`](./write-smarttests.md) — layout and authoring.
- [`truecoverage.md`](./truecoverage.md) — RUM / TrueCoverage (app-side).
- [`assets/template_playwright.config.js`](../assets/template_playwright.config.js) — canonical Playwright projects layout for SmartTests.

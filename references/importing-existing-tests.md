# Importing and aligning existing Playwright tests (SmartTests)

This reference is for **`/testchimp init`** and any workflow that must decide whether a repo is **greenfield** SmartTests vs **existing Playwright**. It complements [`init-testchimp.md`](./init-testchimp.md) Key Areas **1** (basic integration), **2** (import strategy), and **6** (CI).

**Core idea:** SmartTests are **standard Playwright** with TestChimp additions (traceability, AI steps, reporting). The **mapped tests folder** in Git is the single root for `npx playwright test`; **`playwright.config.*` lives inside that folder**, not at an arbitrary repo root—a common drift to fix.

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
   `.testchimp-tests` sits next to legacy specs. Align structure to TestChimp expectations: config inside folder, `playwright-testchimp` reporter, `setup` project + `fixtures/`, optional SmartTest imports (below).

2. **Mapped folder = new blank SmartTests folder**  
   `.testchimp-tests` in a **new** folder; **another** directory still holds old Playwright tests. **Ask** whether to **move** legacy `*.spec.{js,ts}` (and related helpers) into the mapped folder. If yes: **plan** moves in Phase 2; **execute** in Phase 3 after approval. Leaving tests outside the mapped folder breaks platform path / coverage expectations for that mapping.

3. **Already-configured SmartTests folder**  
   The folder with `.testchimp-tests` also has `playwright.config.*` listing **`playwright-testchimp/reporter`** in `reporter`. Treat as **prior TestChimp wiring** (teammate already set up, or reconnect). **Report** this in discovery; avoid duplicating scaffold or overwriting without cause.

---

## Migration strategies (Phase 1 choice)

During init **requirement gather**, when the repo is **not** greenfield or specs are split across folders, the user should pick how aggressively to converge on the **mapped SmartTests root** (the folder with `.testchimp-tests`):

| Strategy | What it means | Implications |
|----------|----------------|--------------|
| **Parallel SmartTests folder (gradual)** | The mapped folder is the canonical TestChimp home; legacy Playwright may live elsewhere **temporarily** while specs and helpers are **moved over incrementally**. | Local runs and CI must eventually **`cd`** into the mapped folder for SmartTests; until migration finishes, document which folder is authoritative for which specs. Platform/coverage paths assume tests under the **mapped** root. |
| **Retrofit in place** | The **existing** Playwright tree (where specs already live) **becomes** the SmartTests root: add `.testchimp-tests`, move or add `playwright.config.*` **inside** that folder, wire reporter/runtime, align `setup/` and `fixtures/` per template. | No long-lived duplicate e2e roots; faster single-folder mental model. May require a focused PR that touches many spec files (runtime import, config). |

**CI:** workflows must **`cd` into the mapped SmartTests folder** before `npx playwright test`, regardless of strategy. If parallel migration leaves some jobs pointing at the old path, fix them in the import plan (Phase 2) and execution (Phase 3).

---

## What TestChimp adds on top of Playwright (incremental)

Teams can adopt these gradually on an existing suite:

| Addition | Purpose |
|----------|---------|
| `// @Scenario` comments | Link specs to test-plan scenarios (traceability). |
| `import { ai } from 'ai-wright'` | Natural-language **`ai.act` / `ai.verify` / `ai.extract`** steps. |
| `playwright-testchimp/runtime` | TrueCoverage / reporter integration (`import 'playwright-testchimp/runtime'`). |
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

- Use the skill template as the baseline: [`assets/template_playwright.config.js`](../assets/template_playwright.config.js) — **`setup`** project first, **`chromium`** (or browsers) with **`dependencies: ['setup']`**, **`testIgnore: ['**/setup/**']`**, and a **`fixtures/`** tree per [`fixture-usage.md`](./fixture-usage.md).

---

## Enabling TestChimp runtime and reporting

1. **`playwright-testchimp`** installed at the SmartTests **package root** (same `package.json` as `@playwright/test` for that folder).
2. In **`playwright.config.*`**, `reporter` includes **`['playwright-testchimp/reporter', { ... }]`**.
3. **`import 'playwright-testchimp/runtime'`** at the top of **each** `*.spec.{js,ts}` file (per TestChimp integration expectations).
4. **`setup/`** as a Playwright project that runs before main tests (see template); add **`fixtures/`** when tests need shared seed/teardown ([`fixture-usage.md`](./fixture-usage.md)).

### Required: runtime import in every spec file

When **importing or aligning** an existing Playwright suite, treat this as **non-negotiable** for completion:

- **Every** `*.spec.{js,ts}` under the **mapped SmartTests root** (including specs **moved** in from a legacy folder and any **`setup/**/*.spec.*`** that Playwright runs as tests) must include **`import 'playwright-testchimp/runtime'`** as a top-of-file side effect (before or alongside other imports, per project style—**do not** skip files).

**Why:** That import wires the **test-side** TestChimp runtime used for **TrueCoverage** (test identity and related metadata during runs), **`ai-wright`** intelligent steps, and consistent integration with **`playwright-testchimp`** reporting—without it, those features are incomplete or unreliable even if the reporter is in config.

During **Phase 2 (plan)**, list adding/fixing this import as an explicit task for every affected file. During **Phase 3 (execute)**, verify with a repo-wide pass (e.g. search for `*.spec.{js,ts}` and confirm each contains the import) before marking import work **done**.

---

## CI

- The workflow must **`cd` into the mapped tests folder** before **`npx playwright test`** (same as local). See [Run SmartTests in CI (Playwright)](https://docs.testchimp.io/smart-tests/run-in-ci-playwright).
- Set **`TESTCHIMP_API_KEY`** in CI secrets/env so the reporter and runtime smarts authenticate (see **`SKILL.md`** preamble for resolving the key from MCP config when authoring locally).

---

## Init workflow: plan vs execute

- **Phase 2 (plan):** If discovery finds **existing Playwright** outside the mapped folder, or **dual-folder** layout, include an explicit **import / alignment** subsection: moves, config path fixes, adding reporter + deps, `fixtures/`, and **adding `import 'playwright-testchimp/runtime'` to every `*.spec.{js,ts}`** in scope (see [Required: runtime import in every spec file](#required-runtime-import-in-every-spec-file) above).
- **Phase 3 (execute):** Perform agreed **file moves** and **config edits** only after the user approves the plan—do not move tests silently. Before closing out import work, confirm **all** SmartTests specs include the runtime import.

---

## Related references

- [`init-testchimp.md`](./init-testchimp.md) — phased init, Key Areas 1–2 & 6.
- [`write-smarttests.md`](./write-smarttests.md) — layout and authoring.
- [`truecoverage.md`](./truecoverage.md) — RUM / TrueCoverage (app-side).
- [`assets/template_playwright.config.js`](../assets/template_playwright.config.js) — canonical Playwright projects layout for SmartTests.

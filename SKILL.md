---
name: testchimp
description: Integrate repositories with TestChimp for QA orchestration — SmartTests (Playwright on web; Mobilewright on native mobile), markdown test plans (read/author via MCP or CLI), coverage, TrueCoverage (RUM on web and native mobile), ExploreChimp UX analytics on UI test pathways, and TestChimp tools (`@testchimp/cli`). Use when the user mentions TestChimp, /testchimp commands (init, test, plan, evolve, explore), SmartTests, agent-driven test or plan authoring, ExploreChimp, or updating this skill from Git.
compatibility: Requires Node.js; web projects need @playwright/test and playwright >= 1.59.0 (see Preamble checks #6). Mobile projects need mobilewright + @mobilewright/test (see references/mobilewright-smarttests.md). TrueCoverage RUM clients: **#7** (`@testchimp/rum-js`, SwiftPM **testchimp-rum-ios**, JitPack **testchimp-rum-android**). **`TESTCHIMP_API_KEY`:** Preamble checks **#4** (runner process, not only MCP/IDE). Network access for TestChimp APIs when using MCP, CLI, or AI steps.
version: 0.3.11
required_cli_version: "0.1.15"
---

# TestChimp

TestChimp is a **QA workflow orchestration layer for AI agents**. It provides:

- **Setup QA infra** - sets up opinionated, enterprise-grade QA infra including CI setup, test-only seed / teardown / read endpoints, mocking strategy (Playwright **`page.route`** for HTTP/API; optional **AIMock** for LLM), TrueCoverage instrumentation, per-PR environment provisioning. **Fixtures** (barrels per scaffold — [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md)) are introduced during **`/testchimp test`** as needed—see [`references/fixture-usage.md`](references/fixture-usage.md).
- **Requirement traceability** via structured comments in tests (e.g. `// @Scenario: #TS-101 Title`) linking SmartTests to scenarios. One test may include **multiple** `// @Scenario:` lines when it covers several scenarios; the first must be the first statement in the test body—see [`references/write-smarttests.md`](references/write-smarttests.md).
- **Markdown test plans** in a mapped `plans/` folder (YAML frontmatter, `stories/` / `scenarios/` / `knowledge/`) — how to read and author them in [`references/test-planning.md`](references/test-planning.md).
- **Intelligent Playwright steps** (`ai.act` / `ai.verify` / `ai.extract` with `ai-wright`) on **web** for more stable execution-time intelligent behavior — **not available for native mobile** (Mobilewright) yet; see [`references/mobilewright-smarttests.md`](references/mobilewright-smarttests.md).
- **Execution reporting** via `@testchimp/playwright` (≥ **0.2.0** for per-run **device context**: web/ios/android platform, device family, OS, resolution, orientation) so runs feed TestChimp for **per-platform requirement coverage** and **scenario execution history** (CLI/MCP: optional `platform` on coverage; `scenarioId` + dimension filters on execution history — [`references/cli.md`](references/cli.md)).
- **Fixtures + seed/read APIs** - Fixture barrels (`fixtures/`, `api/fixtures/`, `mobile/fixtures/`, `web/fixtures/`) and **`shared/`** seed helpers call **seed**, **teardown**, and **read** endpoints per [`references/seeding-endpoints.md`](references/seeding-endpoints.md). Layout: [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md). Patterns: [`references/fixture-usage.md`](references/fixture-usage.md).
- **TrueCoverage** - feedback loop for test coverage aligned with real user behaviour insights from production: **`@testchimp/rum-js`** on web; **TestChimpRum** (Swift / Kotlin) on **iOS** and **Android**, with `@testchimp/playwright` attaching test identity via **`installTestChimp`** (web: `page`; mobile: `uiFixture: 'screen'` + Mobilewright **`projects[].use.platform`**), and (on mobile) **`device`-fixture** automation URLs + in-app URL forwarding. See [`references/truecoverage.md`](references/truecoverage.md). **Default: opted-in** unless `plans/knowledge/ai-test-instructions.md` **explicitly** records a TrueCoverage opt-out under `### TrueCoverage Plan`.
- **ExploreChimp (UX analytics on UI journeys)** — With **`EXPLORECHIMP_ENABLED`** and the **`markScreenState`** fixture, runs send DOM, screenshot, console, network, and metrics checkpoints to TestChimp so agents can surface **UX issues** (performance, layout, visual, usability, accessibility, and related signals) **along the same pathways as SmartTests**. Pure API-only automation is out of scope. For **local / agent-driven** runs (no CI branch env), set **`TESTCHIMP_BRANCH_NAME`** to the current git branch so the reporter sends **`branchName`** and the server can resolve **`branch_id`** on explorations and bugs. Workflow: [`references/exploratory_runs.md`](references/exploratory_runs.md); command alias **`/testchimp explore`**. In **`/testchimp test`**, **Phase 5: Smart regression** runs after **Phase 4: Validate** (likely affected scenarios from `plans/`, linked specs via `// @Scenario:`). **Phase 6: ExploreChimp** is **default-on** when the PR/plan scope includes **new or materially changed UI SmartTests** (real UI; **`markScreenState`** in use or planned once stable—especially new screen-states). The branch plan records **`yes`** or documented **`N/A`** (same user approval window as the rest of the plan); **`N/A`** is the **exception** (e.g. API-only change, no UI journey, user declined cost)—see [`references/testing-process.md`](references/testing-process.md). In **`/testchimp evolve`**, ExploreChimp stays **plan-gated** on **TrueCoverage-prioritized** UI slices ([`references/evolve-coverage.md`](references/evolve-coverage.md)).

## Preamble (run first)

Run this once at the start of any TestChimp flow. It will:
- Flag if your **installed skill is outdated** (git-based; canonical)
- Probe nearby MCP config for `TESTCHIMP_API_KEY` (without printing it) — **does not** prove the Playwright/Mobilewright **child** has the key; see **Preamble checks #4**

```bash
_TC_PRE=$(
  ~/.cursor/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || ~/.claude/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || .cursor/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || .claude/skills/testchimp/bin/testchimp-preamble-check 2>/dev/null \
  || true
)
[ -n "$_TC_PRE" ] && echo "$_TC_PRE" || true
```

If the preamble script cannot be run (or prints nothing), the agent MUST manually validate **Preamble checks** items **1** (skill version) and **4** (`TESTCHIMP_API_KEY` / runner — full rules there).

## Preamble checks (run first)

Before executing a TestChimp flow:

1. **Skill update check** — rely on the `version` in this file's frontmatter. Read the current version from the local `SKILL.md`, then fetch the remote `SKILL.md` from the published repo (`https://github.com/testchimphq/testchimp-skills`, see **Updating this skill from Git** below) and compare frontmatter versions. If the remote version is newer, tell the user an update is available and ask whether to update now (`/testchimp update`). If the user agrees to update the version, proceed with the update - as noted in the below section.

2. **Decision memory check (project scope only)** — locate `/plans/knowledge/ai-test-instructions.md`. If it is missing or empty, tell the user that **project-level** init decisions are not yet persisted and recommend running `/testchimp init` to capture them (usually **once per repo**, then maintained as the team changes strategy). If it exists and is substantively populated, treat it as the source of truth for **project** decisions (environment strategy, TrueCoverage choices, Mocking Plan when present, and **`## ExploreChimp`** when present). **TrueCoverage default:** unless that file **explicitly** states that TrueCoverage is **opted out** (under `### TrueCoverage Plan` or an equally clear project-level statement), treat TrueCoverage as **opted in**—plan instrumentation, RUM wiring, and `plans/events/` work accordingly; do not skip TrueCoverage merely because the section is empty or says “deferred.” **Do not** infer **workstation** readiness from this file: each developer still needs local MCP registration and a canonical key in MCP `env` — with **#4** satisfied before any Playwright/Mobilewright run (see **`/testchimp init`** → [Workstation gate](references/init-testchimp.md#workstation-gate-always-first) in [`references/init-testchimp.md`](references/init-testchimp.md)).

3. **MCP-first access to TestChimp (BLOCKING)** — without TestChimp API access, the agent cannot fetch coverage, execution history, environments, or create/update stories/scenarios.
   - **Preference order (critical)**:
     1) **Use MCP tools first** (preferred): the MCP server process has the key in its `env` block.
     2) If MCP is unresponsive (agent bridge issues, tool timeouts), **fallback to CLI** only after **#4** (same key in the **shell** that runs `testchimp …`).
   - **Never print secrets**: do not paste the key into chat, logs, or echoed commands.
   - **Playwright / Mobilewright / CI:** MCP `env` alone is **not** enough for the test **runner** — still apply **#4** before spawning the runner.

4. **`TESTCHIMP_API_KEY` (P0 — single rule for MCP, CLI, and runners)** — Any process that runs **Playwright** or **Mobilewright** with **`@testchimp/playwright`**, or **`testchimp`** CLI against the project APIs, must have **`TESTCHIMP_API_KEY`** in **that process’s** environment. **IDE-only or MCP-only** config does **not** satisfy the **child** test runner. If you **cannot verify** the key is set on the process **before** spawn, **halt** — do not run tests “to see what happens.”
   - **Resolve (never print secrets):** SmartTests root ( **`.testchimp-tests`** ) → walk **up** to **project-level** host MCP config (e.g. **`.cursor/mcp.json`** for Cursor, **`.mcp.json`** at repo root for Claude Code) → read **`mcpServers.testchimp.env.TESTCHIMP_API_KEY`** → **export** or **inject** into the agent shell, CI job `env`, or compose `env:` for the service that runs `npx playwright test` / `npx mobilewright …`. For TrueCoverage RUM **`projectId`**, read **`env.TESTCHIMP_PROJECT_ID`** from the same entry when app build config does not already define it ([`references/truecoverage.md`](references/truecoverage.md)).
   - **Missing / blank / placeholder:** **STOP**; during **`/testchimp init`**, create or merge the project MCP file from [`assets/sample-mcp.json`](assets/sample-mcp.json) (see [Workstation gate](references/init-testchimp.md#workstation-gate-always-first)), ask the user to paste API key + project ID, reload MCP, then re-export for the **runner**.
   - **Symptoms (same fix):** reporter **disabled**, **401**, missing-key logs → re-apply **#4** on the **runner** env, then re-run.
   - **Never print the key.** **No key-rotation noise** unless leaked or committed.
   - **Not in** **`.env-QA`** / **`.env-*`** (those are for `BASE_URL`, fixtures, etc.); canonical copy in MCP **`env`** per [`assets/sample-mcp.json`](assets/sample-mcp.json).

5. **TestChimp CLI / MCP client compatibility check** — read **`required_cli_version`** from this file's frontmatter (semver). Run **`npm view @testchimp/cli version`** and treat the result as **registry latest**. Find the project's MCP server config (host-specific path; see **#4** walk-up) and locate the server entry whose **`args`** include **`@testchimp/cli`** (often the server name **`testchimp`**), typically **`["-y", "@testchimp/cli@latest", "mcp"]`**.
   - If **`args`** use **`@testchimp/cli@latest`** or **`@testchimp/cli`** with **no** `@` version suffix, treat the **effective** runtime version as **registry latest** (because **`npx -y`** will resolve **`@latest`** on each run).
   - If **`args`** use an explicit **`@testchimp/cli@x.y.z`**, parse **x.y.z** as the configured version.
   - **Pass** if the effective configured version is **>=** **`required_cli_version`** (semver). **Pass** if registry latest is **>=** **`required_cli_version`** when using **`@latest`** or an unpinned package name.
   - **Corrective action** when the pinned semver or registry latest is **below** **`required_cli_version`:** Update **`args`** to **`["-y", "@testchimp/cli@latest", "mcp"]`** (see [`assets/sample-mcp.json`](assets/sample-mcp.json)), **or** pin to at least **`required_cli_version`**. Preserve **`env.TESTCHIMP_API_KEY`**. Tell the user to **reload MCP / restart the IDE** so the new command line applies.
   - If no project MCP config is present yet, **during `/testchimp init`** create or merge it from [`assets/sample-mcp.json`](assets/sample-mcp.json) (other flows: point the user to init or the Workstation gate).

6. **Playwright / Mobilewright toolchain check** — **Web:** TestChimp requires Playwright 1.59.0+. **Before** authoring SmartTests, running **`npx playwright test`**, or doing browser-driven exploration for **`/testchimp init`** smoke, ensure the repo has a compliant install (**#4** before any such run):
   - Resolve the **install root**: from the **SmartTests root** (see **[Marker files](#marker-files)**), walk up until you find the **`package.json`** that declares **`@playwright/test`** (often a parent such as `ui/` in a monorepo). That directory is where **`npm install`** / **`npm ci`** must succeed for Playwright to be runnable.
   - If **`node_modules`** is missing or **`npx playwright --version`** fails, **run the repo’s install** (`npm install`, `npm ci`, or documented workspace install) **at that install root** first. **Do not** treat missing **`node_modules`** as “optional”; without install, Playwright-based steps cannot be validated.
   - **Verify** the resolved **`@playwright/test`** version is **>=** 1.59.0, and that **`playwright`** (browser package) matches **`@playwright/test`** (same line as [`references/write-smarttests.md`](references/write-smarttests.md)). Use e.g. `npm ls @playwright/test --prefix <install-root>` or `npx playwright --version` with **cwd** at the install root.
   - **Corrective action** if below minimum or version mismatch: bump **`@playwright/test`** and **`playwright`** together, reinstall, then **`npx playwright install`** for browsers if needed. If the environment cannot run install commands, **tell the user** to install dependencies and re-run; **do not** silently author tests that were never executed against a real runner.
   - **Mobile / multi-platform** (**`project_type=mobile|multi-platform`** in **`.testchimp-tests`**; legacy **`ios`/`android`** → mobile): ensure **`mobilewright`** and **`@mobilewright/test`** are installed and **same version**; run **`npx mobilewright doctor`** when setup is unclear ([`references/mobilewright-smarttests.md`](references/mobilewright-smarttests.md), [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md)).

7. **RUM client libraries (TrueCoverage) — latest vs installed (required when RUM is in scope)** — Whenever TrueCoverage is **in scope** (see **#2**) or the task adds, upgrades, or validates RUM / session instrumentation, the agent MUST look up the **latest published** RUM library for the **relevant platform** and confirm the project has a **correct, up-to-date install**. **Do not** assume an existing dependency pin is current without checking the registry or upstream tags.
   - **Latest sources (prefer network once per flow):**
     - **Web:** `npm view @testchimp/rum-js version` → **npm** latest for **`@testchimp/rum-js`**.
     - **iOS:** Newest **SemVer tag** on **`https://github.com/testchimphq/testchimp-rum-ios`** (e.g. GitHub **Tags** / **`git ls-remote --tags`** on that repo). SwiftPM consumers use **`.package(url:…, from: "x.y.z")`** or an equivalent Xcode rule — compare to that tag.
     - **Android:** Newest **SemVer tag** on **`https://github.com/testchimphq/testchimp-rum-android`**; JitPack artifact **`com.github.testchimphq:testchimp-rum-android:<tag>`** — compare to **`build.gradle(.kts)`** / version catalog.
   - **Verify in repo:** Locate the real consumer manifest (**`package.json`** / lockfile for web; **`Package.swift`** or Xcode SPM for iOS; Gradle for Android). Confirm the declared version is **present**, **resolved**, and **≥ latest** (semver). If the project **intentionally** stays below latest, add a **one-line justification** to the branch plan or **`plans/knowledge/ai-test-instructions.md`** FAQ; default is to **bump to latest** and reinstall.
   - **Corrective action:** Update the dependency, then **`npm install`** / **`npm ci`** (web), **File → Packages → Resolve** or CLI resolve (iOS), **Gradle sync** (Android). Re-validate **`init` / `initialize`** and automation URL wiring per [`references/truecoverage.md`](references/truecoverage.md).
   - If npm/GitHub is **unreachable**, state that explicitly, use the lockfile or last-known tag as fallback, and **tell the user** to confirm against npm / tags when online.
   - **Omit** this check only when **#2** records an explicit TrueCoverage **opt-out** and the task does not touch application RUM code.

8. **Headed authoring default (interactive)** — when the agent is **authoring** or **debugging** SmartTests for `/testchimp test`, default to **headed** runs so the user can watch and optionally intervene:
   - Prefer `npx playwright test --headed --debug` during authoring/debug sessions.
   - Use headless runs once the test is stable (or when the user explicitly asks for headless/CI mode).

## How TestChimp works

1. Create a project in TestChimp and connect the Git repo. Map 2 folders in the repo to the project created in TestChimp platform **`tests`** (SmartTests) and **`plans`** (test plans). Those can be mapped after logging in to TestChimp -> Select Project -> Project Settings -> Integrations -> GitHub.
2. Run SmartTests with **Playwright** (web) or **Mobilewright** (native mobile — **`project_type`** in **`.testchimp-tests`**); install **`@testchimp/playwright`** as documented in [`references/write-smarttests.md`](references/write-smarttests.md). On **web**, dependencies typically include **`ai-wright`** for intelligent steps; **mobile** does not use ai-wright yet ([`references/mobilewright-smarttests.md`](references/mobilewright-smarttests.md)).
3. Local and CI calls use the project’s **`TESTCHIMP_API_KEY`** — scope per project; placement and runner rules: **Preamble checks #4**.

### Marker files

TestChimp adds **marker files** after mapping: **`.testchimp-tests`** at the **SmartTests root** (platform **tests**) and **`.testchimp-plans`** at the **plans root** (platform **plans**). On-disk folder names may differ (e.g. `ui_tests`, `plans`).

**`project_type`:** **`.testchimp-tests`** → **`web`**, **`mobile`**, or **`multi-platform`** (canonical layouts in [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md)). **Empty or omitted** → **web**. Legacy **`ios`/`android`** → treat as **`mobile`**. **Run platform** for `@testchimp/playwright` comes from Mobilewright **`projects[].use.platform`** (`ios`/`android`); omit for web/API. Use **`installTestChimp(base, { uiFixture: 'screen' })`** in **`mobile/fixtures/index.js`**; **`api/fixtures`** and **`web/fixtures`** use default **`page`**.

**Finding them:** Markers are **dotfiles**; workspace Glob may omit them, so **an empty Glob search does not prove they are missing**. From the repo (or workspace) root, use the terminal—e.g. **`find . -name '.testchimp-*'`**, or **`ls -a`** in a candidate folder next to `package.json` or `plans/`.

**Using SmartTests root:** The directory that contains **`.testchimp-tests`** is the SmartTests root—use it for the API key walk-up (**Preamble #4**), Playwright install resolution (**#6**), and every **`npx playwright …`** run (Agent guardrails).

**If markers are missing after mapping:** Confirm **sync PRs from the TestChimp platform were raised and merged for each mapped folder** and the **local workspace was updated** (e.g. `git pull`)—see [`references/init-testchimp.md`](references/init-testchimp.md) (Key Area 1 and Action item A).

## Agent guardrails (must follow)

1. **Scenario and story IDs — platform-provisioned only (BLOCKING).**
   - **Never invent / assume fake IDs**: Do **not** guess or fabricate **`#TS-…`** / **`US-…`** ids, and do **not** write `// @Scenario: #TS-…` comments before those entities exist in TestChimp.
   - **Never write id-less plan markdown (critical failure mode):** Do **not** `Write` / create new files under **`plans/stories/`** or **`plans/scenarios/`** (any mapped plans root) that omit **`id: US-<n>`** / **`id: TS-<n>`**, or that leave **`id:`** blank. Omitting the field is **not** a workaround for “don’t invent ids” — it produces broken artifacts that Git sync cannot import.
   - **Required create → write → update sequence (every new story/scenario):**
     1. MCP/CLI **`create-user-story`** / **`create-test-scenario`** (platform allocates **`ordinalId`** and returns stub **`content`** with **`id:`** already set).
     2. **Write** the returned **`content`** to the repo path (edit body only; keep **`id:`** / scenario **`story:`**).
     3. MCP/CLI **`update-user-story`** / **`update-test-scenario`** with the **full** markdown. Updates **fail** if `id:` (or scenario `story:`) is missing — use that error to fix before finishing.
   - **Forbidden:** Hand-authoring story/scenario `.md` files first and “adding ids later”; copying a sibling file’s frontmatter without a create call; using only **`story: US-…`** on a new scenario without a platform-issued **`id: TS-…`**.
   - **Correct behavior when coverage is missing**: If the PR introduces behavior and there are **no relevant stories/scenarios**, **plan** their creation (via MCP/CLI) so the platform generates **real IDs**, then follow the sequence above.
   - **Timing rule**: Call **`create-user-story`** / **`create-test-scenario`** (and subsequent updates) **only in Execute**, **after** the user has explicitly approved the Plan. The Plan lists what will be created/updated but must not mutate the platform pre-approval.
   - **After IDs exist**: Add SmartTest link comments using the **actual** platform ids (or ids already present in committed plan markdown). Full rules: [`references/test-planning.md`](references/test-planning.md).
   - **Self-check before finishing any plan-authoring turn:** Every new/changed story/scenario file under the plans root must have a non-empty **`id:`** matching a platform ordinal from create/get in **this** session (or an id already on disk from a prior sync). If any file fails, **stop and fix** — do not commit or hand off.

2. **Run Playwright only from the mapped SmartTests root** (see **[Marker files](#marker-files)**). **`cd` there**, then run Playwright via **`npx`** (e.g. `npx playwright test …`). Do not run tests from the repo root unless that root **is** the mapped folder.

3. **API keys and 401s.** **`TESTCHIMP_API_KEY`:** canonical **`mcp.json`** / MCP **`env`** plus **runner export** — full rules in **Preamble checks #4** (includes **401**, reporter disabled, missing-key logs). Obtain keys: **TestChimp** → **Project Settings** → **Key management**. **Do not** document **PAT**s or alternate user-auth env pairs for agents.

4. **Gitignore generated report folders.** Playwright / Mobilewright (and reporters) can create generated artifacts (HTML reports, traces, screenshots, videos, raw results). These must **not** be committed. Ensure the repo’s **`.gitignore`** includes common Playwright output folders such as:
   - `playwright-report/`
   - `mobilewright-report/`
   - `test-results/`
   - `blob-report/`
   - any other repo-specific generated report/output directory configured by the test runner or CI

5. **Persist infra learnings (required).**
   - Project runbooks live in **`plans/knowledge/ai-test-instructions.md`**. Maintain **`## Past learnings — authoring & validation (FAQ)`** (FAQ-style **`### Q:`** / **`**A:**`** entries) for recurring provisioning, health-check, URL/`BASE_URL`, auth, compose, EaaS, volume, and seed-order issues—see **[Binding: ai-test-instructions](references/testing-process.md#binding-ai-test-instructions-environment-and-faq-playbook)** in [`references/testing-process.md`](references/testing-process.md).
   - **ExploreChimp decisions** (network URL regex when **`NETWORK`** is a source, default source list overrides, exploration scope habits, resolved blockers) belong under **`## ExploreChimp`** in the same file—see [`references/exploratory_runs.md`](references/exploratory_runs.md). **Re-read** that section before each exploration batch.
   - **Before improvising** when a blocker appears during test authoring, execution, or validation: **re-read** that file (Environment Provision Strategy **and** the FAQ). If you resolve something **not** already documented, **append** a new Q/A in the same run.
   - Broader infra notes (not FAQ-shaped) may still go elsewhere in `ai-test-instructions.md`, but anything another agent would hit again belongs in the FAQ.

6. **SmartTests fixtures-first (correct barrel per scaffold).** Read **`.testchimp-tests`** and [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md) before authoring. Every **`*.spec.*`** imports **`{ test, expect }`** from the matching barrel (`fixtures/`, `api/fixtures/`, `mobile/fixtures/`, `web/fixtures/`) — never from `@playwright/test` or `@mobilewright/test` directly. Each barrel’s **`index.js`** applies **`installTestChimp`** (≥ **0.1.8**); **`mobile/fixtures`** uses **`{ uiFixture: 'screen' }`**. **Web UI:** **`page`** + **`markScreenState`**. **Mobile UI:** **`screen`** / **`device`** — [`references/mobilewright-smarttests.md`](references/mobilewright-smarttests.md). Cross-platform seed helpers go in **`shared/`**, not specs. See [`references/fixture-usage.md`](references/fixture-usage.md). **Atlas:** `testchimp list-screen-states` / `upsert-screen-states` — [`references/cli.md`](references/cli.md), [`references/write-smarttests.md`](references/write-smarttests.md) §7.

7. **TrueCoverage RUM `environment` tag (web + native).** RUM SDKs take **`environment`** in **`init` / `initialize`**; they **do not** read **`TESTCHIMP_ENV`** from the test runner process. Planning native (or web) TrueCoverage **must** include **how** the app maps **`environment`** (build config, plist, `BuildConfig`, bootstrap helper) so it **aligns** with **`list-rum-environments`** and execution scopes—or a **deliberate** mismatch documented with scope implications. Do **not** treat **project id + API key + deep link / `installTestChimp`** as complete without this. See [`references/truecoverage.md`](references/truecoverage.md) § **RUM environment tag**.

8. **Platform scope on PR branches (mobile & multi-platform).** When **`project_type`** is **`mobile`** or **`multi-platform`**, **`/testchimp test`** and **`/testchimp explore`** must resolve which of **`web`**, **`ios`**, and **`android`** are in scope for the branch. **Deduce** from PR diff and touched specs when evidence is strong; **always inform** the user of the chosen platform(s) and rationale. **Ask** which platform(s) to test when deduction is ambiguous—do not default to all platforms silently. Persist **`## Platform scope (this run)`** on the branch plan and require user confirmation before Execute. Full rules: [`references/platform-scope.md`](references/platform-scope.md).

## MCP client and CLI (agents)

Install **`@testchimp/cli@latest`** (see [`references/init-testchimp.md`](references/init-testchimp.md)) and register the MCP server using **`npx`** with **`@testchimp/cli@latest`** and the **`mcp`** subcommand in **`args`**.

**CLI (shell / CI):** Same package exposes the **`testchimp`** binary for calling the same HTTP APIs with flags or **`--json-input`**. See [`references/cli.md`](references/cli.md) for env resolution, stdout/stderr, and when to prefer CLI vs MCP.

**Reference config:** [`assets/sample-mcp.json`](assets/sample-mcp.json) — shows **`command`**, **`args`** (`-y` + **`@testchimp/cli@latest`** + **`mcp`**), and **`env`** with **`TESTCHIMP_API_KEY`** and **`TESTCHIMP_PROJECT_ID`** placeholders. **`/testchimp init`** must **write** this blob into the **project-level** MCP file (create or merge) when missing. Replace placeholders with values from **TestChimp → Project Settings → Key management**; **do not commit** real secrets.

**Minimum versions:** This skill declares **`required_cli_version`** in frontmatter. Agents must run **Preamble checks #5** (CLI) and **#6** (Playwright/Mobilewright toolchain). When TrueCoverage or application RUM code is in scope, also run **#7** (latest **`@testchimp/rum-js`** / iOS tags / Android JitPack tag vs project install).

**MCP `env`:** `TESTCHIMP_API_KEY` (required for MCP + runner export per **#4**); `TESTCHIMP_PROJECT_ID` (optional for MCP calls; **required** for TrueCoverage RUM `projectId` when not elsewhere in app config — agents read it during instrumentation per [`references/truecoverage.md`](references/truecoverage.md)). **401** or missing-key symptoms → **#4**.

The MCP server exposes tools grouped by area:

- **Coverage & execution** — `get-requirement-coverage`, `get-execution-history`, `mark-plan-items-implementation-done`
- **Screen-state atlas (SmartTests / traces / ExploreChimp)** — `list-screen-states`, `upsert-screen-states` (same as **`testchimp list-screen-states`** / **`testchimp upsert-screen-states`** in [`references/cli.md`](references/cli.md))
- **Semantic duplicate hygiene (`/testchimp cleanup`)** — `list-semantic-similar-tests`, `mark-semantic-tests-distinct` (TestLocator-based; see [`references/cleanup.md`](references/cleanup.md))
- **Execution debugging** — `fetch-execution-report`, `get-manual-session-details`
- **Planning (user stories & scenarios)** — `get-user-stories`, `get-test-scenarios`, `create-user-story`, `create-test-scenario`, `update-user-story`, `update-test-scenario`
- **Environments & EaaS** — `get-eaas-config`, `get-branch-specific-endpoint-config`, `provision-ephemeral-environment-and-wait`, `provision-ephemeral-environment`, `get-ephemeral-environment-status`, `destroy-ephemeral-environment`
- **Ephemeral deploy diagnostics (BunnyShell)** — `list-bunnyshell-environment-events`, `list-bunnyshell-workflow-jobs`, `get-bunnyshell-workflow-job-logs`
- **TrueCoverage analytics** — `list-rum-environments`, `get-truecoverage-events`, `get-truecoverage-event-details`, `get-truecoverage-child-event-tree`, `get-truecoverage-event-transition`, `get-truecoverage-event-time-series`, `get-truecoverage-session-metadata-keys`, `get-truecoverage-event-metadata-keys` — set **`platform`** on each **`ExecutionScope`** in `--json-input` (see [`references/cli.md`](references/cli.md) § TrueCoverage)

Use the repo, plans, and those tools to decide what to test and how to run them.

## Command routing

| User says | Read |
|-----------|------|
| `/testchimp init` | [`references/init-testchimp.md`](references/init-testchimp.md) — opening message → phased workflow (requirement gather → plan → execute). **Between phases:** complete each **phase completion gate** in the reference; every line **done** or **`N/A`** + one-line justification (persist in `plans/knowledge/ai-test-instructions.md` where noted). |
| `/testchimp test` | [`references/testing-process.md`](references/testing-process.md) — **Preamble #4**; read **[`project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md)** during Plan/Execute; **`ai-test-instructions.md`** first; **Analyze → Plan → Execute → Validate → Phase 5 → Phase 6 → Phase 7** (full chain or documented **`N/A`**). **Mobile / multi-platform:** [`references/platform-scope.md`](references/platform-scope.md) — inform or ask for platform scope on PR branches. |
| `/testchimp explore` | [`references/exploratory_runs.md`](references/exploratory_runs.md) — Run **ExploreChimp** on chosen UI SmartTests (`EXPLORECHIMP_ENABLED`, `markScreenState`, batch id, data sources / network regex). Use when exploration is the **primary** task or the user specifies scope; align with **`/testchimp test`** when part of full PR QA. Prompts like **`/testchimp run explorechimp targeting release '<name>'`** are the same playbook with [release targeting](references/exploratory_runs.md#targeting-a-release-release-checks) (`get-release` + `TESTCHIMP_RELEASE`). **Mobile / multi-platform:** same platform-scope inform/ask rules — [`references/platform-scope.md`](references/platform-scope.md). |
| `/testchimp run security scan for <scan_id>` | [`references/security_scans.md`](references/security_scans.md) — Release Checks: load nested scan config (`dastCheckConfig` / `sastCheckConfig` / `depsCheckConfig` / `leaksCheckConfig`), branch to [`security/dast.md`](references/security/dast.md), [`security/sast.md`](references/security/sast.md), [`security/deps.md`](references/security/deps.md), or [`security/secrets.md`](references/security/secrets.md); `report-*-findings`; playbook sets `COMPLETED`. |
| `/testchimp fix` | [`references/fix-failing-tests.md`](references/fix-failing-tests.md) — Fetch execution report by `batch_invocation_id` (for multiple tests run in a single batch job) or `job_id` (for an individual test run), troubleshoot, apply fixes, and re-run failing tests per `plans/knowledge/ai-test-instructions.md`. |
| `/testchimp author test for manual session` (or pasted **Copy script generate prompt** from manual session viewer) | [`references/author-test-from-manual-session.md`](references/author-test-from-manual-session.md) — Fetch manual session + linked scenarios; authoring-only SmartTest workflow using session steps/screenshots as reference. |
| `/testchimp plan` | [`references/test-planning.md`](references/test-planning.md) |
| `/testchimp evolve` | [`references/evolve-coverage.md`](references/evolve-coverage.md) — Analyze → Plan → Execute; same **done / `N/A` + justify** gating. Includes optional **ExploreChimp** on **TrueCoverage-prioritized** UI journeys (drop-offs, duration/demand hotspots); load [`references/exploratory_runs.md`](references/exploratory_runs.md) when running those explorations. |
| `/testchimp cleanup` | [`references/cleanup.md`](references/cleanup.md) — Analyze → Plan → Execute for semantically similar / duplicate SmartTests; mark distinct pairs; optional deletions (max 10/run, explicit approval). **Not** part of evolve. |
| `/testchimp setup truecoverage` / setup-truecoverage | [`references/truecoverage.md`](references/truecoverage.md) |
| `/testchimp instrument` | [`references/truecoverage.md`](references/truecoverage.md) |
| `/testchimp update` | [Read below for updating the skill] |

### `/testchimp init` — opening message (deliver first)

When the user runs **`/testchimp init`**, the **first substantive message to the user** must set expectations: what init delivers, what they do after init, what the agent does during ongoing QA, and how **`/testchimp evolve`** fits in. **Then** continue with Preamble checks, the [Workstation gate](references/init-testchimp.md#workstation-gate-always-first), and the rest of [`references/init-testchimp.md`](references/init-testchimp.md).

**Include the following substance** (adapt wording slightly for tone; keep meaning):

- **During init**, TestChimp sets up **complete QA infrastructure** for the project: seeding endpoints, test environment management, CI setup, fixtures maintainance, mocks, TrueCoverage instrumentation (for coverage gaps aligned with real user behaviours in production), and test scaffolds with proper TestChimp integration.
- **After init**, the user mainly runs **`/testchimp test`** when they finish a PR and want it tested.
- **Ongoing**, the agent runs the full QA workflow (say in first person when addressing the user: *I will run the complete QA workflow* — author tests for relevant scenarios, author missing test plans for the PR, adjust QA infrastructure as needed - adding seed endpoints, TrueCoverage instrumentations, fixture updates, find coverage gaps and address them).
- **Periodically**, run **`/testchimp evolve`** "I will" (similar to above say in first-person) analyze requirement coverage gaps and TrueCoverage insights—by communicating with the TestChimp platform—and address them systematically: tests and infra to cover under-tested slices, and when planned, **ExploreChimp** runs on **TrueCoverage-prioritized** UI journeys (drop-offs, duration/demand hotspots) to surface UX issues in those critical areas ([`references/evolve-coverage.md`](references/evolve-coverage.md)).

**Always** share this doc link for a short overview of what TestChimp enables: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

(Full step order is in [`references/init-testchimp.md`](references/init-testchimp.md#opening-message-required-first-user-facing-step).)

If the user asks semantically similar requests ("Setup TestChimp", "Write Tests for the PR", "Analyze requirement coverage", "clean up duplicate tests", "dedupe test suite" etc.) — open the matching reference file above. Legacy **`/testchimp audit`** is the same flow as **`/testchimp evolve`** ([`references/evolve-coverage.md`](references/evolve-coverage.md)).

TrueCoverage planning source of truth:

- **Opt-in policy:** TrueCoverage is **in scope by default**. Only skip or omit RUM / reporter / event-doc work when `plans/knowledge/ai-test-instructions.md` **explicitly** records an **opt-out** (see [`references/truecoverage.md`](references/truecoverage.md)). Absence of a TrueCoverage section, “deferred,” or incomplete init does **not** imply opt-out.
- `plans/knowledge/truecoverage-instrument-progress.md` tracks **planned vs done** TrueCoverage instrumentation. Agents should consult it during `/testchimp init`, `/testchimp instrument`, and `/testchimp evolve`.
- **Do not mis-diagnose under-coverage:** when SmartTests are wired through `fixtures/index.js` with `installTestChimp()` (default scaffold), test-identity linking for emits is already handled by `@testchimp/playwright/runtime`. Under-covered events usually mean tests are not traversing those business paths/slices yet; fix with scenario-driven test authoring (and scenario creation when missing), not synthetic "event tick" tests.

## Updating this skill from Git

This skill is published at **`https://github.com/testchimphq/testchimp-skills`** (branch **`main`**). Prefer installing with **`git clone … <skills-parent>/testchimp`** so **`.git`** remains and updates are trivial.

1. Find **`SKILL_DIR`**: the directory containing this **`SKILL.md`** and (when git-installed) **`.git`**. Typical paths include `~/.claude/skills/testchimp`, `~/.cursor/skills/testchimp`, `~/.kiro/skills/testchimp`, `~/.agents/skills/testchimp`, or the same names under **`.claude/skills`**, **`.cursor/skills`**, **`.kiro/skills`**, **`.agents/skills`**, **`.github/skills`** inside a project.
2. If **`.git`** exists in **`SKILL_DIR`**:

   ```bash
   git -C "$SKILL_DIR" pull origin main
   ```

   (or `git fetch origin && git merge origin/main`).

3. If **`.git`** is missing, reinstall with **`git clone`** per **[README.md](README.md)** (or the copy-only fallback there).
4. Tell the user to **restart** the IDE or agent host if the skill does not reload automatically.

## Coverage scope note

`get-requirement-coverage` supports platform-rooted paths under both **`tests/...`** and **`plans/...`**.
When a `plans/...` folder is provided, coverage resolves SmartTests linked to scenarios in that plan scope.
`scope.folderPath` should be provided using **platform paths** (rooted at `tests` or `plans`), even when the mapped repo folders use different names (for example, if mapped repo folder for `tests` in the repo is `ui_tests` then to ask for coverage for `ui_tests/checkout`, the scope you request should be for `tests/checkout`).

**Branch scope:** Omit **`branchName`** in Analyze (and most gap-finding) so coverage aggregates across branch copies. Responses expose **`scenarioOrdinalId`** / **`userStoryOrdinalId`** (ordinals only in MCP/CLI contracts—not platform UUIDs). Plan markdown does **not** store implementation **`status`**; after Validate, use **`mark-plan-items-implementation-done`** with ordinal ids to set lifecycle **`done`** in the DB.

**Manual + automated coverage (unified):** `get-requirement-coverage` can return coverage computed from **automated SmartTests**, **manual sessions**, or **both**.
- Default behavior (omit `recordTypes`): automated **SmartTests only**.
- To include manual sessions too: pass `recordTypes: ["SMART_TEST","MANUAL"]` (MCP JSON), or CLI convenience `testchimp get-requirement-coverage --include-manual ...`.
- Manual-only: `recordTypes: ["MANUAL"]` (MCP JSON), or CLI `--manual-only`.

**Per-platform coverage (CLI/MCP ≥ `0.1.6`, reporter ≥ `0.2.0`):** Omit **`platform`** on **`get-requirement-coverage`** to get rollup shaped by project scaffold — **one** record for **web** projects; up to **two** (iOS + Android) for **mobile**; up to **three** for **multi-platform**, with explicit **`NOT_ATTEMPTED`** rows when a platform had no run in scope. Pass **`platform`**: `web` | `ios` | `android` to narrow to a single platform. Use **`get-execution-history`** with **`scenarioId`** (platform scenario UUID from plan entities, not `TS-<n>`) for scenario-linked runs; optional **`platform`** or **`dimensionFilters`** for device drill-down — see [`references/cli.md`](references/cli.md) § Platform execution reporting.

## Progressive disclosure

When TrueCoverage or **native/web RUM SDK** wiring is in scope, agents must run **Preamble checks #7** (query latest published artifact for the platform, compare to the repo, bump and reinstall if behind) — not only [`references/truecoverage.md`](references/truecoverage.md) prose.

Per the [Agent Skills specification](https://agentskills.io/specification), this skill keeps **`SKILL.md`** as the entrypoint. **Load a reference file only when** the task matches that flow (`/init`, `/test`, `/plan`, `/evolve`, `/explore`, TrueCoverage setup/instrument, **manual-session test authoring**). **After reading `.testchimp-tests`**, if **`project_type`** is **mobile**, **multi-platform**, or legacy **ios/android**, load [`references/mobilewright-smarttests.md`](references/mobilewright-smarttests.md) and [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md) for SmartTest authoring, init, or ExploreChimp on that repo. For **`/testchimp test`** or **`/testchimp explore`** on a **PR branch**, also load [`references/platform-scope.md`](references/platform-scope.md) and apply inform/ask + branch-plan **Platform scope** before Plan approval. When the user pastes a **Copy script generate prompt** from the manual session viewer or says **`/testchimp author test for manual session`**, load [`references/author-test-from-manual-session.md`](references/author-test-from-manual-session.md). During `/testchimp init`, run the **workstation gate** (MCP + API key) first — see [Workstation gate](references/init-testchimp.md#workstation-gate-always-first) in [`references/init-testchimp.md`](references/init-testchimp.md) — then go directly into the phased init workflow (requirement gather, collaborative plan, execute item-by-item with **project-level** progress in `plans/knowledge/ai-test-instructions.md`). When classifying **greenfield vs existing Playwright**, dual-folder mappings, import strategy, or CI alignment for SmartTests, load [`references/importing-existing-tests.md`](references/importing-existing-tests.md). During **`/testchimp test`**, satisfy **Preamble #4** before any Playwright/Mobilewright spawn; treat **`/testchimp test`** as the **full chain** through **Phase 6 (ExploreChimp)** or branch-plan **`N/A`** when UI SmartTests are in scope ([`references/testing-process.md`](references/testing-process.md)). If the user specifies an **area**, **story/scenario**, or other **focus instructions**, prioritize that scope; otherwise derive context from **PR changes / recent commits** and cross-reference test plans per the same reference. For **ExploreChimp** execution details or **`/testchimp explore`**, load [`references/exploratory_runs.md`](references/exploratory_runs.md). For **Playwright `page.route`** (HTTP/API), **optional AIMock** (LLM), goldens layout, and test doubles, load [`references/mocking_strategy.md`](references/mocking_strategy.md). Plan **reading and authoring** (including MCP create/update flows) use [`references/test-planning.md`](references/test-planning.md). When planning or implementing **seed**, **teardown**, or **read** test endpoints, **fixtures**, or **backend state assertions** after UI flows, load [`references/seeding-endpoints.md`](references/seeding-endpoints.md) (includes **restart/reprovision** the app-under-test after seed or backend changes) and [`references/fixture-usage.md`](references/fixture-usage.md). During `/testchimp test`, load [`references/api-testing.md`](references/api-testing.md) when a scenario is designated for API automation and [`references/write-smarttests.md`](references/write-smarttests.md) for UI SmartTests. Load [`references/environment-management.md`](references/environment-management.md) when choosing or provisioning test environments, EaaS (Bunnyshell), branch-scoped `BASE_URL` resolution, or **mobile** device/emulator setup. During **`/testchimp evolve`**, load [`references/evolve-coverage.md`](references/evolve-coverage.md) — structured **Analyze → Plan → Execute** with phase gates and persisted plans at `<MAPPED_PLANS_ROOT>/knowledge/evolve_plans/plan_<YYYY-MM-DD>_<nn>.md`. When the evolve plan includes **TrueCoverage-targeted ExploreChimp**, also load [`references/exploratory_runs.md`](references/exploratory_runs.md). Use [`references/truecoverage.md`](references/truecoverage.md) for **`testchimp.emit`** metadata (including dot-scoped entity keys) so instrumentation captures how real users slice the product for later fixture and test work. Load [`references/truecoverage.md`](references/truecoverage.md) when RUM instrumentation, TrueCoverage planning, or TrueCoverage MCP tools are in scope on **web** (default **opted-in** unless `ai-test-instructions.md` explicitly opts out; **skip TrueCoverage planning for native mobile** per that doc). Deep **`ai-wright`** API detail lives in [`references/ai-wright-usage.md`](references/ai-wright-usage.md) — pull it in when authoring or debugging **web-only** AI steps.

### `/testchimp test` plan persistence (branch scope)

`/testchimp test` may be run multiple times while developing a branch. To make reruns deterministic, the Plan phase must be persisted and reused as a **per-branch** markdown spec under the mapped plans root:

- Always locate the mapped plans root (`<MAPPED_PLANS_ROOT>`) via the `.testchimp-plans` marker file.
- Always create/update the branch plan file at:
  - `<MAPPED_PLANS_ROOT>/knowledge/branch_test_plans/branch_<branch_slug>.md`
- Define `<branch_slug>` as a **filename-safe** form of the current git branch name:
  - Resolve branch name via `git branch --show-current` (fallback `git rev-parse --abbrev-ref HEAD`, then `git rev-parse --short HEAD` for detached HEAD)
  - Lowercase; replace any non `[a-z0-9]` sequences (including `/`) with `_`; trim leading/trailing `_`
- Always include YAML frontmatter with:
  - `LastRunOnCommit: <commit_sha>`
- Always maintain an explicit **done/not-done checklist** of action items so the agent can resume from the file on subsequent runs.

See [`references/testing-process.md`](references/testing-process.md) for the full `/testchimp test` workflow (**Analyze → Plan → Execute → Validate → Phase 5 (Smart regression) → Phase 6 (ExploreChimp) → Phase 7 (Cleanup)**) including non-negotiables, required plan sections, **Preamble #4**, and the checklist gating mechanism.

Environment provisioning contract:

- During `/testchimp init`, persist the **chosen** environment provisioning strategy under `plans/knowledge/ai-test-instructions.md` → `## Environment Provision Strategy`.\n  - If **Local - Test Authoring** is the chosen path, persist a single **local environment up** command/script and explicit **wait-for-healthy** criteria (so the agent can reliably bring the stack up locally, wait until it’s ready, then run seeds/tests).\n  - If **EaaS (Bunnyshell)** or **Branch Management** is chosen, persist the provisioning + wait approach (and how `BASE_URL`/`BACKEND_URL` are resolved).
- Ensure the same file contains **`## Past learnings — authoring & validation (FAQ)`** (see template in [`references/init-testchimp.md`](references/init-testchimp.md)) so agents have a **known playbook** before improvising env fixes.
- During **`/testchimp test`**, the agent must **strictly** follow `ai-test-instructions.md` for bring-up, URLs, and teardown—see **[Binding: ai-test-instructions](references/testing-process.md#binding-ai-test-instructions-environment-and-faq-playbook)** in [`references/testing-process.md`](references/testing-process.md).
- During `/testchimp test`, treat reading `ai-test-instructions.md` as a **hard prerequisite** before **Analyze/Plan** and again before **Execute**; the environment strategy and URL resolution recorded there must drive plan decisions and run-time provisioning.
- During `/testchimp test`, the agent must consult that decision file and bring the environment up (and wait until healthy) before authoring or executing any test cases (including fixture-driven seed/teardown where tests use shared setup).
- During `/testchimp evolve`, treat reading `ai-test-instructions.md` as a **hard prerequisite** before **Analyze/Plan** and before any test authoring/execution work; follow pre-agreed environment decisions exactly (local, Bunnyshell/EaaS, staging/branch strategy as recorded).

**Backend / seed changes: restart or reprovision the app-under-test.** When authoring or changing tests, **fixtures**, or **backend** code that affects what the app-under-test runs (including **seed/teardown/read** routes, **config or flags** that enable test-only behavior, or any service your tests target per `ai-test-instructions.md`), **do not assume a running stack already includes those changes**. Follow the **Environment Provision Strategy** recorded in `plans/knowledge/ai-test-instructions.md`:

- **Local provisioning** — **Tear down and bring the stack back up** (or restart only the affected services) so the running processes load the new code. Prefer the project’s documented **local up** / **wait-for-healthy** flow; killing the existing env and starting fresh is acceptable when that matches how the team runs the stack.
- **Cloud / SaaS / EaaS (ephemeral environments)** — Provisioning often builds from the **current Git branch at `HEAD`**. **Commit and push** (or otherwise ensure the remote branch contains) seed-endpoint and backend changes **before** reprovisioning or re-running provision, so the cloud environment does not deploy stale code. If the project uses branch-specific or staging URLs, confirm the same source-of-truth rules documented in `ai-test-instructions.md`.

See also [`references/seeding-endpoints.md`](references/seeding-endpoints.md) (after changing seed routes) and [`references/environment-management.md`](references/environment-management.md) (local vs EaaS).

## References (this skill)

| Path | Purpose |
|------|---------|
| [`references/init-testchimp.md`](references/init-testchimp.md) | Phased init: requirement gather, collaborative plan, action-item execution |
| [`references/importing-existing-tests.md`](references/importing-existing-tests.md) | Greenfield vs existing Playwright, migration strategies, mapped-folder layout, CI |
| [`references/testing-process.md`](references/testing-process.md) | `/testchimp test` strict workflow: Analyze → Plan → Execute → Validate → Phase 5 (Smart regression) → Phase 6 (ExploreChimp; default-on for UI test deltas) → Phase 7 (Cleanup); checklist gates; “run tests” vs full-chain semantics |
| [`references/exploratory_runs.md`](references/exploratory_runs.md) | `/testchimp explore` and ExploreChimp: env vars, concepts, test selection, `ai-test-instructions` **`## ExploreChimp`** |
| [`references/security_scans.md`](references/security_scans.md) | `/testchimp run security scan for <scan_id>`: nested configs → DAST/SAST/deps/secrets |
| [`references/security/dast.md`](references/security/dast.md) | DAST (ZAP) playbook |
| [`references/security/sast.md`](references/security/sast.md) | SAST (Semgrep) playbook |
| [`references/security/deps.md`](references/security/deps.md) | Deps (Trivy) playbook |
| [`references/security/secrets.md`](references/security/secrets.md) | Secrets (Gitleaks) playbook |
| [`references/security/dast.md`](references/security/dast.md) | DAST detail: scope, active scan, ephemeral sandbox |
| [`references/write-smarttests.md`](references/write-smarttests.md) | SmartTest authoring (UI tests with smart steps) details used by the execution phase |
| [`references/api-testing.md`](references/api-testing.md) | API test authoring workflow from captured browser network flows |
| [`references/test-planning.md`](references/test-planning.md) | Plan folder layout, frontmatter, `/testchimp plan`, MCP plan authoring |
| [`references/evolve-coverage.md`](references/evolve-coverage.md) | `/testchimp evolve`: Analyze → Plan → Execute, phase gates, persisted `knowledge/evolve_plans/`, optional TrueCoverage-targeted **ExploreChimp** |
| [`references/cleanup.md`](references/cleanup.md) | `/testchimp cleanup`: semantically similar / duplicate SmartTest audit; mark distinct; optional deletions (max 10/run) |
| [`references/truecoverage.md`](references/truecoverage.md) | TrueCoverage RUM setup (web + iOS + Android), `plans/events/*.event.md`, MCP analytics |
| [`references/ai-wright-usage.md`](references/ai-wright-usage.md) | `ai-wright` install, env, API depth |
| [`references/environment-management.md`](references/environment-management.md) | Persistent vs ephemeral envs, Bunnyshell, Branch Management, MCP `get-branch-specific-endpoint-config` |
| [`references/cli.md`](references/cli.md) | `@testchimp/cli`: shell usage, `--json-input`, key export for CLI, stdout/stderr; **screen-state atlas** (`list-screen-states`, `upsert-screen-states`) |
| [`references/mocking_strategy.md`](references/mocking_strategy.md) | `page.route` vs optional AIMock, `<tests_root>/assets/goldens`, init plan/execute split |
| [`references/seeding-endpoints.md`](references/seeding-endpoints.md) | Test-only seed, teardown, and read endpoints; discovery, proxy pattern, idempotency, propagated seed-request header guidance |
| [`references/project-types-and-scaffolds.md`](references/project-types-and-scaffolds.md) | Scaffold layouts (`web` / `mobile` / `multi-platform`), spec/fixture paths, `shared/`, run commands, agent authoring guide |
| [`references/fixture-usage.md`](references/fixture-usage.md) | `mergeTests`, fixture barrels, `shared/` helpers, `testInfo`, probe specs |
| [`references/mobilewright-smarttests.md`](references/mobilewright-smarttests.md) | Native mobile: `@mobilewright/test`, `screen`/`device`, `use.platform`, no ai-wright |
| [`references/platform-scope.md`](references/platform-scope.md) | PR-branch platform scope for **mobile** / **multi-platform**: deduce, inform user, or ask; branch-plan persistence; test + explore |
| [`assets/template_playwright.config.js`](assets/template_playwright.config.js) | Web-only Playwright config |
| [`assets/template_mobile_mobilewright.config.ts`](assets/template_mobile_mobilewright.config.ts) | Mobile: setup + api + ios + android |
| [`assets/template_multi_platform_playwright.config.js`](assets/template_multi_platform_playwright.config.js) | Multi-platform web + api |
| [`assets/template_multi_platform_mobilewright.config.ts`](assets/template_multi_platform_mobilewright.config.ts) | Multi-platform native matrix |
| [`assets/sample-mcp.json`](assets/sample-mcp.json) | Sample project MCP config: `npx`, `@testchimp/cli@latest`, `mcp`, `TESTCHIMP_API_KEY` + `TESTCHIMP_PROJECT_ID` placeholders |


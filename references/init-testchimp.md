# /testchimp init

Initialize the repo for TestChimp: reporter, MCP client, env vars, folder markers, and CI hints. This doc is written for **AI agents** executing setup in a codebase—follow it literally and surface blockers (missing keys, unmapped integrations) to the human.

---

## 1. Dependencies (Node / Playwright)

TestChimp SmartTests depend on Playwright 1.59.0+.

Run installs from the **directory that contains the file `.testchimp-tests`**—that file marks the SmartTests root regardless of folder name. If `.testchimp-tests` is not present yet, complete [§3](#3-plans-and-tests-roots-testchimp-integrations) first.

```bash
npm install playwright-testchimp-reporter
npm install -D testchimp-mcp-client
```

---

## 2. Environment variables for interaction with TestChimp Platform.

### Local Development (Cursor / Claude Code)

Set in the MCP server **`env`** block (not only in a repo `.env` file):

- **`TESTCHIMP_API_KEY`** — Project Settings → Keys / key management. The key identifies the **project**, which owns the **plans** and **tests** folder mappings in TestChimp.

Note that API key is **per project** - so the mcp configuration should be done at a project scope (eg: project folder/.cursor/mcp.json), instead of global (since a user may work on multiple projects).

### CI (for running SmartTests in CI)

TestChimp's tests can be run using the standard playwright runner since all tests are playwright based. (Version 1.59+). 

The scaffold `playwright.config.js` already configures the `playwright-testchimp-reporter` which enables reporting to TestChimp platform, enabling smart steps, and TrueCoverage tracking.

- **`TESTCHIMP_API_KEY`** — Required for looping in AI for AI steps and reporter to report execution details to TestChimp platform for coverage insights.

Ask user to configure the above as an environment variable in the Git repo provider in CI to use. Provide instructions to user depending on their Git provider.

---

## 2a. TrueCoverage opt-in (application instrumentation)

TrueCoverage links real user events with test runs (see [`references/truecoverage.md`](truecoverage.md)). During init, determine whether the **application codebase** already uses `testchimp-rum-js`: check `package.json` dependencies and search the repo for imports from `testchimp-rum-js` or your wrapper.

Read **`<SKILL_DIR>/bin/.truecoverage_setup`** if present (see [`truecoverage.md`](truecoverage.md) for `enabled=true|false|later` and the **3-day snooze** rule for `later`).

- If the file is **missing** or you need a fresh decision: briefly explain TrueCoverage (coverage insights aligned with real usage; agents use MCP analytics in audit) and ask whether to enable it for this repo.
  - **Yes, set up now:** include installing `testchimp-rum-js`, a single emit helper, env vars (`TESTCHIMP_API_KEY`, project id, per-env tags), and Playwright reporter alignment in the init work; when complete, write **`enabled=true`** to **`bin/.truecoverage_setup`**.
  - **Not now, but later:** write **`enabled=later`** and tell the user they can run **`/testchimp setup truecoverage`** (or equivalent) when ready.
  - **No:** write **`enabled=false`**.

If **`enabled=true`** is already set, skip the prompt unless the user asks to change it.

---

## 3. Plans and tests roots (TestChimp integrations)

**How TestChimp uses the repo (agent-relevant model):**

- **Plans root** — Humans author **user stories** and **test scenarios** (with stable ids such as `#TS-…`) in the TestChimp platform. That content is **synced into the mapped plans directory** in git as markdown. **Code agents should read these files** to see what must be covered, pull scenario titles and ids for `// @Scenario:` links, and **implement or extend tests guided by the plan**—not by guessing requirements from the UI alone.
- **Tests root** — This is where **SmartTests** live: Playwright-based specs and supporting code (`playwright.config.js`, page objects, fixtures, etc.). Tests may be written **by humans in the TestChimp platform** (synced into the repo), **by humans directly in the repo**, and **by code agents**—all targeting the same mapped **tests** tree. When you author or refactor automation, **do your work under the directory marked with `.testchimp-tests`** so it stays aligned with TestChimp execution, coverage, and sync.

**Git wiring:** The product expects **two distinct folders** in the repository, each registered as its own mapping under **TestChimp → Project Settings → Integrations → Git** (wording may vary slightly by UI version):

| Integration type in TestChimp | Role in the workflow | Typical repo contents |
|--------------------------------|----------------------|------------------------|
| **Plans** | Source of truth for scenarios/stories synced from the platform; agents read before coding tests | `.md` plan files with `#TS-…` and narrative |
| **Tests** | SmartTests and Playwright project; platform edits and local/agent edits converge here | `*.spec.ts`, `playwright.config.js`, `pages/`, … |

If the folders lack `.testchimp-plans` and `.testchimp-tests` marker files, that means the git integration and folder mapping hasn't been done properly. You should ask user to connect the repo to TestChimp, map the 2 folders to TestChimp side `tests` and `plans` and then raise a PR for both - from the TestChimp platform. That will ensure the scaffold is properly created, and the marker files will be created. If one is present and the other isn't provide instructions to user to also raise a PR for the missing one (from TestChimp platform).

**Critical for agents:**

1. **On the TestChimp product side**, these are always the concepts **plans** and **tests**—that is the vocabulary APIs and docs use (e.g. MCP `scope.folderPath` starts with `plans` or `tests` as the **platform** segment, not necessarily your folder name).
2. **On the repository side**, the directories can be named **anything** (`qa-specs/`, `ui_tests/`, `docs/plans/`, …). There is no requirement that the folders be literally `plans/` and `tests/`.
3. **Marker files** tie a concrete directory to its role so you never have to infer from naming:
   - At the **root of the plans tree**: an empty file **`.testchimp-plans`**
   - At the **root of the SmartTests tree**: an empty file **`.testchimp-tests`**
4. **Both** integrations must be mapped in the TestChimp project UI to the correct repo paths. Until both exist and are mapped, sync and coverage features that depend on plans or tests may be incomplete. Instruct the human to connect the Git repo in TestChimp and map the folders via TestChimp -> Project Settings -> Integrations -> Git.
5. Once mapped, ask the user to initiate a Git Sync from the TestChimp platform, so that the folders are mapped correctly, scaffold folder structure created correctly.

**Agent workflow:**

- Search the repo for `.testchimp-plans` and `.testchimp-tests`. The **directory that contains each marker** is the canonical root for that integration type.
- If the user wants TestChimp but markers are missing: **tell the user** to go to TestChimp Platform -> Project Settings → Integrations and map **both** folders (plans mapping → plans root, tests mapping → tests root), and raise PRs for both plans and tests (from Test Planning page and SmartTests page).

**Creating structure from scratch:** Pick two directories (prefer tests and plans as names), then ensure the human completes **both** mappings in TestChimp (and syncs from TestChimp platform side - to populate the folder scaffolds correctly).

---

## 4. Playwright config

- Keep `playwright.config.js` in the same directory as **`.testchimp-tests`** (the SmartTests root).
- Enable **`playwright-testchimp-reporter`**, trace **retain-on-failure**, screenshots on failure.
- Use **[`../assets/template_playwright.config.js`](../assets/template_playwright.config.js)** in this skill pack as a starting point (copy that file into the SmartTests root, or merge its options into an existing config).
- Important: Note that the config file should be directly inside the mapped `tests` folder for proper path resolution and test execution.

---

## 5. CI

- Run Playwright from the **tests** integration root (the path containing **`.testchimp-tests`**), with the env vars in [§2](#2-environment-variables-for-interaction-with-testchimp-platform).
- Provision a preview-url to run the tests on, and then set that as the `BASE_URL` env variable. Playwright config file specifies this as the base path via `use` block. So relative paths specified in tests get resolved to access the PR specific preview-url.
- If test executions are configured to be triggered on PR merge requests in the CI action, exlude TestChimp plan sync PRs (since they don't change system behaviour - just documentation). Title for those PRs is exactly `TestChimp Platform Sync [Plans]`.

---

## 6. MCP install (Cursor)

Register **`testchimp-mcp-client`** in MCP config with **`TESTCHIMP_API_KEY`**. See the package README for a JSON snippet.

After install, agents can call coverage and execution details tools; those APIs still scope by **platform** paths (`tests/...`, `plans/...`)—see **[`write-smarttests.md`](./write-smarttests.md)** for how that relates to the mapped folder on disk.

## 7. Test scaffold setup.

Once the above basic setup is done, you should work with the user to create the test harness. How TestChimps' tests are organized is - there are 3 Playwright projects inside the `tests` folder: `setup`, `e2e`, `api`.
* `setup`: This project is run first before the other projects. This is where the test data seeding should happen.
* `e2e`: This contains primarily UI driven tests (although these tests can also call API endpoints as needed - for test specific setups / teardowns and verifications).
* `api`: This contains primarily API tests.

The `playwright.config.js` wires them up using project dependencies to ensure the above structure.

During the init (this document's scope), you need to ensure a proper setup. By default there is an empty setup. Often, before running any tests, test data (test users, business entities etc.) will need to be inserted to the system to ensure tests have proper world-state to work on. To do this, first check if there are dedicated seed and teardown endpoints available in the codebase.
- If yes: Then make a plan to use them in the setup project - collaborate with the user to define what seed setup to enable (and teardown).
- If no: Then make a plan to create seed endpoints - suitable for the projects' structure. Collaborate with the user to define the endpoint structure (authentication, how to ensure they are not available in production etc.) and specific test data to seed in the global setup process.
Important: Ideally, seed / teardown endpoints should be idempotent, so that multiple runs will be safe.

## 8. Test Environment Setup

Read **[`references/environment-management.md`](environment-management.md)** for the full agent playbook: persistent vs ephemeral targets, Bunnyshell (EaaS), Branch Management preview URLs, and MCP **`get_branch_specific_endpoint_config`**.

Resolve "where" the tests are run. Typical choices depend on "when" the tests are run:
- within PR branch before merge (recommended)
- after merge to main branch

### If within PR branch - before merge

Then we will need PR branch specific environments. This can be:
- PR specific preview-url generated for the frontend (with shared persistent backend - such as staging) or,
- PR specific full stack isolated environment provisioned.
Usually the latter is preferred since that ensures proper data state and tests backend behaviour changes properly. 
TestChimp partners with Bunnyshell to support provisioning PR specific environments. If user prefers this, ask them to configure their Bunnyshell integration in TestChimp platform -> Project Settings -> Integrations -> Bunnyshell. (If they don't already have Bunnyshell configured, you can point them to Bunnyshell skill: https://github.com/bunnyshell/bunnyshell-environments-skill and ask to install that skill to get the yaml for bunnyshell created for their infra). 
If they have custom setup that creates PR specific environments (in-house built), then they can configure the resulting branch specific preview-url as a template string (or manual specific overrides) in the TestChimp -> Project Settings -> Branch Management section.

Alternatively, user may choose to locally spin up frontend (either pointing to shared backend or locally spinning up a backend as well). But in that case, we will still need logic for how the environment gets provisioned for running on CI (if the user wants CI runs configured).

### If after merge to main branch

Then, tests can run against a persistent environment (post deployment). Collaborate with the user to define the environment endpoint to use, and update the `.env-QA` file to have `BASE_URL` set suitably. `playwright.config.js` sets up this as the baseUrl in `use` block, so that tests can use relative paths, and those get resolved to the correct environment specific url.

## End State

Once the initialization is done, the following must be achieved:
- User has connected their Git repo to TestChimp platform
- They have mapped 2 folders on the repo for `plans` and `tests` platform folders.
- CI setup for running tests on CI (trigger based on what the user chooses - PR merge / deployments / manual invoke etc.) setup (or skipped if user chose to).
- Seed and teardown endpoints created, and global setup project written, that brings the test suite to a pre-defined useful product state on which tests can be authored next.
- Decisions taken during the above process (such as when to run tests, seeding plan, etc.) should be persisted in the `plans/knowledge/ai-test-instructions.md` file. This will be referred to in future agentic workflows for context. Include an **Environment strategy** subsection: default mode (persistent vs ephemeral), when to use Bunnyshell vs Branch Management preview URLs, and how CI supplies `BASE_URL` (or equivalent). If any items were skipped, note that as well.
- Skill init marker file is written to `<skill-dir>/bin/.init-has-run` (create `bin/` if needed). This marker is used by the skill preamble to detect whether `/.testchimp init` has already been completed for this installation.

Once done, tell the user of "how to use the agent skill going forward":
- [On-Demand] When a PR is ready to be tested, issue `/testchimp test` - this will trigger test authoring, referring the decisions taken above as context, to author tests for the changes made.
- [Ongoing] User can setup a background agent that runs either periodically or on triggers such as deployment / PR merge closed, that runs `/testchimp audit` - which will analyzer requirement coverage and TrueCoverage gaps and make plans to address them and execute those plans - so that coverage gaps are autonomously fixed.
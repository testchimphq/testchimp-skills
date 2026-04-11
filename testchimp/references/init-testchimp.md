# @testchimp /init

Initialize the repo for TestChimp: reporter, MCP client, env vars, folder markers, and CI hints. This doc is written for **AI agents** executing setup in a codebase—follow it literally and surface blockers (missing keys, unmapped integrations) to the human.

---

## 1. Dependencies (Node / Playwright)

TestChimp SmartTests depend on Playwright 1.59.0+.

Run installs from the **directory that contains the file `.testchimp-tests`**—that file marks the SmartTests root regardless of folder name. If `.testchimp-tests` is not present yet, complete [§3](#3-plans-and-tests-roots-testchimp-integrations) first (create the marker at the chosen root, then map it in TestChimp).

```bash
npm install playwright-testchimp-reporter ai-wright
npm install -D testchimp-mcp-client
```

---

## 2. Environment variables for interaction with TestChimp Platform.

### Local Development (Cursor / Claude Code)

Set in the MCP server **`env`** block (not only in a repo `.env` file):

- **`TESTCHIMP_API_KEY`** — Project Settings → Keys / key management. The key identifies the **project**, which owns the **plans** and **tests** folder mappings in TestChimp.

### CI (for running SmartTests in CI)

TestChimp's tests can be run using the standard playwright runner since all tests are playwright based. (Version 1.59+).

- **`TESTCHIMP_API_KEY`** — Required for looping in AI for AI steps and reporter to report execution details to TestChimp platform for coverage insights.

Ask user to configure the above as an environment variable in the Git provider in CI to use. Provide instructions to user depending on their Git provider.

---

## 3. Plans and tests roots (TestChimp integrations)

**How TestChimp uses the repo (agent-relevant model):**

- **Plans root** — Humans author **user stories** and **test scenarios** (with stable ids such as `#TS-…`) in the TestChimp platform. That content is **synced into the mapped plans directory** in git as markdown. **Code agents should read these files** to see what must be covered, pull scenario titles and ids for `// @Scenario:` links, and **implement or extend tests guided by the plan**—not by guessing requirements from the UI alone.
- **Tests root** — This is where **SmartTests** live: Playwright-based specs and supporting code (`playwright.config.js`, page objects, fixtures, etc.). Tests may be written **by humans in the TestChimp platform** (synced into the repo), **by humans directly in the repo**, and **by code agents in the IDE**—all targeting the same mapped **tests** tree. When you author or refactor automation, **do your work under the directory marked with `.testchimp-tests`** so it stays aligned with TestChimp execution, coverage, and sync.

**Git wiring:** The product expects **two distinct folders** in the repository, each registered as its own mapping under **TestChimp → Project Settings → Integrations → Git** (wording may vary slightly by UI version):

| Integration type in TestChimp | Role in the workflow | Typical repo contents |
|--------------------------------|----------------------|------------------------|
| **Plans** | Source of truth for scenarios/stories synced from the platform; agents read before coding tests | `.md` plan files with `#TS-…` and narrative |
| **Tests** | SmartTests and Playwright project; platform edits and local/agent edits converge here | `*.spec.ts`, `playwright.config.js`, `pages/`, … |

**Critical for agents:**

1. **On the TestChimp product side**, these are always the concepts **plans** and **tests**—that is the vocabulary APIs and docs use (e.g. MCP `scope.folderPath` starts with `plans` or `tests` as the **platform** segment, not necessarily your folder name).
2. **On the repository side**, the directories can be named **anything** (`qa-specs/`, `ui_tests/`, `docs/plans/`, …). There is no requirement that the folder be literally `plans/` or `tests/`.
3. **Marker files** tie a concrete directory to its role so you never have to infer from naming:
   - At the **root of the plans tree**: an empty file **`.testchimp-plans`**
   - At the **root of the SmartTests tree**: an empty file **`.testchimp-tests`**
4. **Both** integrations must be mapped in the TestChimp project UI to the correct repo paths. Until both exist and are mapped, sync and coverage features that depend on plans or tests may be incomplete. Instruct the human to connect the Git repo in TestChimp and map the folders via TestChimp -> Project Settings -> Integrations -> Git.
5. Once mapped, ask the user to initiate a Git Sync from the TestChimp platform, so that the folders are mapped correctly, scaffold folder structure created correctly.

**Agent workflow:**

- Search the repo for `.testchimp-plans` and `.testchimp-tests`. The **directory that contains each marker** is the canonical root for that integration type.
- If the user wants TestChimp but markers are missing: create the empty marker files at the chosen roots, then **tell the user** to go to TestChimp Platform -> Project Settings → Integrations and map **both** folders (plans mapping → plans root, tests mapping → tests root).

**Creating structure from scratch:** Pick two directories (prefer tests and plans as names), add the two marker files at those roots (`.testchimp-tests` and `.testchimp-plans`), then ensure the human completes **both** mappings in TestChimp (and syncs from TestChimp platform side - to populate the folder scaffolds correctly).

---

## 4. Playwright config

- Keep `playwright.config.js` in the same directory as **`.testchimp-tests`** (the SmartTests root).
- Enable **`playwright-testchimp-reporter`**, trace **retain-on-failure**, screenshots on failure.
- Use **[`../assets/template_playwright.config.js`](../assets/template_playwright.config.js)** in this skill pack as a starting point (copy that file into the SmartTests root, or merge its options into an existing config).
- Important: Note that the config file should be directly inside the mapped `tests` folder.

---

## 5. CI

- Run Playwright from the **tests** integration root (the path containing **`.testchimp-tests`**), with the env vars in [§2](#2-environment-variables-for-interaction-with-testchimp-platform).
- Provision a preview-url to run the tests on, and then set that as the `BASE_URL` env variable. Playwright config file specifies this as the base path via `use` block. So relative paths specified in tests get resolved to access the PR specific preview-url.
- If test executions are configured to be triggered on PR merge requests in the CI action, exlude TestChimp plan sync PRs (since they don't change system behaviour - just documentation). Title for those PRs is exactly `TestChimp Platform Sync [Plans]`.

---

## 6. MCP install (Cursor)

Register **`testchimp-mcp-client`** in MCP config with **`TESTCHIMP_API_KEY`**. See the package README for a JSON snippet.

After install, agents can call coverage and execution tools; those APIs still scope by **platform** paths (`tests/...`, `plans/...`)—see **[`write-smarttests.md`](./write-smarttests.md)** for how that relates to the mapped folder on disk.

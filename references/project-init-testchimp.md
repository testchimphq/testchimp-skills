# /testchimp project init

**One-time per project** (repo / team): **platform comms**, **folder mapping**, **connect-to-test-env**, **CI wiring**, plus optional imports and smoke validation. Runs in ChimpHands or a local agent workspace.

**Claude Code plugin command:** **`/testchimp project-init`** (same as **`/testchimp project init`** on other hosts). The `/` menu alias is **`/testchimp:project-init`**. Do **not** tell users to run `/testchimp:testchimp project-init`. Canonical prompt still routes here.

**Time:** with one-by-one tool approvals this typically takes about **20 minutes** and on the order of **60 approval prompts**. Tell the user that up front. **Claude Code:** point them at the README tip to pre-allow `mcp__plugin_testchimp_testchimp__*` in `.claude/settings.json`. If they decline a tool call, continue to the next step — do not stall or retry the same call in a loop.

**Not** the per-developer workstation setup — that is [`init-testchimp.md`](./init-testchimp.md) (`/testchimp init`).

## Progress tracking (platform)

Use MCP tools (CLI ≥ **0.1.35**):

- **`get-project-init-status`** — read `ProjectInitStatus`. Prefer snake_case (`platform_comms`, `folder_mapping`, `connect_to_test_env`, `ci_wiring`, optional `import_plans` / `import_tests` / `smoke_validation`, server-computed `overall_complete`). If a snake_case key is absent, accept the camelCase twin (`platformComms`, `folderMapping`, `connectToTestEnv`, `ciWiring`, `importPlans`, `importTests`, `smokeValidation`, `overallComplete`). Treat `PROJECT_INIT_ITEM_STATUS_DONE` (also accept bare `DONE` or boolean `true` on read) as complete for that item. **Do not** re-run init when overall is already complete.
- **`update-project-init-status`** — wrap fields in **`status`**. Only **snake_case** keys are supported on write. Always send the **full** status enum — never short values like `DONE` / `SKIPPED` / `NOT_APPLICABLE` / `INCOMPLETE` (a server alias for shorts is coming separately; docs and agents must use the canonical form now):
  - `PROJECT_INIT_ITEM_STATUS_DONE`
  - `PROJECT_INIT_ITEM_STATUS_SKIPPED`
  - `PROJECT_INIT_ITEM_STATUS_NOT_APPLICABLE`
  - `PROJECT_INIT_ITEM_STATUS_INCOMPLETE`

  ```json
  {
    "status": {
      "platform_comms": "PROJECT_INIT_ITEM_STATUS_DONE",
      "folder_mapping": "PROJECT_INIT_ITEM_STATUS_DONE",
      "connect_to_test_env": "PROJECT_INIT_ITEM_STATUS_DONE",
      "ci_wiring": "PROJECT_INIT_ITEM_STATUS_DONE",
      "import_plans": "PROJECT_INIT_ITEM_STATUS_DONE",
      "import_tests": "PROJECT_INIT_ITEM_STATUS_DONE",
      "smoke_validation": "PROJECT_INIT_ITEM_STATUS_DONE"
    }
  }
  ```

  Send only the keys you are updating. Partial merge; server recomputes `overall_complete` when all **required** items are `PROJECT_INIT_ITEM_STATUS_DONE`. Do not send `overall_complete` (server-computed). Do **not** send camelCase keys (`platformComms`, `folderMapping`, `connectToTestEnv`, `ciWiring`, …). After every update, read the tool response (or re-call **`get-project-init-status`**) and **verify the returned status for those keys reflects the value you sent** before continuing.
- **`get-git-folder-mapping`** / **`update-git-folder-mapping`** — read/write mapped `plans/` and `tests/` paths on the platform after the agent scaffolds folders locally (branch prefix **`testchimp-`**). Do **not** wait for a PR merge before calling `update-git-folder-mapping` or continuing local steps.
- **`invite-team-members`** (CLI ≥ **0.1.91**) — invite teammates by email; the **final** step of project init ([§ 7](#7-final--invite-team-members)).

**Required** for `overall_complete`: `platform_comms`, `folder_mapping`, `connect_to_test_env`, `ci_wiring`.

**Optional** (do not block completion): `import_plans`, `import_tests`, `smoke_validation`.

**Final step, always offered** (not in `ProjectInitStatus`): **invite team members**, after every other item is done, skipped or deferred.

**Out of init scope** (separate workflows): TrueCoverage → **`/testchimp setup truecoverage`** / **`/testchimp instrument`**; mocking lock-down → during **`/testchimp test`** / create-tests per [`mocking_strategy.md`](./mocking_strategy.md); seed endpoint authoring → during test authoring per [`seeding-endpoints.md`](./seeding-endpoints.md).

Also persist durable **non-env** decisions (deferred optionals, ExploreChimp notes when using the legacy file) carefully: **test-env connectivity always goes in `connect-to-test-env.policy.md`**. Do **not** create `ai-test-instructions.md` solely for env strategy.

---

> **Workflow overlay:** **Workflow id:** `project-init` (Claude Code **`/testchimp project-init`** / **`/testchimp:project-init`**; other hosts **`/testchimp project init`**). **Plan path:** `knowledge/workflow_plans/project-init/<workflow_execution_id>.plan.md`. Mint a **ULID** `workflow_execution_id`, **write on disk** that plan file (checklist of init action items), call **`upsert-plans-support-file`** with the **same** content (blocking), then seek **explicit user approval** before Phase 3 Execute — unless `--mode=non-interactive` or policy `allow-execute-without-approval`. Do not upsert-only: ChimpHands Files changed needs the local file. See [`policies-and-traceability.md`](./policies-and-traceability.md).

### Phase gating (required)

Between phases, **stop and complete the phase’s completion gate** before continuing. For **every** gate line: mark **done** (one-line evidence) or **`N/A`** + one-line justification. Record outcomes in the workflow plan / chat (and update **`connect-to-test-env.policy.md`** for env decisions).

---

## Purpose

Project init wires the **shared** TestChimp integration for a repo: Git folder mapping, test environment strategy, and CI. It usually runs with `plans/` and `tests/` in the **same repo as the product** (recommended). It may also run in a **plans/tests-only mapped repo** when the team chose separation — see [`split-repo-workspaces.md`](./split-repo-workspaces.md).

Agents must:

1. collaborate on a concrete action plan first,
2. track progress via **`get-project-init-status`** / **`update-project-init-status`**,
3. persist **test-env connectivity** in **`plans/knowledge/policies/connect-to-test-env.policy.md`** (upsert-policy); use existing `ai-test-instructions.md` only as a legacy fallback — do not create it for env,
4. execute each item methodically and update status after each completion.

### Source of truth: env policy (+ optional legacy file)

**Test-env connectivity** (local up, wait-for-healthy, CI/Cloud bring-up, `BASE_URL`) lives in:

`plans/knowledge/policies/connect-to-test-env.policy.md`

Skeleton: [`../assets/policies/connect-to-test-env.policy.md`](../assets/policies/connect-to-test-env.policy.md).

**Legacy:** If **`plans/knowledge/ai-test-instructions.md` already exists**, you may still maintain optional sections there (TrueCoverage Plan, ExploreChimp, FAQ). Prefer migrating Environment Provision Strategy content into the connect-to-test-env policy. **Do not** create `ai-test-instructions.md` on greenfield projects just to hold env strategy.

Optional legacy template (only when the file already exists or the team explicitly wants it for non-env notes):

```md
# TestChimp project notes (legacy)

## Completed Items

## Pending Items

## Deferred Items

---
## ExploreChimp

<!-- Optional: default sources / PR explore scope. See references/run-explorechimp.md. -->

## Past learnings — authoring & validation (FAQ)

<!-- Q/A playbook for env blockers — prefer updating connect-to-test-env.policy.md for bring-up steps. -->
```

Keep decision files **project-level only** (no per-laptop MCP progress — that belongs in init).

### Two scopes: workstation vs project

| Scope | Command | What it covers |
|--------|---------|----------------|
| **Workstation** (per machine) | **`/testchimp init`** / **`/testchimp:init`** | Local MCP file, API key on this laptop, local stack smoke. See [`init-testchimp.md`](./init-testchimp.md). |
| **Project** (repo / team) | **`/testchimp project-init`** / **`/testchimp:project-init`** / **`/testchimp project init`** | Platform comms verification, folder mapping, shared env strategy, CI, optional imports. |

A teammate may clone after project init is **`overall_complete`** and still need init on their machine (`/testchimp init`). Project init does **not** replace per-developer setup.

---

## Opening message (required, first user-facing step)

When project init starts, set expectations before deep work:

- **During project init**, TestChimp wires **one-time project infrastructure**: Git **plans/tests folder mapping** (agent-driven via CLI), **test environment strategy** (`connect-to-test-env`), **CI execution**, then optional **import** of existing plans/tests and optional **smoke** authoring. Basic SmartTests scaffold (markers, Playwright/Mobilewright harness) lands with folder mapping — not a full test-authoring campaign. Expect about **20 minutes** and many tool approvals unless TestChimp MCP tools are pre-allowed (`mcp__plugin_testchimp_testchimp__*` in `.claude/settings.json`).
- **Per developer**, each teammate runs **`/testchimp init`** (Claude Code menu **`/testchimp:init`**) once to register local MCP and verify their machine can run tests.
- **After setup**, the user mainly runs **`/testchimp test`** when a PR is ready; the agent runs the full QA workflow on demand.
- **Ongoing**, run **`/testchimp upkeep`** / **`/testchimp evolve`** for coverage gaps; **`/testchimp setup truecoverage`** when the team wants RUM analytics (not part of project init).
- **At the end**, you'll offer to invite their teammates so the whole team can use the project.

**Always** include: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

Then call **`get-project-init-status`** and report what is already **`PROJECT_INIT_ITEM_STATUS_DONE`** vs missing.

**Do not** ask about smoke validation (or author smoke tests) at the start. Critical setup first (`platform_comms` → `folder_mapping` → `connect_to_test_env` → `ci_wiring`); offer smoke only as an optional step with imports (Phase 1 optionals / Phase 3).

**Do not** ask for teammate emails at the start either. Team invites are the **last** step ([§ 7](#7-final--invite-team-members)).

---

## Phase 1 — Requirement gather (discover → clarify)

Discover from repo + platform first; ask targeted questions only when discovery is ambiguous.

**Do not** write substantive env-strategy content into `ai-test-instructions.md` — put it in **`connect-to-test-env.policy.md`**. Do not create `ai-test-instructions.md` until the user confirms they want that legacy file for non-env notes.

If **`get-project-init-status`** shows required items already **`PROJECT_INIT_ITEM_STATUS_DONE`**, treat Key Areas as **read-and-confirm** unless the user wants changes.

### Key Area 1 — Platform comms

Verify the **project** can talk to TestChimp APIs from this agent session (not every teammate’s laptop). Prefer the **plugin/extension-provided** hosted MCP (`https://mcp.testchimp.io/mcp`) when TestChimp is already installed as a plugin — do **not** write a second project-level server or require a stdio API key for these calls.

1. **`ephemeral-environment` (`action=CONFIG`)** `{}` — must **not** return **401** (empty config is OK).
2. **`get-project-credentials`** (when the connection is OAuth) — confirm `projectName` / `projectId` with the user. That is the project picked on the consent screen; every later tool call is scoped to it. If **`<git root>/.testchimp/mcp.json`** already has a real key for this project, leave it. If it is missing and runners will need a key, save it now using [Save the runner key](./init-testchimp.md#save-the-runner-key) — do not put the key in a shell command.
3. **`get-project-init-status`** — baseline current progress.
4. **Project mismatch (blocking)** — if this repo already has `.testchimp-plans` / `.testchimp-tests`, a gitignored `.testchimp/mcp.json` with a different `TESTCHIMP_PROJECT_ID`, or `get-git-folder-mapping` points at another `owner/repo` than this tree's remotes, the user signed in to the wrong project. Stop and tell them to re-authenticate via [Host MCP sign-in](./init-testchimp.md#workstation-gate-always-first), picking **this** repo's project. Then re-run this area.

Do **not** emit an early `ACTION_COMPLETED` here — that would close the run before Plan/Execute.

**What creates the run row:** the first successful **`report-agent-action`** (or a mutating call with inline **`agentTraceability`**) for this `workflow_execution_id`. `upsert-plans-support-file` alone does **not** create it. When you write the plan, send this first RAA (MCP camelCase field names):

```json
{
  "workflowId": "project-init",
  "workflowExecutionId": "<ulid>",
  "entityType": "POLICY",
  "actionType": "ANALYZED",
  "entityIdentity": "connect-to-test-env.policy.md"
}
```

When `entityType` is **`POLICY`**, `entityIdentity` **must** be a real **`*.policy.md` filename** for the policy this step is acting on (here `connect-to-test-env.policy.md`). The server returns **400** `POLICY entity_identity must be a *.policy.md filename` for catalog ids such as `project-init` or `init`. Use `CREATED` / `UPDATED` instead of `ANALYZED` only when you created or updated that policy file in this step.

`entityType: WORKFLOW` is **only** valid with `ACTION_COMPLETED` / `ACTION_FAILED` (and `entityIdentity` must equal `workflowId`). That is the whole-run close — there is no non-`POLICY` entity type for a mid-run “we started project-init” row. **`WORKFLOW` + `ANALYZED` is rejected** — that is the MCP schema, not a retry-with-different-casing issue. `ANALYZED` is for `USER_STORY` / `SCENARIO` / `POLICY` / other non-`WORKFLOW` entities. Close at end of Execute with `entityType: WORKFLOW`, `actionType: ACTION_COMPLETED` or `ACTION_FAILED`, `entityIdentity: project-init`. In ChimpHands, omit `userId` / prefer `actorType: CLOUD_AGENT` — MCP stamps `SESSION_ID` and the responsible user.

If **401** or tools are unavailable: the plugin / remote MCP is not signed in (or a stdio API key is missing). Ask the user to complete **`/testchimp init`** ([`init-testchimp.md`](./init-testchimp.md)) — authenticate the hosted server in the host MCP UI, not by pasting an API key.

Seed composite policies under **`plans/knowledge/policies/`** when missing (`run-qa.policy.md`, `upkeep.policy.md` from [`../assets/policies/`](../assets/policies/) — do not overwrite team policies).

### Key Area 2 — Folder mapping

**Agent-first (preferred).** Use CLI tools; manual TestChimp → Project Settings → Integrations is **fallback only** when CLI calls fail or Git integration is not yet connected.

Agent discovery (report findings first):

1. **`get-git-folder-mapping`** — platform `plans_folder_path`, `tests_folder_path`, repository.
2. On disk — locate marker files (terminal: `find . -name '.testchimp-*'`; Glob may miss dotfiles):
   - `.testchimp-plans` → plans root
   - `.testchimp-tests` → SmartTests root
3. Read **`.testchimp-tests`** for **`project_type`** (`web` default; `mobile` / `multi-platform`; legacy `ios`/`android` → mobile). See [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md).

**When mapping is missing or markers absent on disk:**

1. Propose **`plans/`** and **`tests/`** paths (or team-preferred names) with the user.
2. Scaffold the SmartTests tree per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) — markers, `playwright.config.*` / `mobilewright.config.ts`, fixture barrels ([`fixture-usage.md`](./fixture-usage.md)), deps ([`write-smarttests.md`](./write-smarttests.md)).
3. Call **`update-git-folder-mapping`** with the **local** paths (`plans_folder_path`, `tests_folder_path`, `repository_full_name` when needed) as soon as markers exist on disk. Do **not** block on a merge.
4. **Suggest** a commit / PR on branch prefix **`testchimp-`** so the team can review the scaffold — remaining local steps (env policy, CI file, status updates, invites) must continue even if the user defers or the PR is unmerged.
5. Confirm both markers exist locally. Use **`git -C <dir>`** rather than `cd <dir> && git …`.

**Fallback (CLI blocked or no Git integration yet):** Ask the user to connect the repo in TestChimp → Project Settings → Integrations → Git and map folders in the UI. Pull platform sync PRs when they exist so markers appear locally, but keep going with a local scaffold if a merge is still pending. Retry **`get-git-folder-mapping`** after.

Platform paths in MCP APIs use platform-rooted paths (`plans/...`, `tests/...`) even when repo folder names differ.

**Harness note:** Init scaffolds layout and deps; domain fixtures and seed endpoints are authored during **`/testchimp test`** / create-tests when scenarios require them.

### Key Area 3 — Connect to test environment

Why: agents and CI need a documented, repeatable way to provision and reach the app under test.

Agent discovery:

- Inspect CI/workflows and env files for `BASE_URL` / preview URL conventions.
- Check for **`plans/knowledge/policies/connect-to-test-env.policy.md`** (or frontmatter `workflow-id: connect-to-test-env`).
- Read **`## Environment Provision Strategy`** in `ai-test-instructions.md` if present.

Decide and record **in `connect-to-test-env.policy.md`** (then **`upsert-policy`**):

- **Local — Test Authoring** (`## Local Agent`): single agent-runnable **local up** command + **wait-for-healthy** criteria + URL mapping (`BASE_URL`, backends).
- **CI — Test Execution** (`## CI / Cloud`): persistent vs ephemeral (EaaS/Bunnyshell, Branch Management preview URLs, on-runner spin-up) per [`environment-management.md`](./environment-management.md).
- **Auth flows** (`## Auth flows`, when the product has sign-up / verify / OTP / MFA / reset): detect provider and existing test hooks; choose a ladder step; ask only for gaps; record provider, env/secret **names**, and setup/`storageState` paths. Full playbook: [`auth-flows.md`](./auth-flows.md). Do **not** plan hosted inboxes or rented SMS numbers.

If a legacy **`## Environment Provision Strategy`** exists in `ai-test-instructions.md`, migrate usable content into the policy rather than duplicating forever.

If no usable policy exists (and no legacy strategy to migrate), mark **Missing Config**, discuss with the user, and author/seed policy ([`create-policy.md`](./create-policy.md)) — **blocking** for env-dependent optional work (e.g. import `markScreenState`).

Full playbook when executing: [`connect-to-test-env.md`](./connect-to-test-env.md).

### Key Area 4 — CI setup

Agent discovery:

- Check `.github/workflows/` (or equivalent) for Playwright/Mobilewright/TestChimp CI.
- Note whether jobs **`cd`** into the **mapped SmartTests folder** and set **`TESTCHIMP_API_KEY`**.

Ask only when discovery is ambiguous: CI system, PR vs main triggers, env strategy alignment.

**Detail reference:** [`configure-ci-test-execution.md`](./configure-ci-test-execution.md), [`import-existing-tests.md`](./import-existing-tests.md) when replacing legacy CI.

### Optional — Import existing plans

When the team has requirement/plan markdown outside the mapped **`plans/`** tree:

- Offer nested **`/testchimp import plans <folder>`** ([`import-plans.md`](./import-plans.md)) — **one approval** with the parent init plan.
- Or skip; user can run standalone later.

**Platform plans already exist, local folders empty (do not silently skip):** If **`import_plans`** is already **`PROJECT_INIT_ITEM_STATUS_DONE`** (or **`get-requirement-coverage`** / **`list-test-scenarios-for-scope`** then **`get-user-stories`** / **`get-test-scenarios`** show stories/scenarios on the project) **but** the mapped **`plans/stories`** and **`plans/scenarios`** trees have no `.md` files, **tell the user** and **offer to pull them down** into those folders. Do **not** treat empty local dirs as “nothing to import.” Pull-down steps: [`import-plans.md`](./import-plans.md)#platform-plans-present-local-folders-empty.

### Optional — Import existing tests

When the mapped SmartTests root looks **scaffold-only** (≤ 3 real `*.spec.{js,ts}` outside `setup/`) **and** other E2E exists elsewhere:

- Offer nested **`/testchimp import existing tests <folder>`** ([`import-existing-tests.md`](./import-existing-tests.md)) — **one approval**.
- If the mapped root already has a real suite: **N/A** or lightweight align-in-place (reporter/fixtures-first only) — do not re-ask full migration every run.
- Defer optional **`markScreenState`** until **Key Area 3** / connect-to-test-env is done.

### Optional — Smoke validation (author smoke tests)

**After** the four required areas are planned — never before `connect-to-test-env` / folder mapping. Same posture as imports: offer once, skip freely, does not block `overall_complete`.

When offering:

- Author **2–3** critical-path SmartTests under the mapped SmartTests root (tag `@smoke` per `global.policy.md` when tags are defined).
- Requires markers + a usable local-up / env contract from **Key Area 3** — if those are still missing in Phase 1 discovery, plan smoke for Phase 3 **after** connect-to-test-env executes; do not block on smoke now.
- Follow [`write-smarttests.md`](./write-smarttests.md); local run guidance in [`init-testchimp.md`](./init-testchimp.md).
- Or skip; user can author later via **`/testchimp create tests`** / **`/testchimp test`**.

### Final — Invite team members

Don't discover or ask anything here in Phase 1. Just list it as the last plan item; it runs in Phase 3 after everything else ([§ 7](#7-final--invite-team-members)).

### Phase 1 completion gate

- [ ] **Key Area 1** — platform comms verified (`ephemeral-environment` (`action=CONFIG`) not 401); signed-in project matches this repo; init status baseline read.
- [ ] **Key Area 2** — mapping state discovered; agent CLI path or fallback documented.
- [ ] **Key Area 3** — env strategy decided enough for Phase 2; connect-to-test-env policy gate satisfied or authoring planned.
- [ ] **Key Area 4** — CI discovery + intended direction recorded.
- [ ] **Optional imports / smoke** — nested / skipped / **N/A** with one-line justification each (smoke offered only alongside optionals, not before required areas).

---

## Phase 2 — Plan phase (four required areas + optionals)

Create **`## Init action items`** in the project-init **`.plan.md`** checklist (preferred) — or in an **existing** `ai-test-instructions.md` if the team already uses that file — with **`status`**: `pending | in_progress | done | skipped | deferred`. Do not create `ai-test-instructions.md` just for this checklist.

Your plan **must** include exactly these **four required** areas in order, plus optional items when applicable:

1. **Platform comms**
2. **Folder mapping** (includes scaffold / harness when needed)
3. **Connect to test environment**
4. **CI setup**

Optional (when planned): **Import plans**, **Import tests**, **Smoke validation**.

**Always last:** **Invite team members** (offered once; the user may skip).

### Acceptance criteria

**Platform comms**

- `ephemeral-environment` (`action=CONFIG`) succeeds (not 401). Plugin / OAuth sessions use the consent-chosen project; a mismatch with this repo is resolved via Host MCP sign-in before continuing.
- `update-project-init-status` with `platform_comms: PROJECT_INIT_ITEM_STATUS_DONE` when complete. Verify the returned status.

**Folder mapping**

- **`get-git-folder-mapping`** reflects agreed paths.
- Both `.testchimp-plans` and `.testchimp-tests` exist on disk (local scaffold is enough; a merge is optional).
- SmartTests scaffold matches [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md); deps installed at SmartTests root.
- `update-project-init-status` with `folder_mapping: PROJECT_INIT_ITEM_STATUS_DONE` when complete. Verify the returned status.

**Connect to test environment**

- **`connect-to-test-env.policy.md`** exists with local-up + health criteria (and CI/Cloud when applicable). Legacy Environment Provision Strategy in an **existing** `ai-test-instructions.md` may temporarily satisfy Missing Config until migrated — prefer the policy.
- `update-project-init-status` with `connect_to_test_env: PROJECT_INIT_ITEM_STATUS_DONE` when complete. Verify the returned status.

**CI setup**

- Workflow authored, verified, or **N/A** with justification; runs from SmartTests root with `TESTCHIMP_API_KEY` and env strategy for `BASE_URL`.
- User informed how to trigger CI runs.
- `update-project-init-status` with `ci_wiring: PROJECT_INIT_ITEM_STATUS_DONE` when complete. Verify the returned status.

**Optional imports**

- Per [`import-plans.md`](./import-plans.md) / [`import-existing-tests.md`](./import-existing-tests.md); set `import_plans` / `import_tests` on platform when done.

**Optional smoke validation**

- 2–3 `@smoke` SmartTests authored and runnable against the documented local/test env, **or** skipped / **N/A** with justification.
- `update-project-init-status` with `smoke_validation: PROJECT_INIT_ITEM_STATUS_DONE` when smoke finishes successfully (optional — does not affect `overall_complete`). Verify the returned status. Use `PROJECT_INIT_ITEM_STATUS_SKIPPED` or `PROJECT_INIT_ITEM_STATUS_NOT_APPLICABLE` when recording a skip / N/A.

**Invite team members (last)**

- Offered after every other item; invites sent for the emails the user confirmed, **or** skipped. Record the outcome in the plan (not tracked in `ProjectInitStatus`).

After the plan is written, get **explicit user approval** before Phase 3.

### Phase 2 gate

- [ ] Four required areas (+ optionals) listed with acceptance criteria.
- [ ] User explicitly approved the plan.

---

## Phase 3 — Execution phase

Execute in order; after each area, verify acceptance criteria, call **`update-project-init-status`**, and update **`connect-to-test-env.policy.md`** for env decisions (upsert-policy). Update an existing `ai-test-instructions.md` only for legacy non-env notes / FAQ — do not create it for env.

**PR strategy:** Suggest a commit / PR (one combined or separate slices: mapping/scaffold, env docs, CI). Default to separate PRs when slices are large. Branch prefix **`testchimp-`**. **Do not** pause Execute for “waiting on merge” — local files, `update-git-folder-mapping`, `update-project-init-status`, CI template, and invites do not require the PR to land first.

### 1. Platform comms

- Re-verify **`ephemeral-environment` (`action=CONFIG`)**.
- Mark `platform_comms: PROJECT_INIT_ITEM_STATUS_DONE` (full enum; verify the returned status).
- Ensure the plan ULID run already exists (first **`report-agent-action`** / mutating call with `workflowId: project-init`) — do not close with `ACTION_COMPLETED` until End state.

### 2. Folder mapping (+ scaffold / harness)

**CLI-first flow:**

1. **`get-git-folder-mapping`** — confirm or set target paths.
2. If markers missing — scaffold per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md):
   - Marker files, `setup/` / `e2e` or `web/e2e` + `mobile/e2e` / `api/`, fixture barrels ([`fixture-usage.md`](./fixture-usage.md)).
   - **Web:** `@playwright/test` ≥ 1.59.0, `@testchimp/playwright`, `@testchimp/cli` devDep, [`template_playwright.config.js`](../assets/template_playwright.config.js).
   - **Mobile:** `mobilewright`, `@mobilewright/test` (same version), mobilewright config templates.
3. **`update-git-folder-mapping`** as soon as markers exist locally (do not wait for merge).
4. Confirm markers locally. Suggest commit / PR; continue if it is not merged.
5. If **`plans/guide/SAMPLE_PLANS.md`** is missing, copy [`../assets/guide/SAMPLE_PLANS.md`](../assets/guide/SAMPLE_PLANS.md). Do **not** overwrite an existing guide, and never overwrite **`plans/stories/**`** or **`plans/scenarios/**`**. Existing story/scenario files keep their frontmatter `id:` values — do not re-create them or invent ids. That guide must **not** contain real or placeholder story/scenario ids. New stories and scenarios are created with **`create-user-story`** / **`create-test-scenario`**; write local files from the create response (the platform assigns the ids).
6. **If the platform already has plans and local `plans/stories` + `plans/scenarios` are empty:** do **not** skip. Tell the user and offer to pull them down — [`import-plans.md`](./import-plans.md)#platform-plans-present-local-folders-empty.

**Dependencies** (SmartTests root):

```bash
npm install @testchimp/playwright
npm install -D @testchimp/cli@latest
# mobile additionally: npm install mobilewright @mobilewright/test
```

**Fallback:** Manual platform Git integration + sync PRs (see Key Area 2) — only when CLI path failed.

Mark `folder_mapping: PROJECT_INIT_ITEM_STATUS_DONE` when markers + platform mapping align (verify the returned status).

### 3. Connect to test environment

Follow [`connect-to-test-env.md`](./connect-to-test-env.md) / [`environment-management.md`](./environment-management.md):

- Author or confirm **`connect-to-test-env.policy.md`** with Local Agent + CI / Cloud sections (local-up, wait-for-healthy, URL mapping). Call **`upsert-policy`**.
- Do **not** also invent **`## Environment Provision Strategy`** in a new `ai-test-instructions.md`. If that legacy file already has strategy content, migrate it into the policy.
- For ephemeral EaaS: confirm `ephemeral-environment` (`action=CONFIG`) payload; Bunnyshell / Branch Management as applicable.

Mark `connect_to_test_env: PROJECT_INIT_ITEM_STATUS_DONE` when strategy is documented and verified (or policy + local-up contract exists for later provisioning). Verify the returned status.

### 4. CI setup

Follow [`configure-ci-test-execution.md`](./configure-ci-test-execution.md):

- Copy [`../assets/template_smarttests.yml`](../assets/template_smarttests.yml) to **`.github/workflows/smarttests.yml`**. Replace `tests` with the mapped SmartTests folder if needed. Do **not** write a draft and then `sed` it — the template is already valid (`working-directory`, `TESTCHIMP_EXECUTION_SOURCE=CI`, `TESTCHIMP_API_KEY`, `BASE_URL`, skip plan-sync PRs).
- Run from SmartTests root; `TESTCHIMP_API_KEY` in CI secrets; `TESTCHIMP_EXECUTION_SOURCE=CI` on pipeline jobs.
- Pass `BASE_URL` per env strategy; exclude plan-sync PRs titled `TestChimp Platform Sync [Plans]`.
- If nested import already authored CI — **verify only**, do not duplicate.
- Git commands: **`git -C <dir> …`**, never `cd <dir> && git …`.
- **ChimpHands:** Pushing `.github/workflows/*` requires the TestChimp GitHub App **Workflows: Read & write** permission (Actions `GITHUB_TOKEN` cannot modify workflow files). If push is rejected for missing workflows permission, tell the user to grant that App permission, accept the install update, then run `testchimp chimphands refresh-git-auth` and retry — do not suggest adding `permissions.workflows` to the workflow YAML (that key is invalid). If `chimphands.yml` is missing, install it from the TestChimp UI; do not overwrite a customized workflow.

Mark `ci_wiring: PROJECT_INIT_ITEM_STATUS_DONE` when workflow exists, or `PROJECT_INIT_ITEM_STATUS_NOT_APPLICABLE` when N/A is justified. Verify the returned status.

### 5. Optional — Import plans / Import tests

When approved in Phase 2:

- **Plans:** [`import-plans.md`](./import-plans.md) → `import_plans: PROJECT_INIT_ITEM_STATUS_DONE` (verify the returned status). If import is already complete on the platform but local `plans/stories` and `plans/scenarios` are empty, tell the user and offer the pull-down in that playbook — do not skip.
- **Tests:** [`import-existing-tests.md`](./import-existing-tests.md) → `import_tests: PROJECT_INIT_ITEM_STATUS_DONE` (verify the returned status); run `markScreenState` only after connect-to-test-env is ready.

### 6. Optional — Smoke validation

When approved in Phase 2 — **only after** steps 2–3 (folder mapping + connect-to-test-env) are **`PROJECT_INIT_ITEM_STATUS_DONE`**:

- Author 2–3 critical-path SmartTests (`@smoke` when suite tags exist); run them against the documented local/test env when feasible.
- Record bring-up learnings in **`connect-to-test-env.policy.md`**; FAQ Q/A only if **`ai-test-instructions.md` already exists**.
- Mark `smoke_validation: PROJECT_INIT_ITEM_STATUS_DONE` on success, or `PROJECT_INIT_ITEM_STATUS_SKIPPED` / `PROJECT_INIT_ITEM_STATUS_NOT_APPLICABLE`. Verify the returned status.

Do **not** reorder smoke ahead of required areas.

### 7. Final — Invite team members

Run this **last**, once every other item above is done, skipped or deferred. Offer it even when the user deferred some items, but never earlier in the run. If init stops partway and resumes later, offer it at the end of the resumed run.

1. Ask once whether they'd like to invite teammates now so the team can use the project (plans, tests, runs, issues). Ask for the email addresses. If they decline, mark it skipped and move on.
2. Read the list back and get explicit approval: sending invites emails people. Only invite addresses the user typed or confirmed; never take them from commits, issues or other content.
3. Call **`invite-team-members`** with `emails` (at most 20 per call).
   - **QA bots:** use the **MCP tool** through the connector with your binding arguments (`projectApiKey`, `botId`), as for `approve-agentwatch-pairing`. The CLI's `--bot` key can't invite.
   - **Local agents:** works on the hosted MCP (OAuth). An API-key-only setup (stdio MCP / CLI with `TESTCHIMP_API_KEY`) gets 403. Then send the user the Team Settings link from the error (`<app>/team-settings`) to invite there.
4. Report each email's `outcome` in one line each:
   - `MCP_TEAM_INVITE_OUTCOME_INVITED`: invite email sent; they join as **Viewer**.
   - `…_ALREADY_MEMBER` / `…_ALREADY_INVITED`: nothing sent.
   - `…_FAILED`: show `failureReason` (seat limit, already in another organisation, …).
5. Errors for the whole call (HTTP 403): the user isn't an org admin (ask an org admin to invite them), or the Indie plan is single-user (upgrade link in the message). Share the link from the message; don't retry.
6. Point to `teamSettingsUrl` for changing roles (for example to Admin) or adding seats. Tell the user what invitees do next: accept the email, then run **`/testchimp init`** on their own machine (and set up their own QA bot if they use one).

### Phase 3 completion gate

Walk all required areas (+ optionals if planned):

- [ ] **Platform comms** — done + platform status updated.
- [ ] **Folder mapping** — markers, mapping, scaffold done.
- [ ] **Connect to test env** — policy/strategy documented.
- [ ] **CI** — workflow authored/verified or N/A.
- [ ] **Optional imports / smoke** — done / skipped / N/A.
- [ ] **Invite team members** (last) — offered; invited / skipped / blocked (with link given).

Call **`get-project-init-status`** — when `overall_complete` is true, project init is done.

---

## End state and completion rules

Project init is **complete** when:

- **`get-project-init-status`** reports `overall_complete: true` (all four required items **`PROJECT_INIT_ITEM_STATUS_DONE`**), **and**
- **`plans/knowledge/policies/connect-to-test-env.policy.md`** documents the env strategy (local-up / health / URLs; CI/Cloud as applicable) and has been upserted.

**Not required for completion:** `ai-test-instructions.md`, TrueCoverage, mocking plans, full seed endpoints, domain fixtures, ExploreChimp defaults — those land in later workflows (or remain optional legacy notes).

The team-invite offer ([§ 7](#7-final--invite-team-members)) comes before closing the run, but doesn't block completion.

Before treating the run as done, **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** with `workflowId` / `entityIdentity` **`project-init`** and the plan ULID (`ACTION_COMPLETED` / `ACTION_FAILED`).

---

## Post-init guidance

- Each developer: run **`/testchimp init`** on their machine. Teammates not invited yet: org admins invite from Team Settings (or ask an agent to use **`invite-team-members`**).
- If you hit a TestChimp bug or docs gap during this run, you may call **`send-feedback`** after telling the user what you will send and why. Do not send a ritual end-of-init report. If they decline that tool, finish the summary and stop.
- On demand: **`/testchimp test`** when a PR is ready.
- TrueCoverage: **`/testchimp setup truecoverage`** / **`/testchimp instrument`** when the team opts in.
- Ongoing: **`/testchimp upkeep`**; optional **`/testchimp cleanup`**.

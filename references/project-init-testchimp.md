# /testchimp project init

**One-time per project** (repo / team): **platform comms**, **folder mapping**, **connect-to-test-env**, **CI wiring**, plus optional imports and smoke validation. Runs in ChimpHands or a local agent workspace.

**Not** the per-developer workstation setup — that is [`init-testchimp.md`](./init-testchimp.md) (`/testchimp init`).

## Progress tracking (platform)

Use MCP tools (CLI ≥ **0.1.35**):

- **`get-project-init-status`** — read `ProjectInitStatus` (`platform_comms`, `folder_mapping`, `connect_to_test_env`, `ci_wiring`, optional `import_plans` / `import_tests` / `smoke_validation`, server-computed `overall_complete`).
- **`update-project-init-status`** — partial merge; server recomputes `overall_complete` when all **required** items are `DONE`.
- **`get-git-folder-mapping`** / **`update-git-folder-mapping`** — read/write mapped `plans/` and `tests/` paths on the platform after the agent scaffolds folders in a PR (branch prefix **`testchimp-`**).

**Required** for `overall_complete`: `platform_comms`, `folder_mapping`, `connect_to_test_env`, `ci_wiring`.

**Optional** (do not block completion): `import_plans`, `import_tests`, `smoke_validation`.

**Out of init scope** (separate workflows): TrueCoverage → **`/testchimp setup truecoverage`** / **`/testchimp instrument`**; mocking lock-down → during **`/testchimp test`** / create-tests per [`mocking_strategy.md`](./mocking_strategy.md); seed endpoint authoring → during test authoring per [`seeding-endpoints.md`](./seeding-endpoints.md).

Also persist durable decisions in **`plans/knowledge/ai-test-instructions.md`**.

---

> **Plan → approve → execute:** Mint a **ULID** `workflow_execution_id`, **write on disk** **`knowledge/workflow_plans/init/<workflow_execution_id>.plan.md`** (checklist of init action items), call **`upsert-plans-support-file`** with the **same** content (blocking), then seek **explicit user approval** before Phase 3 Execute — unless `--mode=non-interactive` or policy `allow-execute-without-approval`. Do not upsert-only: ChimpHands Files changed needs the local file. See [`policies-and-traceability.md`](./policies-and-traceability.md).

### Phase gating (required)

Between phases, **stop and complete the phase’s completion gate** before continuing. For **every** gate line: mark **done** (one-line evidence) or **`N/A`** + one-line justification. Record outcomes in **`plans/knowledge/ai-test-instructions.md`** and/or chat.

---

## Purpose

Project init wires the **shared** TestChimp integration for a repo: Git folder mapping, test environment strategy, and CI. It usually runs with `plans/` and `tests/` in the **same repo as the product** (recommended). It may also run in a **plans/tests-only mapped repo** when the team chose separation — see [`split-repo-workspaces.md`](./split-repo-workspaces.md).

Agents must:

1. collaborate on a concrete action plan first,
2. track progress via **`get-project-init-status`** / **`update-project-init-status`**,
3. persist decisions in `plans/knowledge/ai-test-instructions.md`,
4. execute each item methodically and update status after each completion.

### Source of truth: `plans/knowledge/ai-test-instructions.md`

Project-level decisions live here so teammates and agents share the same choices. At minimum, ensure:

```md
# TestChimp Init Progress

## Completed Items

## Pending Items

## Deferred Items

---
## Environment Provision Strategy

### Local - Test Authoring

### CI - Test Execution

## ExploreChimp

<!-- Optional: default sources / PR explore scope, product quirks. See references/run-explorechimp.md. -->

## Past learnings — authoring & validation (FAQ)

<!-- Q/A playbook for env blockers. See references/run-qa.md. -->
```

Keep this file **project-level only** (no per-laptop MCP progress — that belongs in `/testchimp init`).

### Two scopes: workstation vs project

| Scope | Command | What it covers |
|--------|---------|----------------|
| **Workstation** (per machine) | **`/testchimp init`** | Local MCP file, API key on this laptop, local stack smoke. See [`init-testchimp.md`](./init-testchimp.md). |
| **Project** (repo / team) | **`/testchimp project init`** | Platform comms verification, folder mapping, shared env strategy, CI, optional imports. |

A teammate may clone after project init is **`overall_complete`** and still need **`/testchimp init`** on their machine. Project init does **not** replace per-developer setup.

---

## Opening message (required, first user-facing step)

When **`/testchimp project init`** starts, set expectations before deep work:

- **During project init**, TestChimp wires **one-time project infrastructure**: Git **plans/tests folder mapping** (agent-driven via CLI), **test environment strategy** (`connect-to-test-env`), **CI execution**, then optional **import** of existing plans/tests and optional **smoke** authoring. Basic SmartTests scaffold (markers, Playwright/Mobilewright harness) lands with folder mapping — not a full test-authoring campaign.
- **Per developer**, each teammate runs **`/testchimp init`** once to register local MCP and verify their machine can run tests.
- **After setup**, the user mainly runs **`/testchimp test`** when a PR is ready; the agent runs the full QA workflow on demand.
- **Ongoing**, run **`/testchimp upkeep`** / **`/testchimp evolve`** for coverage gaps; **`/testchimp setup truecoverage`** when the team wants RUM analytics (not part of project init).

**Always** include: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

Then call **`get-project-init-status`** and report what is already **DONE** vs missing.

**Do not** ask about smoke validation (or author smoke tests) at the start. Critical setup first (`platform_comms` → `folder_mapping` → `connect_to_test_env` → `ci_wiring`); offer smoke only as an optional step with imports (Phase 1 optionals / Phase 3).

---

## Phase 1 — Requirement gather (discover → clarify)

Discover from repo + platform first; ask targeted questions only when discovery is ambiguous.

**Do not** write substantive `ai-test-instructions.md` sections until the user confirms defaults — except reading existing content when re-running init.

If **`get-project-init-status`** shows required items already **DONE**, treat Key Areas as **read-and-confirm** unless the user wants changes.

### Key Area 1 — Platform comms

Verify the **project** can talk to TestChimp APIs from this agent session (not every teammate’s laptop):

1. **`get-eaas-config`** `{}` — must **not** return **401** (empty config is OK).
2. **`get-project-init-status`** — baseline current progress.
3. Best-effort **`report-agent-action`** after connectivity succeeds:
   - `workflowId`: **`init`**, `workflowExecutionId`: fresh ULID, `actorType`: **`LOCAL_AGENT`**, `entityType`: **`WORKFLOW`**, `entityIdentity`: **`init`**, `actionType`: **`ACTION_COMPLETED`**
   - Omit secrets; failure must not block init.

If **401**: the API key is missing or invalid — ask the user to complete **`/testchimp init`** workstation MCP setup ([`init-testchimp.md`](./init-testchimp.md)) before continuing project init.

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
3. Open a PR on branch prefix **`testchimp-`**; get it merged.
4. Call **`update-git-folder-mapping`** with the merged paths (`plans_folder_path`, `tests_folder_path`, `repository_full_name` when needed).
5. Pull locally; confirm both markers exist.

**Fallback (CLI blocked or no Git integration yet):** Ask the user to connect the repo in TestChimp → Project Settings → Integrations → Git, map folders in the UI, merge platform sync PR(s), then pull so markers appear locally. Retry **`get-git-folder-mapping`** after.

Platform paths in MCP APIs use platform-rooted paths (`plans/...`, `tests/...`) even when repo folder names differ.

**Harness note:** Init scaffolds layout and deps; domain fixtures and seed endpoints are authored during **`/testchimp test`** / create-tests when scenarios require them.

### Key Area 3 — Connect to test environment

Why: agents and CI need a documented, repeatable way to provision and reach the app under test.

Agent discovery:

- Inspect CI/workflows and env files for `BASE_URL` / preview URL conventions.
- Check for **`plans/knowledge/policies/connect-to-test-env.policy.md`** (or frontmatter `workflow-id: connect-to-test-env`).
- Read **`## Environment Provision Strategy`** in `ai-test-instructions.md` if present.

Decide and record:

- **Local — Test Authoring:** single agent-runnable **local up** command + **wait-for-healthy** criteria + URL mapping (`BASE_URL`, backends).
- **CI — Test Execution:** persistent vs ephemeral (EaaS/Bunnyshell, Branch Management preview URLs, etc.) per [`environment-management.md`](./environment-management.md).

If no usable policy or env strategy exists, mark **Missing Config**, discuss with the user, and author/seed policy ([`create-policy.md`](./create-policy.md)) — **blocking** for env-dependent optional work (e.g. import `markScreenState`).

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

### Phase 1 completion gate

- [ ] **Key Area 1** — platform comms verified (`get-eaas-config` not 401); init status baseline read.
- [ ] **Key Area 2** — mapping state discovered; agent CLI path or fallback documented.
- [ ] **Key Area 3** — env strategy decided enough for Phase 2; connect-to-test-env policy gate satisfied or authoring planned.
- [ ] **Key Area 4** — CI discovery + intended direction recorded.
- [ ] **Optional imports / smoke** — nested / skipped / **N/A** with one-line justification each (smoke offered only alongside optionals, not before required areas).

---

## Phase 2 — Plan phase (four required areas + optionals)

Create **`## Init action items`** in `plans/knowledge/ai-test-instructions.md` (or the init `.plan.md` checklist) with **`status`**: `pending | in_progress | done | skipped | deferred`.

Your plan **must** include exactly these **four required** areas in order, plus optional items when applicable:

1. **Platform comms**
2. **Folder mapping** (includes scaffold / harness when needed)
3. **Connect to test environment**
4. **CI setup**

Optional (when planned): **Import plans**, **Import tests**, **Smoke validation**.

### Acceptance criteria

**Platform comms**

- `get-eaas-config` succeeds (not 401).
- `update-project-init-status` with `platform_comms: DONE` when complete.

**Folder mapping**

- **`get-git-folder-mapping`** reflects agreed paths.
- Both `.testchimp-plans` and `.testchimp-tests` exist on disk after merge + pull.
- SmartTests scaffold matches [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md); deps installed at SmartTests root.
- `update-project-init-status` with `folder_mapping: DONE` when complete.

**Connect to test environment**

- `connect-to-test-env` policy exists **or** substantive **`## Environment Provision Strategy`** in `ai-test-instructions.md`.
- Local-up command + health criteria documented for authoring.
- `update-project-init-status` with `connect_to_test_env: DONE` when complete.

**CI setup**

- Workflow authored, verified, or **N/A** with justification; runs from SmartTests root with `TESTCHIMP_API_KEY` and env strategy for `BASE_URL`.
- User informed how to trigger CI runs.
- `update-project-init-status` with `ci_wiring: DONE` when complete.

**Optional imports**

- Per [`import-plans.md`](./import-plans.md) / [`import-existing-tests.md`](./import-existing-tests.md); set `import_plans` / `import_tests` on platform when done.

**Optional smoke validation**

- 2–3 `@smoke` SmartTests authored and runnable against the documented local/test env, **or** skipped / **N/A** with justification.
- `update-project-init-status` with `smoke_validation: DONE` when smoke finishes successfully (optional — does not affect `overall_complete`).

After the plan is written, get **explicit user approval** before Phase 3.

### Phase 2 gate

- [ ] Four required areas (+ optionals) listed with acceptance criteria.
- [ ] User explicitly approved the plan.

---

## Phase 3 — Execution phase

Execute in order; after each area, verify acceptance criteria, call **`update-project-init-status`**, and update `ai-test-instructions.md`.

**PR strategy:** Ask whether the user wants **one combined PR** or **separate PRs** (mapping/scaffold, env docs, CI). Default to separate PRs when slices are large. Branch prefix **`testchimp-`**.

### 1. Platform comms

- Re-verify **`get-eaas-config`**.
- Best-effort **`report-agent-action`** (see Key Area 1).
- Mark `platform_comms: DONE`.

### 2. Folder mapping (+ scaffold / harness)

**CLI-first flow:**

1. **`get-git-folder-mapping`** — confirm or set target paths.
2. If markers missing — scaffold per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md):
   - Marker files, `setup/` / `e2e` or `web/e2e` + `mobile/e2e` / `api/`, fixture barrels ([`fixture-usage.md`](./fixture-usage.md)).
   - **Web:** `@playwright/test` ≥ 1.59.0, `@testchimp/playwright`, `@testchimp/cli` devDep, [`template_playwright.config.js`](../assets/template_playwright.config.js).
   - **Mobile:** `mobilewright`, `@mobilewright/test` (same version), mobilewright config templates.
3. PR → merge → **`update-git-folder-mapping`**.
4. Pull; confirm markers locally.

**Dependencies** (SmartTests root):

```bash
npm install @testchimp/playwright
npm install -D @testchimp/cli@latest
# mobile additionally: npm install mobilewright @mobilewright/test
```

**Fallback:** Manual platform Git integration + sync PRs (see Key Area 2) — only when CLI path failed.

Mark `folder_mapping: DONE` when markers + platform mapping align.

### 3. Connect to test environment

Follow [`connect-to-test-env.md`](./connect-to-test-env.md) / [`environment-management.md`](./environment-management.md):

- Author or confirm **`connect-to-test-env.policy.md`** when missing.
- Persist **`## Environment Provision Strategy`** (Local + CI subsections).
- For ephemeral EaaS: confirm `get-eaas-config` payload; Bunnyshell / Branch Management as applicable.

Mark `connect_to_test_env: DONE` when strategy is documented and verified (or policy + local-up contract exists for later provisioning).

### 4. CI setup

Follow [`configure-ci-test-execution.md`](./configure-ci-test-execution.md):

- Run from SmartTests root; `TESTCHIMP_API_KEY` in CI secrets; `TESTCHIMP_EXECUTION_SOURCE=CI` on pipeline jobs.
- Pass `BASE_URL` per env strategy; exclude plan-sync PRs titled `TestChimp Platform Sync [Plans]`.
- If nested import already authored CI — **verify only**, do not duplicate.
- **ChimpHands:** Pushing `.github/workflows/*` requires the TestChimp GitHub App **Workflows: Read & write** permission (Actions `GITHUB_TOKEN` cannot modify workflow files). If push is rejected for missing workflows permission, tell the user to grant that App permission, accept the install update, then **Install / refresh** the ChimpHands workflow and retry — do not suggest adding `permissions.workflows` to the workflow YAML (that key is invalid).

Mark `ci_wiring: DONE` when workflow exists or N/A is justified.

### 5. Optional — Import plans / Import tests

When approved in Phase 2:

- **Plans:** [`import-plans.md`](./import-plans.md) → `import_plans: DONE`.
- **Tests:** [`import-existing-tests.md`](./import-existing-tests.md) → `import_tests: DONE`; run `markScreenState` only after connect-to-test-env is ready.

### 6. Optional — Smoke validation

When approved in Phase 2 — **only after** steps 2–3 (folder mapping + connect-to-test-env) are **DONE**:

- Author 2–3 critical-path SmartTests (`@smoke` when suite tags exist); run them against the documented local/test env when feasible.
- Record learnings in **`## Past learnings — authoring & validation (FAQ)`** if useful.
- Mark `smoke_validation: DONE` on success, or record skip / **N/A**.

Do **not** reorder smoke ahead of required areas.

### Phase 3 completion gate

Walk all required areas (+ optionals if planned):

- [ ] **Platform comms** — done + platform status updated.
- [ ] **Folder mapping** — markers, mapping, scaffold done.
- [ ] **Connect to test env** — policy/strategy documented.
- [ ] **CI** — workflow authored/verified or N/A.
- [ ] **Optional imports / smoke** — done / skipped / N/A.

Call **`get-project-init-status`** — when `overall_complete` is true, project init is done.

---

## End state and completion rules

Project init is **complete** when:

- **`get-project-init-status`** reports `overall_complete: true` (all four required items **DONE**), **and**
- `plans/knowledge/ai-test-instructions.md` records env strategy, CI trigger guidance, and any deferred optional items.

**Not required for completion:** TrueCoverage, mocking plans, full seed endpoints, domain fixtures, ExploreChimp defaults — those land in later workflows.

---

## Post-init guidance

- Each developer: run **`/testchimp init`** on their machine.
- On demand: **`/testchimp test`** when a PR is ready.
- TrueCoverage: **`/testchimp setup truecoverage`** / **`/testchimp instrument`** when the team opts in.
- Ongoing: **`/testchimp upkeep`**; optional **`/testchimp cleanup`**.

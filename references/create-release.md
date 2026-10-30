# `/testchimp create release`


> **Plan → approve → execute → report:** Write `knowledge/workflow_plans/create-release/<workflow_execution_id>.plan.md`, call **`upsert-plans-support-file`** (blocking), then require explicit user approval before Execute (unless `--mode=non-interactive` or policy `allow-execute-without-approval`). Before finishing, run **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** (`ACTION_COMPLETED` with `WORKFLOW` + `create-release`, or `ACTION_FAILED` on hard failure). Nested subflows reuse this parent plan (parent closes). See [`policies-and-traceability.md`](./policies-and-traceability.md).

**Workflow id:** `create-release`

**Canonical prompt:** `/testchimp create release <label> <MAJOR|MINOR|HOTFIX>`

**Synonyms:** `/testchimp create a major|minor|hotfix release tagged <label>`, plain “create a release…”.

**Depends on:** [`connect-to-test-env`](./connect-to-test-env.md) when local suite / ExploreChimp / DAST runs need an environment.

**Policy:** `plans/knowledge/policies/create-release.policy.md` (or `--policy` / matching frontmatter). Seed skeleton: [`../assets/policies/create-release.policy.md`](../assets/policies/create-release.policy.md).

**Requires `@testchimp/cli` ≥ 2.0.3** for `upsert-release` `focusAreas` and **`create-security-scan`**.

This is the compound workflow for **creating a release and getting release QA posture**. Suite maintenance alone stays [`upkeep`](./upkeep.md); this workflow may nest upkeep when policy says so.

---

## Purpose

1. Lock release **label**, **type** (`MAJOR` \| `MINOR` \| `HOTFIX`), **tag convention**, **scope**, and **create-release policy**.
2. Create the catalog release (`upsert-release`) with `gitCommitSha` and focus-area scope.
3. Create a named test run on that release.
4. Drive policy-selected nested QA actions so the suite has executed for the release (CI attach or local).
5. Summarise release QA posture (`get-release` `detail=GATE` + `get-qa-posture`).

---

## Policy vs seed (do not collide)

- Skill asset banner: **`[SEED POLICY - REQUIRE USER DECISIONS TO LOCK-IN]`**.
- Project policy is authoritative **only after lock-in** (no seed banner; matrix filled).
- Treat as **unlocked** when the project file is missing, still has the seed banner, or decision keys are blank/TBD.
- On unlock: **do not** silently apply skill-asset defaults. Propose the recommended matrix (below), explain per type, offer **Accept recommended defaults** | **Customize**. On accept/customize → write project policy **without** the seed banner → **`upsert-policy`** → continue.
- Never start nested QA actions until the project policy is locked.

### Recommended defaults (playbook proposal — not pre-filled in the seed file)

| Type | Scope | Actions |
|------|-------|---------|
| **MAJOR** | `full` | `upkeep` yes; suite `full`; `explorechimp` yes; perf = `upkeep-perf` + `run-perf-tests`; security static **and** DAST |
| **MINOR** | `changed` | suite `smart-smoke`; `explorechimp` yes; perf = `run-perf-tests` only; security off |
| **HOTFIX** | `changed` | suite `smart-smoke` only |

**Suite CI rule (Execute):** If the project already has SmartTests CI wiring, prefer `manage-test-run` **FIND → LINK** for batches since the prior release cut and skip a redundant local run when coverage is already attached. Else run locally (`execute-tests` for full / `run-smart-smoke` for smart-smoke) with **`TESTCHIMP_RELEASE`** and **`TESTCHIMP_TEST_RUN_ID`**. Write policy as `full` / `smart-smoke`; CI preference is runtime behaviour.

**DAST:** always ask the user before `create-security-scan` + `run-release-check`, even when policy enables it (can be dangerous). Static scanners may proceed without a second confirm when policy enables them.

---

## Phase A — Interactive lock-in (before Plan file)

1. **Parse** label + type from the prompt. Missing → ask (prefer **`ask-user-question-async`** when available / cloud).
2. **`get-release`** with **no** `version` (list). If the label **already exists** → **stop and inform** the user. Do not silent-update. Continue as update only if they explicitly confirm.
3. If label missing: suggest the next tag from the latest catalog label + any locked **tag convention**; if convention unset, ask and lock it into the project policy (`### Tag convention`).
4. **`gitCommitSha`:** current `HEAD` (or user-supplied SHA). Always send on create. Resolve **`priorReleaseVersion`** from the list (latest prior when sensible).
5. **Scope** from locked policy (MAJOR `full` / MINOR+HOTFIX `changed`). If unlocked, include scope in the accept-defaults write.
   - **`full`:** omit `focusAreas` on create (full scenario set). Do not send an empty array to “clear” on update — empty/omit leaves existing focus areas unchanged.
   - **`changed` (best-effort):** prior SHA → cut SHA git diff → map touched plans/scenarios to `FileScope` focus areas (`folderPath` + `artifactType: SCENARIO_ARTIFACT` when known). **State clearly** that this is best-effort and that **MAJOR should prefer full**.
6. **Policy gate:** if unlocked → propose recommended defaults (table above) in plain language → Accept / Customize → write locked project policy (no banner) + **`upsert-policy`**.

---

## Phase B — Plan → approve

1. Mint ULID `workflow_execution_id`.
2. Write `knowledge/workflow_plans/create-release/<workflow_execution_id>.plan.md` with the locked label/type/scope/policy actions checklist.
3. **`upsert-plans-support-file`** (blocking).
4. Explicit user approval unless `--mode=non-interactive` or policy allows non-interactive.

---

## Phase C — Must-do Execute

1. **`upsert-release`** with `version`, `gitCommitSha`, `priorReleaseVersion`, `releaseType`, and `focusAreas` when scoped. Check response `created`; if not created and user did not approve update, stop.
2. **`manage-test-run`** omit `id`, pass `release` (= version), optional title e.g. `Create release <label>`. Keep the returned **`id`** as `TESTCHIMP_TEST_RUN_ID` for later runs.

---

## Phase D — Policy-driven nested actions

Follow the **project** policy for this release type. Nest existing playbooks; reuse the parent plan (no second approval cycle unless the nested playbook requires a hard confirm such as DAST).

### Upkeep

When policy says yes (default MAJOR): nest [`upkeep.md`](./upkeep.md).

### Suite execution

Responsibility: the release must have executed coverage.

1. If CI SmartTests wiring exists → `manage-test-run` with `id` + `commitRange: FIND` → show discovered batches → `commitRange: LINK` (or explicit ids after user OK when interactive). Prefer this over a redundant local full suite when batches already cover the cut.
2. Else:
   - `full` → nest [`execute-tests.md`](./execute-tests.md) for release scope.
   - `smart-smoke` → nest [`run-smart-smoke.md`](./run-smart-smoke.md) scoped to prior→cut.
3. Always export on local runners: **`TESTCHIMP_RELEASE=<label>`** and **`TESTCHIMP_TEST_RUN_ID=<id>`**.

### ExploreChimp

When policy says yes (default MAJOR + MINOR): nest [`run-explorechimp.md`](./run-explorechimp.md) targeting the release (prior→cut + `TESTCHIMP_RELEASE`).

### Perf

When policy enables:

- MAJOR (`upkeep-and-run`): nest [`upkeep-perf.md`](./upkeep-perf.md) then [`run-perf-tests.md`](./run-perf-tests.md) for the release.
- MINOR (`run`): nest [`run-perf-tests.md`](./run-perf-tests.md) only.
- HOTFIX / `never`: skip.

### Security (default MAJOR only)

For each enabled checker:

1. **`create-security-scan`** with `version` + exactly one check config (`sastCheckConfig` / `depsCheckConfig` / `leaksCheckConfig` / `dastCheckConfig`).
2. Nest [`run-release-check.md`](./run-release-check.md) / `/testchimp run security scan for <scanId>`.

**DAST:** ask first every time. Statics may proceed when `security_static: yes`.

Suggested static defaults when creating scans (adjust to project norms): release-scoped SAST/deps/secrets with baseline = prior release SHA when available.

---

## Phase E — Close

1. **`get-release`** `--release '<label>'` `--detail GATE`.
2. **`get-qa-posture`**.
3. Summarise for the user: release label/type/cut, scope, test-run status, suite coverage posture, ExploreChimp/perf/security highlights, open blockers, and next recommended action.
4. **[Report workflow execution](./policies-and-traceability.md#report-workflow-execution)** — `ACTION_COMPLETED` with `WORKFLOW` + `create-release`.

---

## Completion gate

- [ ] Label + type locked; existing label handled (inform / stop unless user confirmed update)
- [ ] Tag convention locked when previously unset
- [ ] Project `create-release.policy.md` locked (no seed banner) before nested actions
- [ ] Release created/updated with `gitCommitSha` (+ `focusAreas` when changed-scope)
- [ ] Named test run created on the release
- [ ] Suite coverage ensured (CI LINK and/or local execute / smart-smoke with release + test-run env tags)
- [ ] Nested ExploreChimp / perf / security only when policy enables; DAST always confirmed
- [ ] GATE + QA posture summarised to the user
- [ ] Workflow execution reported

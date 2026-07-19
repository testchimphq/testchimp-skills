# Platform scope (mobile & multi-platform)

When **`project_type`** in **`.testchimp-tests`** is **`mobile`** or **`multi-platform`** (legacy **`ios`/`android`** → **`mobile`**), agents must treat **platform** (`web`, `ios`, `android`) as an explicit scope decision for **PR-branch** work—not an implicit default.

**Applies to:** **`/testchimp test`** (Analyze through Phase 6) and **`/testchimp explore`** (standalone or Phase 6). **Web-only** projects (`project_type` empty or **`web`**) skip this file except where a repo still has optional native paths.

**Does not replace:** per-spec **`--project`** / Mobilewright **`use.platform`** ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)); coverage MCP/CLI **`--platform`** ([`cli.md`](./cli.md)).

---

## PR-branch rule (blocking before Plan approval)

On a **PR branch** (feature branch with a PR diff vs base, or the user’s stated branch scope):

1. **Resolve platforms in scope** for this run (see [Deduction](#deduction-signals) below).
2. **If confidence is high** — **tell the user** which platform(s) you selected and **why** (evidence bullets from diff, paths, or plan). Proceed only after that message (user may correct you before approving the Plan).
3. **If confidence is low or mixed** — **ask the user** which platform(s) to include: **`web`**, **`ios`**, **`android`** (one or more). Do **not** assume “run everything” unless the user confirms or the PR clearly touches all stacks.
4. **Persist** the decision in the branch plan (see [Branch plan section](#branch-plan-section)) and reuse it on reruns unless the PR diff or user overrides.

**User correction:** If the user narrows or expands platforms after your deduction, update the branch plan and re-scope tests, regression, ExploreChimp, and coverage queries.

---

## Deduction signals

Use **PR diff vs base** (`origin/main...HEAD` or equivalent) plus **touched SmartTests** and **plans** context. Prefer **strong** signals; when signals conflict, treat as **ambiguous** and **ask**.

| Signal | Suggests |
|--------|----------|
| Changes only under `web/`, `e2e/` (web config), `playwright.config.js`, web-only app paths | **`web`** |
| Changes only under `mobile/e2e/ios/`, iOS app/Xcode, `use.platform: 'ios'`, iOS RUM/TrueCoverage | **`ios`** |
| Changes only under `mobile/e2e/android/`, Android app/Gradle, `use.platform: 'android'`, Android RUM | **`android`** |
| Shared `api/`, `shared/`, backend, or cross-cutting product logic with **no** platform-specific UI/tests | **Ambiguous** — ask |
| Multi-platform **product** UX (e.g. execution platform selector) but **tests** only touch one tree | **Ambiguous** — ask (product change may still need multi-platform validation) |
| Explicit user focus (“iOS only”, “web regression”) | Use user scope |

**Weak signals alone are not enough** to skip asking: e.g. “mostly web files” with one shared util, or a single line in a multi-platform component.

**High-confidence examples (inform user, then continue):**

- PR only updates `mobile/e2e/ios/login.spec.js` and iOS fixture → **`ios`**
- PR only updates `web/e2e/checkout.spec.js` → **`web`**
- PR updates both `mobile/e2e/ios/` and `mobile/e2e/android/` with matching product changes → **`ios`** + **`android`**

---

## Branch plan section

For **`mobile`** / **`multi-platform`**, the branch plan MUST include a top-level section (after change summary, before or within Plan inventory):

```md
## Platform scope (this run)

- **Decision:** `web` | `ios` | `android` | comma-separated list
- **Confidence:** `high` | `low` (if `low`, user was asked before Plan approval)
- **Rationale:** 1–3 bullets (paths, features, user reply)
- **User confirmed:** yes | pending (must be `yes` before Execute)
```

- **Analyze:** Draft **Decision** + **Rationale**; set **User confirmed** to `pending` if you asked.
- **Plan:** Do not request final Plan approval until **User confirmed: yes** (or user explicitly approves the plan text that embeds the platform list).
- **Execute / Validate / Phase 5 / Phase 6:** Run and report only scoped platforms; use `--project` / `--platform` filters per [`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md) and [`cli.md`](./cli.md).
- **Rerun:** Re-read this section; re-ask if the PR diff materially changes platform surface.

---

## `/testchimp test` workflow hooks

| Phase | Action |
|-------|--------|
| **Analyze** | Read **`.testchimp-tests`** `project_type`. If mobile/multi-platform, perform [Deduction](#deduction-signals); write **Platform scope** draft in branch plan. **Ask or inform** per [PR-branch rule](#pr-branch-rule-blocking-before-plan-approval). |
| **Plan** | Every inventory test row notes **platform** (`web` / `ios` / `android`). Smart regression **§6** and ExploreChimp **§7** lists are **filtered** to scoped platforms. Coverage/history queries use `--platform` when analyzing one stack ([`run-qa.md`](./run-qa.md) Analyze inputs). |
| **Execute → Phase 6** | Do not run iOS/Android projects outside scope; do not skip a scoped platform without plan update + user ack. |

**Phase 1 completion gate** (mobile/multi-platform): add checklist item — **Platform scope** drafted, user informed or asked, and **User confirmed** recorded (or `N/A` — **web-only** project only).

---

## `/testchimp explore` workflow hooks

Before choosing tests or setting **`EXPLORECHIMP_ENABLED`**:

1. Apply the same [PR-branch rule](#pr-branch-rule-blocking-before-plan-approval) and [Deduction](#deduction-signals).
2. **Inform** the user of the platform(s) ExploreChimp will run on (and rationale), or **ask** if ambiguous.
3. Restrict runs to UI specs and Mobilewright **`--project`** values in scope (`web` → Playwright web project; `ios` / `android` → matching `use.platform`).
4. When exploration is part of **`/testchimp test` Phase 6**, use the branch plan **Platform scope** + **§7** target list—intersection only.

Standalone **`/testchimp explore`**: if there is no branch plan yet, still **inform or ask** before the first batch; optionally append **Platform scope** to the branch plan file for consistency.

---

## Messaging templates (user-facing)

**High confidence (inform):**

> **Platform scope:** I’m limiting this run to **`ios`** because the PR only touches `mobile/e2e/ios/…` and iOS app sources. Say if you also want **web** or **android** covered.

**Low confidence (ask):**

> **Platform scope:** The PR changes shared API logic and multi-platform UI copy; I can’t tell whether you want **web**, **iOS**, **Android**, or a combination. Which platform(s) should I test and run ExploreChimp on for this branch?

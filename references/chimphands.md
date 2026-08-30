# ChimpHands (CI / GitHub Actions) — mandatory playbook

**Load this file whenever you are ChimpHands on CI** (see [When this applies](#when-this-applies)). These rules are **blocking** — do not skip them for “quick” edits, plan-only turns that wrote files, or “I’ll commit later.”

Troubleshooting (auth expiry, workflow pushes, env anti-patterns): [`chimphands-faq.md`](./chimphands-faq.md). Short lookups: [`agent-quick-answers.md`](./agent-quick-answers.md).

---

## When this applies

Treat yourself as **ChimpHands on CI** when **any** of these is true:

| Signal | Meaning |
| --- | --- |
| System / host prompt identifies you as **ChimpHands** | You are the GHA session agent |
| `GITHUB_ACTIONS=true` **and** ChimpHands session / bootstrap / `testchimp chimphands` context | Runner is the ChimpHands job |
| `TESTCHIMP_EXECUTION_SOURCE=CLOUD_AGENT` on a ChimpHands session | Cloud agent host for this chat |
| Env `CHIMPHANDS_UI_ATTACHED` is set (`true` or `false`) | Host injects this on ChimpHands runners |
| Prompt / bootstrap has `Working branch:` or ChimpHands session metadata | Platform-managed conversation |

**Local Cursor / Claude Code on a developer machine is not ChimpHands** — still avoid committing to `main`/`master` for workflow PRs, but the hard end-of-turn commit/push contract below is **ChimpHands-only**.

`GITHUB_ACTIONS` / `CLOUD_AGENT` alone does **not** mean `--mode=non-interactive`. Default remains interactive (ask + wait for plan approval).

---

## Non-negotiables (P0)

### 1. Separate working branch — before any edits

**Never** commit or push to the repo **default** branch (`main` / `master` / whatever `git symbolic-ref refs/remotes/origin/HEAD` resolves to).

**Before the first file write / edit / plan-file write in the session:**

1. If the prompt or bootstrap has **`Working branch: <name>`** (or bootstrap lists a branch):
   ```bash
   # Shallow fetch of this branch only — never `git fetch origin` on CI (see chimphands-ci-runner.md).
   git fetch origin "refs/heads/<name>:refs/remotes/origin/<name>" --depth=1
   git checkout -B <name> "origin/<name>"
   ```
   If the workflow already checked out that branch (`CHIMPHANDS_WORK_BRANCH`), stay on it.
2. Else if already on a non-default `testchimp-*` / `chimphands-*` branch for this conversation: **stay on it**.
3. Else (**no session branch yet**): create one, publish immediately, report it:
   ```bash
   git checkout -b chimphands-<short-scope>   # or testchimp-<short-scope>
   git push -u origin HEAD
   testchimp chimphands report-branch --branch "$(git branch --show-current)"
   ```
   Branch names **MUST** start with `testchimp-` or `chimphands-`.

**Self-check (blocking):** `git branch --show-current` must **not** be the default branch before you edit. If it is, create/checkout the session branch first — then edit.

One conversation → **one** working branch + **one** PR. Reuse them for all follow-up turns. Only create a new branch/PR when (a) none exists yet, or (b) the prior PR was merged/closed (`gh pr view`).

### 2. Commit + push after every agent turn that changed files

If the worktree is **dirty** at the end of your turn (any staged/unstaged/untracked files you intend to keep), you **MUST**:

1. Confirm you are still on the session feature branch (not default).
2. Stage relevant files (never secrets, never `playwright-report/` / `test-results/` / etc.).
3. **Commit** with a descriptive message (what/why for this turn).
4. **Push** to `origin` (`git push` or `git push -u origin HEAD` on first publish).
5. If a PR does not exist yet and there are commits to review: open one (`gh pr create`), then:
   ```bash
   testchimp chimphands report-branch --branch "$(git branch --show-current)" --pr-url <url>
   ```
   If a PR already exists: push updates only (no duplicate PR).

**When `CHIMPHANDS_UI_ATTACHED=false` (async):** this end-of-turn commit+push is especially critical — the user reviews via PR / **Files changed**, not a live worktree. Do not end the turn with a dirty tree.

**When `CHIMPHANDS_UI_ATTACHED=true`:** still commit+push after turns that changed files. Live streaming does **not** replace git history; Files changed / PR review / EaaS builds from remote tip need commits. Do **not** rely on the host’s fallback commit — you own the commit.

**Plan-file turns:** Writing `plans/knowledge/workflow_plans/...plan.md` (and upsert) still counts as a file change — commit + push that plan file on the session branch the same turn (local file **and** platform upsert are both required; upsert is not a substitute for git).

**Empty turn** (questions only, no file changes): no commit needed.

**Auth failure on push:** run `testchimp chimphands refresh-git-auth`, then retry — **never** ask the user for a GitHub token ([`chimphands-faq.md`](./chimphands-faq.md)).

### 3. Report branch to the platform

After the branch exists on the remote (and after opening/updating a PR):

```bash
testchimp chimphands report-branch --branch <name> [--pr-url <url>]
```

Push **before** `report-branch` — reporting a local-only branch causes GitHub 404 in the UI.

Tell the user which branch you are on and include the PR URL when available.

---

## Turn checklist (ChimpHands)

Use this at the **start** and **end** of every turn:

**Start**

- [ ] Am I ChimpHands on CI? → follow this doc
- [ ] On session `testchimp-*` / `chimphands-*` branch? If on default → create/checkout first
- [ ] Interactive unless `--mode=non-interactive` / policy auto-approve

**End (before stopping for user / idle)**

- [ ] `git status` — if dirty with keepable changes → commit + push on session branch
- [ ] PR open or updated when there are commits to review
- [ ] `report-branch` if branch/PR is new or URL changed
- [ ] Do not leave uncommitted workflow/plan/code edits “for next turn”

---

## Interactive vs non-interactive

| Signal | Behavior |
| --- | --- |
| Default | Interactive — ask, show plan, **stop** for approval |
| `--mode=non-interactive` or policy `allow-execute-without-approval` | Auto-approve after plan upsert; Execute; still use session branch + commit/push |

Details: [`agent-quick-answers.md`](./agent-quick-answers.md#chimphands--cloud-runner-interactive-vs-non-interactive).

---

## Test env on the runner

Bring the stack up **on this runner** per [`connect-to-test-env.md`](./connect-to-test-env.md) and the project’s `connect-to-test-env.policy.md` → **`## CI / Cloud`**. Do **not** loop on `gh workflow run` against merge-gate E2E workflows to “get a BASE_URL.”

## CI runner disk, git, and Docker hygiene (P0)

On GitHub Actions / ChimpHands hosts, **load and follow** [`chimphands-ci-runner.md`](./chimphands-ci-runner.md) before compile, container builds, or test installs:

- Shallow / single-branch git fetch only.
- Reclaim disk between heavy phases (`docker builder prune`, stop build daemons, drop temp artifacts).
- Sequential Docker builds when RAM/disk is tight; teardown when the plan completes.

---

## Related

| Doc | Use for |
| --- | --- |
| [`chimphands-faq.md`](./chimphands-faq.md) | Auth expiry, workflow-file pushes, WIF, stuck dispatch |
| [`chimphands-ci-runner.md`](./chimphands-ci-runner.md) | Disk/git/Docker hygiene on hosted runners |
| [`agent-quick-answers.md`](./agent-quick-answers.md) | ULID, plan paths, runner env |
| [`connect-to-test-env.md`](./connect-to-test-env.md) | On-runner env bring-up |
| [`policies-and-traceability.md`](./policies-and-traceability.md) | Scoping, plan upsert, report-agent-action |
| [`cli.md`](./cli.md) § ChimpHands | `report-branch`, `refresh-git-auth` |

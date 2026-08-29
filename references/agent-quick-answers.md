# Agent quick answers

Short answers for recurring workflow mechanics. When a step below applies, **use the answer directly** — run the command, follow the path, or apply the rule. Use normal planning for product scope, test strategy, and ambiguous user intent.

See also [`SKILL.md`](../SKILL.md) and workflow playbooks under `references/`.

**ChimpHands on CI:** For branch creation + end-of-turn commit (mandatory), load [`chimphands.md`](./chimphands.md) — do not rely on the short tables below alone.

---

## Mint `workflow_execution_id` (ULID)

| If | Then |
| --- | --- |
| Prompt already has `--workflow-execution-id <ulid>` or `workflow-execution-id: <ulid>` | **Reuse it** — never mint a second id for the same run. |
| Plan filename is `…/workflow_plans/<workflow-id>/<ulid>.plan.md` | **Reuse** that ULID from the path. |
| Otherwise | Run **`npx --yes ulid`** (Node is on GHA runners and typical dev machines). Use stdout (trimmed) as the id. |

Do **not** invent ids or write one-off ULID scripts. One ULID per workflow run; reuse on every `report-agent-action` and mutating MCP call in that run.

Full contract: [`policies-and-traceability.md`](./policies-and-traceability.md#ulid-before-execute).

---

## Workflow plan file path

| Field | Value |
| --- | --- |
| Relative path (for `upsert-plans-support-file`) | `knowledge/workflow_plans/<workflow-id>/<workflow_execution_id>.plan.md` |
| On disk | Under the **mapped plans root** (folder with `.testchimp-plans`), create parent dirs as needed |
| Order | **Write local file first**, then `upsert-plans-support-file` with the **same** content (blocking before Execute) |

Leading `plans/` in CLI paths is stripped automatically — pass path relative to mapped root.

---

## Read an existing named plan

1. **`get-plans-support-file`** (platform first).
2. When `found: true`, write `content` to the mapped local path.
3. Reuse ULID from filename/prompt; do not mint a new one.

---

## ChimpHands / cloud runner: interactive vs non-interactive

| Signal | Mode |
| --- | --- |
| Default (ChimpHands UI, GHA, `CLOUD_AGENT`) | **Interactive** — ask questions, show plan, **stop** for approval |
| Prompt contains `--mode=non-interactive` (or policy `allow-execute-without-approval`) | Auto-approve after plan upsert; then Execute |

`GITHUB_ACTIONS` / “running in CI” does **not** mean skip approval by itself.

### UI attached vs async (no live browser)

| Signal | Meaning |
| --- | --- |
| `CHIMPHANDS_UI_ATTACHED=true` (env) or bootstrap `ui_attached: true` | A browser tab has the ChimpHands session open — live streaming + worktree VCS diffs work |
| `CHIMPHANDS_UI_ATTACHED=false` | **Async** — runner is up but nobody is watching live. End-of-turn commit+push is critical for PR / **Files changed** |
| `GITHUB_ACTIONS` / `TESTCHIMP_EXECUTION_SOURCE=CLOUD_AGENT` | Where you execute — **not** the same as UI attached |

**Always** commit + push at end of any ChimpHands turn with a dirty worktree (UI attached or not). Full contract: [`chimphands.md`](./chimphands.md). Host fallback commit exists — do **not** rely on it.

---

## Working branch and PR (ChimpHands)

**Canonical:** [`chimphands.md`](./chimphands.md) (blocking). Quick remap:

| If | Then |
| --- | --- |
| About to edit and on default branch | **Stop** — create/checkout `testchimp-*` / `chimphands-*` first |
| Prompt has `Working branch: <name>` or bootstrap lists a branch | `git fetch && git checkout <name>` — reuse for all turns |
| No working branch yet | Create `testchimp-*` or `chimphands-*`, **`git push -u origin <branch>`**, then `report-branch` |
| End of turn with dirty worktree | **Commit + push** on the session branch (plan files included) |
| After push / PR open | `testchimp chimphands report-branch --branch <name> [--pr-url <url>]` |
| `git` / `gh` auth failure | **`testchimp chimphands refresh-git-auth`** then retry — never ask the user for a token ([`chimphands-faq.md`](./chimphands-faq.md)) |

Never commit to default branch. One branch + one PR per conversation unless the prior PR was merged/closed.

---

## ChimpHands playbook + FAQ (CI / cloud)

| Doc | Use |
| --- | --- |
| **[`chimphands.md`](./chimphands.md)** | Mandatory branch + end-of-turn commit/push |
| [`chimphands-faq.md`](./chimphands-faq.md) | Auth expiry, workflow-file pushes, stuck dispatch, self-heal |

**Need a test env on ChimpHands** (author / run / fix tests): follow [`connect-to-test-env.md`](./connect-to-test-env.md) and the project’s **`## CI / Cloud`** policy section — bring the stack up **on this runner**. Do **not** loop on `gh workflow run` against merge-gate E2E workflows. Persist bring-up learnings back into that policy section.

---

## MCP vs CLI

| Order | Action |
| --- | --- |
| 1 | **MCP tools** (preferred) |
| 2 | **`testchimp` CLI** only if MCP fails — after exporting MCP `env` (`TESTCHIMP_API_KEY`, `TESTCHIMP_BACKEND_URL`, `TESTCHIMP_INGRESS_URL`) into the shell |

Never narrate API results without tool output.

---

## Mapped `plans/` and `tests/` roots

- Find **`.testchimp-plans`** / **`.testchimp-tests`** marker files (walk up from cwd).
- Platform paths always use logical prefix **`plans/…`** even when the repo folder has a different name (e.g. `ui/plans`).
- `upsert-plans-support-file --file-path` is relative to the mapped plans root.

---

## Playwright / Mobilewright runner env

Before spawning the test runner on ChimpHands / GHA:

```bash
export TESTCHIMP_EXECUTION_SOURCE=CLOUD_AGENT
# Plus TESTCHIMP_API_KEY, TESTCHIMP_BACKEND_URL, TESTCHIMP_INGRESS_URL from project MCP env
```

Never pass CLI `--reporter` (drops `@testchimp/playwright` reporter). See `SKILL.md` Preamble **#4** and **#8**.

---

## Git SHA for plan frontmatter (`LastRunOnCommit`, scope)

Use the real commit — **never fabricate** a SHA:

```bash
git rev-parse HEAD
```

For branch scope vs default branch, use merge-base / `git log` as in [`policies-and-traceability.md`](./policies-and-traceability.md#scoping-overarching--all-workflows).

---

## `/testchimp` composer command → `workflow-id`

| User command (after `/testchimp`) | `workflow-id` |
| --- | --- |
| `project init` | `init` |
| `author plan` | `author-plans` |
| `run qa` / `test` | `run-qa` |
| `upkeep` / `evolve` | `upkeep` |
| `create tests` | `create-tests` |
| `explore` | `run-explorechimp` |
| `create perf tests` | `create-perf-tests` |
| `run perf tests` | `run-perf-tests` |
| `implement …` | `implement` |

Plan path pattern: `knowledge/workflow_plans/<workflow-id>/<ulid>.plan.md`.

---

## What belongs here vs elsewhere

| Normal planning | Quick answers below |
| --- | --- |
| Product design, test strategy, scope tradeoffs | ULID mint, plan path, branch checkout, MCP vs CLI, runner env |
| Ambiguous user intent | Preamble checks in [`SKILL.md`](../SKILL.md) |
| ChimpHands branch / end-of-turn commit | [`chimphands.md`](./chimphands.md) |
| ChimpHands GHA auth / CI self-heal | [`chimphands-faq.md`](./chimphands-faq.md) |
| Test env bring-up (local or ChimpHands) | [`connect-to-test-env.md`](./connect-to-test-env.md) + `plans/knowledge/policies/connect-to-test-env.policy.md` |
| Repo-specific env / bring-up blockers | `plans/knowledge/ai-test-instructions.md` FAQ (see [`run-qa.md`](./run-qa.md#binding-ai-test-instructions-environment-and-faq-playbook)) |

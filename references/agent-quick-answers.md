# Agent quick answers

Short answers for recurring workflow mechanics. When a step below applies, **use the answer directly** — run the command, follow the path, or apply the rule. Use normal planning for product scope, test strategy, and ambiguous user intent.

See also [`SKILL.md`](../SKILL.md) and workflow playbooks under `references/`.

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

---

## Working branch and PR (ChimpHands)

| If | Then |
| --- | --- |
| Prompt has `Working branch: <name>` or bootstrap lists a branch | `git fetch && git checkout <name>` — reuse for all turns in the session |
| No working branch yet | Create `testchimp-*` or `chimphands-*`, **`git push -u origin <branch>`** before `testchimp chimphands report-branch` |
| After push / PR open | `testchimp chimphands report-branch --branch <name> [--pr-url <url>]` |

Never commit to default branch. One branch + one PR per ChimpHands conversation unless the prior PR was merged/closed.

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
| Repo-specific env / bring-up blockers | `plans/knowledge/ai-test-instructions.md` FAQ (see [`run-qa.md`](./run-qa.md#binding-ai-test-instructions-environment-and-faq-playbook)) |

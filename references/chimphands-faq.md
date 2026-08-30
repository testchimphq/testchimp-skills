# ChimpHands FAQ (CI / cloud runner)

Common issues when ChimpHands runs on GitHub Actions. **Self-fix first** — do not ask the user to paste secrets or “reconnect a GitHub token” in chat.

**Mandatory branch + commit contract (load first):** [`chimphands.md`](./chimphands.md) — separate `testchimp-*` / `chimphands-*` branch before edits; commit + push at the end of every dirty turn. This FAQ is troubleshooting only.

See also: [`agent-quick-answers.md`](./agent-quick-answers.md) (interactive mode, UI attached, short remap).

---

## GitHub App installation token expired (~1 hour)

### Symptom

`git push`, `gh pr create`, or `gh` API calls fail with auth errors after the session has been alive a long time (idle wait, long turns, or job > ~1h):

- `Authentication failed` / `Invalid username or password`
- `HTTP 401` / `403` / `write access not granted`
- `remote: Permission to … denied`

### Cause

At job start, the ChimpHands workflow mints a short-lived **TestChimp GitHub App installation token** via `POST /api/chimphands/github_write_token` (~**1 hour** TTL) and sets `GH_TOKEN` / `GITHUB_TOKEN`. Long-lived interactive jobs can outlive that token. This is **not** a user OAuth token and there is nothing to paste into chat.

### Fix (mandatory — agent self-heal)

**Preferred (CLI ≥ 0.1.66):**

```bash
testchimp chimphands refresh-git-auth
# then retry the failed git / gh command
```

Requires `TESTCHIMP_API_KEY` (and `TESTCHIMP_BACKEND_URL` when configured) — already present on ChimpHands runners.

The command:

1. Remints via `/api/chimphands/github_write_token`
2. Applies credentials for this process / GHA job (`GH_TOKEN`, `GITHUB_TOKEN`, `$GITHUB_ENV` when set)
3. Rewrites `origin` HTTPS URL when needed and runs `gh auth` setup
4. Prints JSON **without** the token (`ok`, `repositoryFullName`, `expiresAtMillis`)

**Fallback if `refresh-git-auth` is missing** (older CLI): remint with curl, apply without echoing the token, then retry:

```bash
BACKEND="${TESTCHIMP_BACKEND_URL:-https://featureservice.testchimp.io}"
BACKEND="${BACKEND%/}"
HTTP_CODE=$(curl -sS -o /tmp/tc_git_token.json -w "%{http_code}" -X POST \
  "${BACKEND}/api/chimphands/github_write_token" \
  -H "Content-Type: application/json" \
  -H "TestChimp-Api-Key: ${TESTCHIMP_API_KEY}" \
  -d '{}')
# Expect 200; do not cat the file into chat. Apply token to env + git, then rm the file.
python3 - <<'PY'
import json, os, subprocess, pathlib
d = json.load(open("/tmp/tc_git_token.json"))
token = (d.get("token") or "").strip()
assert token, "empty token"
os.environ["GH_TOKEN"] = token
os.environ["GITHUB_TOKEN"] = token
gh_env = os.environ.get("GITHUB_ENV")
if gh_env:
    with open(gh_env, "a") as f:
        f.write(f"GH_TOKEN={token}\nGITHUB_TOKEN={token}\n")
# Rewrite origin if https://github.com/...
r = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True)
url = (r.stdout or "").strip()
import re
m = re.match(r"https://(?:[^@]+@)?github\.com/([^/]+)/([^/\s]+?)(?:\.git)?/?$", url, re.I)
if m:
    owner, repo = m.group(1), m.group(2).removesuffix(".git")
    new = f"https://x-access-token:{token}@github.com/{owner}/{repo}.git"
    subprocess.run(["git", "remote", "set-url", "origin", new], check=False)
pathlib.Path("/tmp/tc_git_token.json").unlink(missing_ok=True)
print(json.dumps({"ok": True, "repositoryFullName": d.get("repositoryFullName") or d.get("repository_full_name") or "", "expiresAtMillis": d.get("expiresAtMillis") or d.get("expires_at_millis")}))
PY
# Also: printf '%s' "$TOKEN" | gh auth login --with-token   (use token from env in same shell — never echo it)
```

**Never** print the token. **Never** ask the user to refresh/reconnect/paste a GitHub token.

Host commit-before-idle (CLI ≥ 0.1.66) also remints + retries once on auth-looking push failures.

### Related

Cold idle → session **revive** dispatches a **new** Actions run, which mints a fresh token at job start. Prefer `refresh-git-auth` when the **same** run is still active and only credentials went stale.

---

## Cannot push files under `.github/workflows/`

### Symptom

Ordinary commits push, but updates to `.github/workflows/*` (e.g. SmartTests CI / ChimpHands workflow) fail or are ignored.

### Cause

Actions’ built-in `GITHUB_TOKEN` **cannot** create/update workflow files. ChimpHands prefers the App installation token (needs GitHub App permission **Workflows: Read & write**).

### Fix

1. Confirm the App has **Workflows: Read & write**; org admin must **accept** pending permission updates.
2. Run `testchimp chimphands refresh-git-auth` so the runner is not on the Actions fallback token.
3. If `chimphands.yml` is missing on the default branch, install it from the TestChimp UI. Do **not** overwrite a customized workflow (e.g. WIF) — edit the repo file directly when you need local changes.

---

## “Refresh / reconnect the GitHub token” messages (wrong)

If the model asks the user to refresh a GitHub token for this session: **that is incorrect**. Remint with `testchimp chimphands refresh-git-auth` and continue. Do not wait on the user for git auth.

---

## Push / PR blocked (branch name or protection)

| Symptom | Fix |
| --- | --- |
| Branch rejected by rulesets | Use `testchimp-*` or `chimphands-*` only; allow those prefixes in GitHub rulesets |
| Cannot push to `main` / `master` | Never commit to default — create/reuse session feature branch |
| `report-branch` but GitHub 404 | Push with `git push -u origin <branch>` **before** `testchimp chimphands report-branch` |

---

## Need a test environment on ChimpHands (stack for authoring / running / fixing tests)

**Do not** loop on `gh workflow run` / `gh run watch` against existing merge-gate or E2E workflows to “get a stack up.” Those jobs provision their **own** ephemeral env for a check; they do not give this session a usable `BASE_URL`.

**Do this instead:**

1. Load [`connect-to-test-env.md`](./connect-to-test-env.md) and read **`plans/knowledge/policies/connect-to-test-env.policy.md` → `## CI / Cloud`** (fallback: ai-test-instructions Environment Provision Strategy).
2. Follow those steps **on this runner** (compose, local-up scripts, EaaS MCP, etc.). Wait for healthy; export `BASE_URL` / backend URLs.
3. Use that same stack for create-tests, execute-tests, fix failures, smart smoke, ExploreChimp under the approved plan.
4. When you discover better commands, health checks, or pitfalls, **update the policy’s CI section** (and upsert) so the next session does not rediscover them.

If the CI section only describes PR check workflows and has no on-runner bring-up steps, complete bring-up from Local Agent / repo scripts, then **write the working procedure into `## CI / Cloud`**.

Details and anti-patterns: [`connect-to-test-env.md`](./connect-to-test-env.md#chimphands--github-actions-critical).

---

## Cloud jobs that truly “only run inside GitHub Actions” (WIF / OIDC)

Some **separate** customer workflows authenticate to cloud providers via **Workload Identity Federation** or **OIDC** and only receive those credentials inside GitHub Actions. Use this path **only when the connect-to-test-env policy (or the user) explicitly requires that workflow** — not as a substitute for bringing up the SmartTest env.

From ChimpHands:

1. Ensure git auth works (`refresh-git-auth` if needed).
2. Commit + push to the session branch if the job needs the branch tip.
3. Trigger with `gh workflow run <workflow> …` or open/update the PR so `on: pull_request` / `workflow_dispatch` fires.
4. Watch with `gh run list` / `gh run watch` (or the Actions UI).

Do not ask the user to paste cloud credentials, service-account keys, or WIF config. If `gh workflow run` fails with 401/403, remint auth first.

---

## Interactive vs non-interactive on GHA

`GITHUB_ACTIONS` / `CLOUD_AGENT` means **where** you run, not “skip approval.” Default is interactive (ask + wait). Only `--mode=non-interactive` or policy `allow-execute-without-approval` auto-approves. Details: [`agent-quick-answers.md`](./agent-quick-answers.md#chimphands--cloud-runner-interactive-vs-non-interactive).

---

## Async UI (`CHIMPHANDS_UI_ATTACHED=false`)

No live browser on the session: end-of-turn **commit + push** is critical for PR / Files changed. On ChimpHands, commit+push after **every** dirty turn (UI attached or not) — full rules in [`chimphands.md`](./chimphands.md). Host fallback commit exists; do not rely on it.

---

## Mid-turn chat messages (course-correct / steer)

### Symptom

You send a chat message while the agent is in a long tool (e.g. `bash` watch). GHA shows `queued user message (turnActive=true)` but the agent keeps going and never reacts.

### Cause (CLI before 0.1.66)

OpenCode cannot inject into an active turn. Older hosts only queued the message until the turn finished — so a long watch blocked the interjection forever.

### Fix (CLI ≥ 0.1.67)

The host delivers mid-turn user messages to the active OpenCode session via `prompt_async` — **without aborting** the running turn. The agent sees the new message and decides whether to course-correct, stop a watch/poll, or keep going. Chat UI: type a message while the agent is working and Send / Ctrl+Enter — empty composer still shows Stop.

Requires `@testchimp/cli@latest` on the runner (`npm install -g @testchimp/cli@latest` in `chimphands.yml`).

---

## TestChimp API 401 on CLI / MCP

Wrong host or missing key — not GitHub App token expiry.

1. Export `TESTCHIMP_BACKEND_URL` / `TESTCHIMP_INGRESS_URL` from project MCP when configured.
2. Export `TESTCHIMP_API_KEY` from the same entry (never print).
3. Retry. See `SKILL.md` Preamble **#4**.

---

## Workflow not dispatching / session stuck “starting”

| Check | Action |
| --- | --- |
| GitHub App + repo linked | TestChimp → Integrations → GitHub |
| `chimphands.yml` on default branch | Install from UI only when missing; merge install PR if branch protection blocked direct commit. Customized workflows are not auto-overwritten. |
| Actions disabled for first App workflow | In GitHub Actions UI, **Enable workflows** once if prompted |
| `TESTCHIMP_API_KEY` secret on the repo | Required for mint + bootstrap |

---

## What belongs here

| Put in this FAQ | Put elsewhere |
| --- | --- |
| ChimpHands GHA git/auth, workflow install, env anti-pattern (`gh workflow run` loops) | Product test strategy → normal planning |
| `refresh-git-auth`, stuck dispatch, WIF | **Branch + end-of-turn commit** → [`chimphands.md`](./chimphands.md) |
| Self-heal rules agents must follow without user secrets | ULID / plan path → [`agent-quick-answers.md`](./agent-quick-answers.md) |
| Narrow WIF/OIDC dispatch when policy requires it | **Test env bring-up** → [`connect-to-test-env.md`](./connect-to-test-env.md) + project `connect-to-test-env.policy.md` |
| | Repo env FAQ → `plans/knowledge/ai-test-instructions.md` |

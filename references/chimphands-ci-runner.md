# ChimpHands CI runner hygiene (GitHub Actions / cloud)

**Load with** [`chimphands.md`](./chimphands.md) whenever you run on a hosted CI runner (`GITHUB_ACTIONS`, ChimpHands session, `TESTCHIMP_EXECUTION_SOURCE=CLOUD_AGENT`).

This guidance is **project-agnostic** — it does not assume Gradle, Docker Compose, Playwright, or any specific stack. Follow the repo’s `connect-to-test-env.policy.md` / README for *what* to build; this doc covers *how to stay within runner disk, memory, and time budgets* while you do it.

---

## Git: scoped fetch only

Hosted runners have limited disk (~14 GiB usable on `ubuntu-latest`). **Never** run a blanket `git fetch origin` or `git fetch --unshallow` unless the user or policy explicitly requires deep history (e.g. security baselines with `baselineGitCommitSha`).

### What the workflow already did

- Shallow checkout (`fetch-depth: 1`) of the **base branch** (`inputs.branch`, prompt `Base branch:` / legacy `Working branch:`, or the repo default).
- Remote **branch names only** (no objects) in `.chimphands/remote-branch-names.txt`.
- `CHIMPHANDS_WORK_BRANCH` in the job environment when the workflow sets it (parent branch — create a **`testchimp-*`** agent branch from it before editing; see [`chimphands.md`](./chimphands.md)).

### When you need another branch

Fetch **one** branch tip, shallow:

```bash
BRANCH="<name>"
git fetch origin "refs/heads/${BRANCH}:refs/remotes/origin/${BRANCH}" --depth=1
git checkout -B "${BRANCH}" "origin/${BRANCH}"
```

To see what exists without downloading commits:

```bash
cat .chimphands/remote-branch-names.txt 2>/dev/null || \
  git ls-remote --heads origin | awk '{print $2}' | sed 's@^refs/heads/@@'
```

### Do not

- `git fetch origin` (downloads every remote branch tip and often balloons disk).
- `git fetch --all --prune` without a single-branch refspec.
- Clone submodules or extra repos unless the approved plan requires it.

---

## Disk budget (P0 on hosted runners)

Treat disk like memory on a laptop: **measure, reclaim between phases, fail fast** when low.

### Before heavy work

```bash
df -h /
# optional when Docker is in play:
docker system df 2>/dev/null || true
```

If available space is under ~4 GiB before a large build, **reclaim first** (below) — do not start another full image build or dependency install.

### Between phases (generic reclaim)

After a compile/build phase when **runtime artifacts** (images, jars, binaries) are already packaged and you need space for the next phase:

| Area | When safe to clean | Example commands |
| --- | --- | --- |
| Build tool daemons / host caches | After host-side compile; runtime uses containers or deployed artifacts | `./gradlew --stop`; `mvn --batch-mode -q -DskipTests=false -v` (stop daemon); stop language-specific daemons per repo docs |
| Docker **build cache** | After `docker build` / `compose build` when **images** for `up`/`run` are kept | `docker builder prune -af` |
| Docker **dangling** images | When tagged images for the test env are already built | `docker image prune -f` |
| Package manager caches (host) | After install if the same deps are baked into an image or not needed again | Remove only caches you can recreate; prefer workflow `cache:` keys when present |
| Test / report output | After upload or when starting a fresh test run | `rm -rf test-results playwright-report* coverage .pytest_cache` (paths per repo) |
| Temp | Between phases | `rm -rf /tmp/*` (best-effort) |

**Do not** `docker system prune -af --volumes` while a compose stack you still need is running.

### Docker build order (when the project uses containers)

On small runners, avoid peak RAM/disk from **parallel** heavy builds (e.g. backend compile + frontend webpack in one `compose build --parallel`):

1. Build backend / worker images first (or one at a time if OOM).
2. `docker builder prune -af` when images are tagged and you still need disk.
3. Build UI / asset-heavy images **alone**.
4. `docker compose up -d` (or project equivalent) **without** `--build` if images are fresh.

Enable BuildKit when the repo does: `export DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1`.

### Dependency installs

- Prefer **one** host install of test runners (e.g. browser binaries) per session — reuse for later phases.
- Do not run `npm ci` / `pip install` on the host **and** inside Docker for the same tree unless the project policy requires both.
- Pin or cache global CLIs when the workflow already installed them — avoid reinstalling `@latest` every turn.

### Retries

If a build fails for **disk** or **no space left on device**:

1. Reclaim (table above).
2. Re-check `df -h /`.
3. Retry **once** with a slimmer path (sequential builds, skip optional services).

Do **not** loop blind retries — each attempt stacks caches and images.

### Teardown (end of session or plan Phase 7)

Per project policy: stop compose/k8s/emulators, remove volumes if ephemeral, final `docker builder prune` when safe, delete large local artifacts. Leave the runner cleaner than you found it.

---

## Memory and parallelism

- `ubuntu-latest` is often **7 GiB RAM** — cap concurrent JVMs, webpack, and `docker compose build --parallel`.
- Prefer sequential image builds over OOM kills (exit 137 / SIGTERM).
- Stop unused daemons after compile phases.

---

## Time and cost

- Long idle waits burn the job timeout and GitHub App token TTL (~1h) — see [`chimphands-faq.md`](./chimphands-faq.md).
- Prefer one disciplined bring-up over exploratory re-runs.
- Commit + push in meaningful batches so users can review without re-running the whole stack.

---

## Observability (when stuck)

```bash
df -h /
docker system df 2>/dev/null || true
du -xh --max-depth=2 . 2>/dev/null | sort -h | tail -15
```

Report **what phase** failed (compile, image build, compose up, test install) and **available GiB** — not just “out of disk.”

---

## Related

| Doc | Use for |
| --- | --- |
| [`chimphands.md`](./chimphands.md) | Branch, commit, PR contract |
| [`connect-to-test-env.md`](./connect-to-test-env.md) | *What* env to provision |
| [`chimphands-faq.md`](./chimphands-faq.md) | Auth, WIF, anti-patterns |

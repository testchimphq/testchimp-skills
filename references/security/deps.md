# Deps (dependency issues)

Follow this when `get-security-scan-config` returns **`detail.depsCheckConfig`**. Parent orchestrator: [`../security_scans.md`](../security_scans.md).

## Config fields (camelCase)

| Field | Meaning |
|-------|---------|
| `scope` | `RELEASE_DEPENDENCIES` (default) — deps **newly introduced** since baseline; `FULL_DEPENDENCY_TREE` — all project deps |
| `securityProfile` | `ESSENTIAL` \| `STANDARD` (default) \| `COMPREHENSIVE` — severity filter (below) |
| `ignoreVulnerabilitiesWithoutFixes` | When true (default), skip vulns with no available fix (`--ignore-unfixed`) |
| `baselineGitCommitSha` | Required for `RELEASE_DEPENDENCIES`; prior release SHA or user-picked baseline from the UI |

Also load **`releaseLabel`** from the top-level scan config response for `get-release` / context.

### Security profile → Trivy severities

| `securityProfile` | Include severities | Trivy `--severity` |
|-------------------|--------------------|---------------------|
| `ESSENTIAL` | CRITICAL | `CRITICAL` |
| `STANDARD` | HIGH + CRITICAL | `HIGH,CRITICAL` |
| `COMPREHENSIVE` | LOW + MEDIUM + HIGH + CRITICAL + UNKNOWN | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` |

Server also filters on ingest using the same profile (+ ignore-unfixed). Prefer passing matching `--severity` / `--ignore-unfixed` to Trivy to keep reports smaller.

## Steps

1. Read **`depsCheckConfig`** — **do not re-ask** for scope, profile, ignore-unfixed, or baseline.

2. **Ensure Trivy** is available:
   1. If `trivy --version` works → reuse.
   2. Else install via `brew install trivy` or [Trivy install docs](https://aquasecurity.github.io/trivy/latest/getting-started/installation/).
   3. Else **STOP** with clear install instructions → set `EXCEPTION`.

3. Prefer scanning at the **git repo root**.

4. Resolve scan targets:
   - **`FULL_DEPENDENCY_TREE`:** scan `.` (or documented app roots).
   - **`RELEASE_DEPENDENCIES`:** require `baselineGitCommitSha`. List files changed since baseline:
     ```bash
     git diff --name-only '<baselineGitCommitSha>'..HEAD
     ```
     Keep paths that are or sit under dependency manifests / lockfiles:
     - `package.json` / `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` / `npm-shrinkwrap.json`
     - `pom.xml`
     - `build.gradle` / `build.gradle.kts` / `gradle.lockfile`
     - `requirements.txt` / `Pipfile` / `Pipfile.lock` / `poetry.lock` / `uv.lock`
     - `go.mod` / `go.sum`
     - `Cargo.toml` / `Cargo.lock`
     - `Gemfile` / `Gemfile.lock`
     - `composer.json` / `composer.lock`
     - `*.csproj` / `packages.lock.json` / `packages.config`
     Scan the **directories containing** those changed manifests (unique parent dirs), or the manifests themselves with `trivy fs`. If no matching manifests changed, still produce an empty Trivy JSON (`{"Results":[]}`), upload it, and mark `COMPLETED`.
     Fetch enough git history for the baseline commit when needed. Prefer `get-release --version '<releaseLabel>'` for cut/prior context when useful.

5. Run Trivy (write full JSON — include all `Results` metadata; do **not** strip fields). **Always** pass `--scanners vuln` so secret findings are not mixed into the deps report:

```bash
trivy fs --scanners vuln --format json --output /tmp/trivy-report-<scan_id>.json \
  --severity HIGH,CRITICAL \
  [--ignore-unfixed] \
  <target>
```

- Map `--severity` from the profile table.
- Add `--ignore-unfixed` when `ignoreVulnerabilitiesWithoutFixes` is true or absent.
- **Exit codes:** Trivy may exit non-zero when vulnerabilities are found depending on flags; treat findings as **success** for this playbook (still report). Treat only crashes / missing binary / failed upload as hard failures.
- Empty findings are still success — upload `{"Results":[]}` and mark `COMPLETED`.

6. **Release delta (required for `RELEASE_DEPENDENCIES`):** scanning a changed lockfile reports *all* vulns in that lockfile, not only new ones. After the current scan:
   1. Materialize the **same targets as of `baselineGitCommitSha`** into a temp dir (`git show <baseline>:<path>` / `git checkout <baseline> -- …` in a worktree or temp copy).
   2. Run the **same** `trivy fs --scanners vuln …` command on the baseline snapshot → `/tmp/trivy-baseline-<scan_id>.json`.
   3. Diff findings by key `VulnerabilityID|PkgName|InstalledVersion|Target` (or equivalent). Keep only findings present in the **current** report and absent from the **baseline** report.
   4. Write the filtered result as Trivy-shaped JSON (`{"Results":[…]}` with filtered `Vulnerabilities`) to `/tmp/trivy-report-<scan_id>.json` for upload.
   5. If the baseline snapshot of a target is missing (file did not exist at baseline), treat all current vulns for that target as new.

7. **`testchimp report-deps-findings --id '<scan_id>' --report-file <path>`** — upload the **entire** JSON file (must be an object with a `Results` array).

8. On successful report → **`testchimp update-scan-progress --id '<scan_id>' --status COMPLETED`**. On hard failure → `EXCEPTION`.

## Notes

- `report-deps-findings` does **not** set scan status; this playbook does immediately after a successful report.
- Do **not** use any `run-*-scan` tools — scanners run locally; only report tools upload results.
- Duplicate findings (same bug hash) are skipped project-wide; the raw report is still stored for the report viewer.
- Server re-applies severity / ignore-unfixed filters on ingest — the Report UI may show more findings than bugs filed.

# Secrets (leaks)

Follow this when `get-security-scan-config` returns **`detail.leaksCheckConfig`**. Parent orchestrator: [`../run-release-check.md`](../run-release-check.md).

## Config fields (camelCase)

| Field | Meaning |
|-------|---------|
| `scope` | `RELEASE_CHANGES` (default) — secrets introduced since baseline; `ALL_REPOSITORY_SECRETS` — all secrets in the tree |
| `baselineGitCommitSha` | Required for `RELEASE_CHANGES`; prior release SHA or user-picked baseline from the UI |

Also load **`releaseLabel`** from the top-level scan config response for `get-release` / context.

## Steps

1. Read **`leaksCheckConfig`** — **do not re-ask** for scope or baseline.

2. **Ensure Gitleaks** is available:
   1. If `gitleaks version` works → reuse.
   2. Else install via `brew install gitleaks` or [gitleaks releases](https://github.com/gitleaks/gitleaks/releases).
   3. Else **STOP** with clear install instructions → set `EXCEPTION`.

3. Prefer scanning at the **git repo root**.

4. Build and run Gitleaks (write full JSON — do **not** strip fields client-side; the server redacts `Secret`/`Match` on ingest):

Prefer **`gitleaks git`** (current CLI). Fall back to `gitleaks detect` only if `git` subcommand is unavailable.

```bash
# RELEASE_CHANGES — commits since baseline (secrets introduced in the release range)
gitleaks git . --report-path /tmp/gitleaks-report-<scan_id>.json --report-format json \
  --log-opts '<baselineGitCommitSha>..HEAD'

# ALL_REPOSITORY_SECRETS — full git history
gitleaks git . --report-path /tmp/gitleaks-report-<scan_id>.json --report-format json
```

Legacy fallback (older installs):

```bash
gitleaks detect --source . --report-path /tmp/gitleaks-report-<scan_id>.json --report-format json \
  [--log-opts '<baselineGitCommitSha>..HEAD']
```

- If `scope` is `RELEASE_CHANGES` (or absent / unknown): require `baselineGitCommitSha`. Fetch enough git history so the baseline exists (`git fetch --unshallow` / deepen as needed). Prefer `get-release --version '<releaseLabel>'` for cut/prior context when useful.
- If `scope` is `ALL_REPOSITORY_SECRETS`: omit `--log-opts`.
- **Exit codes:** Gitleaks exit `1` when leaks are found is **success** for this playbook (still report). Treat only crashes / missing binary / failed upload as hard failures.
- **Empty findings:** if Gitleaks writes no file or an empty file, write `[]` to the report path before upload. Empty array is valid and still `COMPLETED`.

5. **`testchimp report-secrets-findings --id '<scan_id>' --report-file <path>`** — upload the **entire** JSON file (must be a JSON array or `{ "findings": [...] }`).

6. On successful report → **`testchimp update-scan-progress --id '<scan_id>' --status COMPLETED`**. On hard failure → `EXCEPTION`.

## Notes

- `report-secrets-findings` does **not** set scan status; this playbook does immediately after a successful report.
- Do **not** use any `run-*-scan` tools — scanners run locally; only report tools upload results.
- Duplicate findings (same bug hash) are skipped project-wide; the redacted raw report is still stored for the report viewer.
- Release scope uses **commit-range** history (`--log-opts`), not a naive file-list-only scan — that is how Gitleaks detects secrets introduced since the baseline.

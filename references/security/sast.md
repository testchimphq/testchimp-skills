# SAST (static code checks)

Follow this when `get-security-scan-config` returns **`detail.sastCheckConfig`**. Parent orchestrator: [`../security_scans.md`](../security_scans.md).

## Config fields (camelCase)

| Field | Meaning |
|-------|---------|
| `scope` | `RELEASE_SCOPED` (default) — only new findings vs baseline; `FULL_REPOSITORY` — all findings |
| `rules` | `ESSENTIAL` \| `STANDARD` (default) \| `COMPREHENSIVE` — Semgrep registry packs (below) |
| `severities` | `BugSeverity` list to keep (default `CRITICAL_SEVERITY`, `HIGH_SEVERITY`) |
| `baselineGitCommitSha` | Required for `RELEASE_SCOPED`; Semgrep `--baseline-commit` |

Also load **`releaseLabel`** from the top-level scan config response when useful for context.

### Rules → Semgrep configs

| `rules` | `--config` values |
|---------|-------------------|
| `ESSENTIAL` | `p/default` |
| `STANDARD` | `p/default`, `p/owasp-top-ten` |
| `COMPREHENSIVE` | `p/default`, `p/owasp-top-ten`, `p/security-audit`, `p/cwe-top-25` |

Server maps Semgrep severities when reporting (`ERROR`/`CRITICAL`→`CRITICAL_SEVERITY`, `WARNING`/`HIGH`→`HIGH_SEVERITY`, `MEDIUM`/`MODERATE`→`MEDIUM_SEVERITY`, `INFO`/`LOW`→`LOW_SEVERITY`) and filters by configured `severities`. Paths are normalized (`\`→`/`, strip `./`) for stable bug hashes.

## Steps

1. Read **`sastCheckConfig`** — **do not re-ask** for scope, rules, severities, or baseline.

2. **Ensure Semgrep** is available:
   1. If `semgrep --version` works → reuse.
   2. Else install via `pipx install semgrep`, `brew install semgrep`, or `pip install semgrep`.
   3. Else **STOP** with clear install instructions → orchestrator / playbook sets `EXCEPTION`.

3. Prefer scanning at the **git repo root** (or mapped app roots from project conventions / `ai-test-instructions.md` if documented).

4. Build and run Semgrep (write full CLI JSON — include `paths`, `results`, `errors`, `version`; do **not** strip metadata):

```bash
semgrep scan --json -o /tmp/semgrep-report-<scan_id>.json \
  --config p/... \
  [--baseline-commit '<baselineGitCommitSha>'] \
  .
```

- Add one `--config` per pack from the rules table.
- If `scope` is `RELEASE_SCOPED` (or absent / unknown): require `baselineGitCommitSha`; add `--baseline-commit`. Fetch enough git history so the baseline commit exists (`git fetch --unshallow` / deepen as needed).
- If `scope` is `FULL_REPOSITORY`: omit `--baseline-commit`.
- Do **not** pass `--time` by default.
- **Exit codes:** Semgrep exit `1` when findings exist is **success** for this playbook (still report). Treat only crashes / missing binary / failed upload as hard failures.

5. **`testchimp report-sast-findings --id '<scan_id>' --report-file <path>`** — upload the **entire** JSON file.

6. On successful report → **`testchimp update-scan-progress --id '<scan_id>' --status COMPLETED`**. On hard failure → `EXCEPTION`.

## Notes

- `report-sast-findings` does **not** set scan status; this playbook does immediately after a successful report.
- Duplicate findings (same bug hash) are skipped project-wide; the raw report is still stored for the report viewer.

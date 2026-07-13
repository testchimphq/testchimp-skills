# Security scans (release checks)

Use this playbook when the user (or Release Checks modal) asks to run:

```text
/testchimp run security scan for <scan_id>
```

Requires **`@testchimp/cli` ≥ 0.1.14** (`get-security-scan-config`, `update-scan-progress`, `report-dast-findings`, stubs for SAST/deps/secrets).

**Statuses** (exact strings for `update-scan-progress --status`):

| Status | When |
|--------|------|
| `QUEUED` | Created in UI; do not set unless resetting |
| `IN_PROGRESS` | Scan work started |
| `COMPLETED` | **All** selected categories finished (agent sets this; report tools do not) |
| `EXCEPTION` | Hard failure that stops the scan |

Allowed transitions: `QUEUED` → `IN_PROGRESS` \| `EXCEPTION`; `IN_PROGRESS` → `COMPLETED` \| `EXCEPTION`. Terminal: `COMPLETED`, `EXCEPTION`.

## Flow

1. **`testchimp update-scan-progress --id '<scan_id>' --status IN_PROGRESS`**
2. **`testchimp get-security-scan-config --id '<scan_id>'`** — read `categories`, `environment`, `releaseLabel`, **`allowActiveScan`**, and `detail`.
3. **`testchimp get-release --version '<release_label>'`** — cut SHA, prior SHA, focus areas.
4. **Resolve DAST base URL** (only if `DYNAMIC_CHECKS` is enabled):
   - Look for SmartTest suite env files (e.g. `.env-QA`, `.env-<ENV>`, `.env`) near the tests root.
   - Prefer `BASE_URL` / `base_url` for the selected environment.
   - If missing or ambiguous → **ask the user to confirm the target endpoint** before continuing.
5. **Ensure OWASP ZAP** (daemon + API):
   1. If ZAP API already responds on the configured local port → reuse.
   2. Else locate install (`ZAP_HOME`, `/Applications/ZAP.app/.../zap.sh`, PATH).
   3. Else install via OS package manager when available (`brew install --cask zap`, `winget install ZAP.ZAP`, Linux package/snap).
   4. Else if Docker is available → `ghcr.io/zaproxy/zaproxy:stable` daemon on a fixed host port.
   5. Else **STOP** with clear install instructions.
   - Prefer **daemon mode** for Playwright HTTP(S) proxying. For HTTPS apps, configure ZAP CA trust or use Playwright `ignoreHTTPSErrors` as needed.
6. **Select automation tests** for passive crawl:
   - Prefer tests **authored/updated** in this release (from release delta / git range).
   - Else map **code changes** in the release git range to covering UI tests.
   - Else **guided walk** of areas affected by the release.
   - Prefer **real-backend** tests; skip mocks-heavy tests.
7. Run those tests (or walk) with the browser proxied through ZAP → **passive** listening.
8. **Active scan — honour config, do not re-ask:**
   - If `allowActiveScan` is **true** → run ZAP **active** scan scoped to URLs/context learned in passive phase.
   - If `allowActiveScan` is **false** / absent → **skip** active mode; report passive findings only.
9. Export **Traditional JSON** (`traditional-json`, not HTML; avoid `traditional-json-plus` unless needed).
10. **`testchimp report-dast-findings --id '<scan_id>' --report-file <path>`**
11. For other categories (if ever enabled): `run-sast-scan` / `run-deps-scan` / `run-secrets-scan` (stubs until implemented).
12. **`testchimp update-scan-progress --id '<scan_id>' --status COMPLETED`** when done (or `EXCEPTION` on hard failure).

## Notes

- `report-dast-findings` does **not** complete the scan (multi-category future-proofing).
- Duplicate findings (same bug hash) are skipped project-wide; still store the raw report for audit.
- Point the user at Release Checks on the release detail page; **View Bugs** opens `/bugs` scoped to the scan id.
- Queued / in-progress rows expose **Copy prompt** so the user can re-run the agent without recreating the scan.

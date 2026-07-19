# DAST (dynamic application security)

Follow this when `get-security-scan-config` returns top-level or `detail` **`dastCheckConfig`** (or legacy `detail.securityScanDetail` with dynamic checks). Parent orchestrator: [`../run-release-check.md`](../run-release-check.md).

## Config fields (camelCase)

Prefer **`dastCheckConfig`** (top-level or under `detail`). Fields:

| Field | Meaning |
|-------|---------|
| `environment` | **Environment tag** (e.g. `QA`). Always present for labeling / `.env*` lookup when not using sandbox. |
| `allowActiveScan` | `true` → ZAP **active** after passive; `false`/absent → passive-only. **Do not re-ask.** |
| `useEphemeralSandbox` | Provision Bunnyshell ephemeral **only when this is true and `allowActiveScan` is true**. Server clears sandbox when active is false. |
| `scope` | Which automation to run with ZAP proxy: `RELEASE_SCOPE` (default), `SMOKE`, `FULL`. **Do not re-ask.** |

Also load **`releaseLabel`** from the top-level scan config response for `get-release`.

## Steps

1. **`testchimp get-release --version '<release_label>'`** — cut SHA, prior SHA, focus areas (needed for `RELEASE_SCOPE` and useful context for all scopes).

2. **Resolve DAST base URL**
   - If **`useEphemeralSandbox` is true and `allowActiveScan` is true**:
     - Follow the EaaS (Bunnyshell) workflow in [`../environment-management.md`](../environment-management.md): **`get-eaas-config`** → if `{}`, **STOP** with a clear message that Bunnyshell is not configured (do not invent a URL) → **`provision-ephemeral-environment-and-wait`** → map `component_urls_json` to `BASE_URL` / `BACKEND_URL`.
     - Keep the scan’s **`environment` tag** as the label; the ephemeral deploy is an **instance** of that tag — do **not** fall back to shared `.env*` `BASE_URL` when sandbox was requested.
     - Remember the provisioned env id / handle so the parent orchestrator can **`destroy-ephemeral-environment`** in cleanup (**always**, including on failure).
   - Else (no sandbox):
     - Resolve shared/persistent URL from the **`environment` tag** via SmartTest suite env files (e.g. `.env-QA`, `.env-<ENV>`, `.env`) near the tests root.
     - Prefer `BASE_URL` / `base_url` for that tag.
     - If missing or ambiguous → **ask the user to confirm the target endpoint** before continuing.

3. **Ensure OWASP ZAP** (daemon + API):
   1. If ZAP API already responds on the configured local port → reuse.
   2. Else locate install (`ZAP_HOME`, `/Applications/ZAP.app/.../zap.sh`, PATH).
   3. Else install via OS package manager when available (`brew install --cask zap`, `winget install ZAP.ZAP`, Linux package/snap).
   4. Else if Docker is available → `ghcr.io/zaproxy/zaproxy:stable` daemon on a fixed host port.
   5. Else **STOP** with clear install instructions.
   - Prefer **daemon mode** for Playwright HTTP(S) proxying. For HTTPS apps, configure ZAP CA trust or use Playwright `ignoreHTTPSErrors` as needed.

4. **Select automation tests for the ZAP-proxied crawl** based on **`scope`** (default `RELEASE_SCOPE` if absent / `UNKNOWN_DAST_SCAN_SCOPE`):
   - **`RELEASE_SCOPE`** — Prefer tests **authored/updated** in this release (release delta / git range). Else map **code changes** in the release git range to covering UI tests. Else **guided walk** of areas affected by the release (`get-release` focus areas). Prefer **real-backend** tests; skip mocks-heavy tests.
   - **`SMOKE`** — Critical / smoke flows only: login, primary happy paths, health-critical journeys. Prefer tagged smoke suite or project conventions in `ai-test-instructions.md`. Do **not** expand to the full suite.
   - **`FULL`** — Comprehensive SmartTest / UI suite through ZAP proxy (still prefer real-backend; skip mocks-heavy where possible). Longer run is expected.

5. Run those tests (or walk) with the browser proxied through ZAP → **passive** listening.

6. **Active scan — honour config, do not re-ask:**
   - If `allowActiveScan` is **true** → run ZAP **active** scan scoped to URLs/context learned in passive phase.
   - If `allowActiveScan` is **false** / absent → **skip** active mode; report passive findings only.

7. Export **Traditional JSON** (`traditional-json`, not HTML; avoid `traditional-json-plus` unless needed).

8. **`testchimp report-dast-findings --id '<scan_id>' --report-file <path>`**

9. On successful report → **`testchimp update-scan-progress --id '<scan_id>' --status COMPLETED`**. On hard failure of a required step → `EXCEPTION`.

## Notes

- `report-dast-findings` does **not** set scan status; this playbook does immediately after a successful report.
- Duplicate findings (same bug hash) are skipped project-wide; still store the raw report for audit.
- Docs: [DAST ephemeral sandbox](https://docs.testchimp.io/integrations/bunnyshell#dast-ephemeral-sandbox).

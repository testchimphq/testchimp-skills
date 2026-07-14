# Security scans (release checks)

Use this playbook when the user (or Release Checks modal) asks to run:

```text
/testchimp run security scan for <scan_id>
```

Requires **`@testchimp/cli` ≥ 0.1.14** (`get-security-scan-config`, `update-scan-progress`, `report-dast-findings`, EaaS tools when ephemeral sandbox is requested).

**Statuses** (exact strings for `update-scan-progress --status`):

| Status | When |
|--------|------|
| `QUEUED` | Created in UI; do not set unless resetting |
| `IN_PROGRESS` | Scan work started |
| `COMPLETED` | **All** selected check types finished (agent sets this; report tools do not) |
| `EXCEPTION` | Hard failure that stops the scan |

Allowed transitions: `QUEUED` → `IN_PROGRESS` \| `EXCEPTION`; `IN_PROGRESS` → `COMPLETED` \| `EXCEPTION`. Terminal: `COMPLETED`, `EXCEPTION`.

## Flow

Treat steps 4–6 as a **try / finally**: always run cleanup (step 6) even when step 4 throws into `EXCEPTION`.

1. **`testchimp update-scan-progress --id '<scan_id>' --status IN_PROGRESS`**
2. **`testchimp get-security-scan-config --id '<scan_id>'`** — response shape (camelCase):
   - Prefer top-level **`dastCheckConfig`** when present (also mirrored under `detail.dastCheckConfig`).
   - Future / stub types live only under **`detail`**: `detail.sastCheckConfig`, `detail.depsCheckConfig`, `detail.leaksCheckConfig`.
   - Legacy scans may still have `detail.securityScanDetail`; the server also materializes top-level `dastCheckConfig` from it when possible.
   - Convenience mirrors (may be deprecated): top-level `environment`, `allowActiveScan`, `useEphemeralSandbox`, `releaseLabel`, `status`.
3. **Branch on which configs are present** (a scan typically has one type today):
   - If top-level / `detail` **`dastCheckConfig`** (or legacy dynamic `securityScanDetail`) → [`security/dast.md`](./security/dast.md)
   - If **`detail.sastCheckConfig`** → [`security/sast.md`](./security/sast.md)
   - If **`detail.depsCheckConfig`** → [`security/deps.md`](./security/deps.md)
   - If **`detail.leaksCheckConfig`** → [`security/secrets.md`](./security/secrets.md)
   - If **none** of the above → set `EXCEPTION` and tell the user the scan config is empty/unrecognized.
4. Run the matching playbook(s). On hard failure of a required step → **`update-scan-progress --status EXCEPTION`** (still do cleanup).
5. When all applicable check types succeed → **`update-scan-progress --status COMPLETED`**.
6. **Cleanup (always):** if this run provisioned an ephemeral environment for DAST sandbox, call **`destroy-ephemeral-environment`**. Follow [`environment-management.md`](./environment-management.md).

## Notes

- Do **not** invent separate slash commands per check type; one orchestrator reads nested config from the scan id.
- Point the user at Release Checks on the release detail page; **View Bugs** opens `/bugs` scoped to the scan id.
- Queued / in-progress rows expose **Copy prompt** so the user can re-run the agent without recreating the scan.

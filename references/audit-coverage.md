# /testchimp audit

Audit test coverage vs plans using TestChimp data.

## Steps

1. **Requirement coverage** — Call MCP **`get_requirement_coverage`** with:
   - Optional **`scope.folderPath`** — platform-rooted path under **`tests/...`** or **`plans/...`**.
     - Example tests scope: `["tests","checkout"]`
     - Example plans scope: `["plans","checkout"]`
   - Optional **`scope.filePaths`** — SmartTest file paths relative to the platform **tests** folder root (e.g. `e2e/foo.spec.ts`).
   - Optional **`branchName`** (Git branch), **`environment`**, **`release`**
   - Set **`includeNonCoveredUserStories`** / **`includeNonCoveredTestScenarios`** to `true` when you need explicit gaps

2. **Execution history** — Call **`get_execution_history`** with the same scope shape to see recent pass/fail and errors.

3. **Plan** — From missing scenarios, failures, and story priority, propose an ordered list of fixes (new tests, updates, data setup).

4. **Execute** — Implement changes as SmartTests (see [`write-smarttests.md`](./write-smarttests.md)), then re-run locally or in CI.

## Notes

- Coverage is tied to **SmartTest ↔ scenario** mappings and execution jobs ingested by the reporter.
- `scope.folderPath` uses **platform-side** roots (`tests` / `plans`) and then maps to the actual repo folder names configured in project integrations.

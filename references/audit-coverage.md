# /testchimp audit

Audit test coverage vs plans using TestChimp data.

## Steps

0. **TrueCoverage (optional)** — If `plans/knowledge/ai-test-instructions.md` indicates TrueCoverage is enabled (see `### TrueCoverage Plan`), after requirement coverage use MCP tools to compare real usage vs tests. See **`ExecutionScope`** in [`truecoverage.md`](./truecoverage.md): **`baseExecutionScope`** ≈ prod/real usage; **`comparisonExecutionScope`** ≈ test/staging runs. Set **`automationEmitsOnly: true`** on the **comparison** (or **`coverage_scope`**) object so coverage reflects **test-tagged emits only** and manual traffic on the same env does not inflate “covered.” Then:
   - **`list-rum-environments`** — valid environment tags.
   - **`get-truecoverage-events`** — funnel summaries (`baseExecutionScope` + optional `comparisonExecutionScope`).
   - Drill down with **`get-truecoverage-event-details`**, **`get-truecoverage-child-event-tree`**, **`get-truecoverage-event-transition`**, **`get-truecoverage-event-time-series`**, and metadata tools as needed.
   - Prioritize gaps that combine **low test coverage** with **high user impact** (see event summaries and scopes).

1. **Requirement coverage** — Call MCP **`get-requirement-coverage`** with:
   - Optional **`scope.folderPath`** — platform-rooted path under **`tests/...`** or **`plans/...`**.
     - Example tests scope: `["tests","checkout"]`
     - Example plans scope: `["plans","checkout"]`
   - Optional **`scope.filePaths`** — SmartTest file paths relative to the platform **tests** folder root (e.g. `e2e/foo.spec.ts`).
   - Optional **`branchName`** (Git branch), **`environment`**, **`release`**
   - Set **`includeNonCoveredUserStories`** / **`includeNonCoveredTestScenarios`** to `true` when you need explicit gaps

2. **Execution history** — Call **`get-execution-history`** with the same scope shape to see recent pass/fail and errors.

3. **Plan** — From missing scenarios, failures, story priority, and any TrueCoverage gaps, propose an ordered list of fixes (new tests, RUM instrumentation, data setup).

4. **Execute** — Implement changes as SmartTests (see [`write-smarttests.md`](./write-smarttests.md)), then re-run locally or in CI.

## Notes

- Coverage is tied to **SmartTest ↔ scenario** mappings and execution jobs ingested by the reporter.
- `scope.folderPath` uses **platform-side** roots (`tests` / `plans`) and then maps to the actual repo folder names configured in project integrations.

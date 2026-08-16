# /testchimp init-perf

Scaffold k6 performance testing under the mapped SmartTests root. Load [`perf-testing.md`](./perf-testing.md) first.

**Capability (soft gate):** `get-org-capabilities` must include
**`PERFORMANCE_TESTING`**, or `freeTrialActive` must be true. Otherwise mark
this workflow N/A, explain that the org does not currently include performance
testing, and stop without failing an enclosing workflow.

## Execute

1. Resolve SmartTests root (`.testchimp-tests` marker).
2. Copy skill assets from [`../assets/k6/`](../assets/k6/) into `<SmartTests root>/k6/` **when missing** (`journeys/`, `composites/`, `profiles/`, `datasets/`, `lib/`, `scripts/`). Do not overwrite existing journeys, manifests, or policy decisions. **Add** any new scaffold files that existing `k6/` trees lack (`lib/volume-size.js`, `lib/dataset.js`, `scripts/run.sh`, `scripts/suite-worklist.py`, `scripts/run-volume-staircase.sh`, `profiles/volume.js` with `K6_VOLUME_STEPS` duration). Clients execute **`k6/scripts/run.sh`** (not a dogfood-only wrapper).
3. Patch Playwright config: `testIgnore` must include `'**/k6/**'` (in addition to `'**/setup/**'` / fixtures). Templates: [`../assets/template_playwright.config.js`](../assets/template_playwright.config.js).
4. Run `k6/scripts/prepare.sh` so `@testchimp/k6` **latest** (≥ **0.2.1** for full-metric timeseries; ≥ **0.2.2** for HTTP 5xx/4xx/3xx fail-rate series) is downloaded into gitignored `k6/lib/` (re-fetched on each prepare/run). **Never** vendor a reporter copy into git.
5. Confirm `k6` is installed (`k6 version`); if missing, tell the user to install [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/).
6. Seed `plans/knowledge/policies/run-perf-tests.policy.md`,
   `create-perf-tests.policy.md`, and `upkeep-perf.policy.md` from
   [`../assets/policies/`](../assets/policies/) when missing; project values
   must replace placeholders before non-smoke execution.
7. Record a short **Performance testing** note in
   `plans/knowledge/ai-test-instructions.md`: k6 folder, permitted environment,
   health check, seed/teardown command, profile ownership, dataset limits,
   durable `llm_mode` (default `mocked`), latency profile
   (`none` / `mocked-standard` / `mocked-slow`), **external dependency mock
   inventory** (what is stubbed, where, and realistic latency targets — see
   [`perf-testing.md`](./perf-testing.md) § External dependencies). **`/testchimp
   run QA`** writes `plans/smart-smoke/<branch>/related-perf-tests.json` when
   `k6/journeys` exists; it does **not** execute load/volume. Execution is
   `k6/scripts/run.sh` (CI `--impacted` or `/testchimp run-perf-tests`).
8. Do **not** silently install AIMock. k6 LLM paths use `k6/lib/mock-llm.js`
   (k6-side delay only — it does not stub SUT LLM clients). If the
   application would call an LLM on the journey path, fail closed in SUT
   config or keep those APIs off the journey.
   General external doubles use `k6/lib/mock-external.js` and/or env-level
   stubs with realistic latency. If a journey needs a real LLM/external and
   the harness is missing, block load/volume unless the user explicitly
   approves `llm_mode: real` / live externals.
   Record SUT hosts separately from reporter env, what each VU represents,
   and the peak dataset id for volume staircases (`volume_size` in-run).
9. Shell-check scripts and run `k6 inspect` on the example journey. Do not run
   load/volume until absolute settings are approved.
10. **Optional nested `import-perf-tests`:** if the workspace already has a
    performance suite **outside** `<SmartTests root>/k6/` (Locust `locustfile.py`,
    JMeter `*.jmx`, Gatling simulations, Artillery YAML, or a k6 folder elsewhere),
    offer to run [`import-perf-tests.md`](./import-perf-tests.md) **now** as a
    nested subflow of this init-perf (same plan + `workflow_execution_id` —
    **one approval**), or skip for later (`/testchimp import-perf-tests <folder>`).
    Do not start a second Plan → approve → Execute cycle.

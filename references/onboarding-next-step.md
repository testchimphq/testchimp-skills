# Onboarding next step (hand-back)

New TestChimp projects show a setup launchpad on the dashboard: connect repo → project setup → connect agent → author plans → run QA → first results → verify a test → test a release (→ optionally invite the team). The agent does most of these steps, so when a workflow finishes, tell the user what comes next instead of leaving them to work it out.

## When

At the very end of these workflows, after the closing `report-agent-action`:

- `/testchimp project-init` (`project-init`)
- `/testchimp init` (`init`)
- `/testchimp author plans` (`author-plans`)
- `/testchimp run QA` (`run-qa`)
- `/testchimp create release` (`create-release`)

Skip it in `--mode=non-interactive` runs and for any other workflow.

## How

1. Call **`get-onboarding-status`** (MCP) or `testchimp get-onboarding-status` (CLI). Pass `userId` when you have the workspace user (same value you use for `report-agent-action`).
2. Read the response (protobuf JSON, camelCase):
   - `nextStepCommand` — the `/testchimp …` command to suggest next. Empty means the next step happens in the TestChimp UI, or setup is done.
   - `steps[]` — `{ id, state }` with ids `LAUNCHPAD_STEP_*` and states `LAUNCHPAD_TODO | LAUNCHPAD_IN_PROGRESS | LAUNCHPAD_DONE | LAUNCHPAD_SKIPPED | LAUNCHPAD_STUCK`.
   - `completed` — every required step is done or skipped.
3. Tell the user in one or two lines, using the first that applies:
   - `LAUNCHPAD_STEP_FIRST_RESULTS` is `LAUNCHPAD_STUCK`: "Tests ran but no results reached TestChimp. The test runner needs `TESTCHIMP_API_KEY` in its own environment — export it in the shell that runs Playwright, then run the tests again."
   - `nextStepCommand` is non-empty: "Next: run `<nextStepCommand>`." plus a short reason taken from the step it belongs to.
   - First open step is `LAUNCHPAD_STEP_CONNECT_REPO`: "Next: connect your repo in TestChimp (Project Settings → Integrations)."
   - First open step is `LAUNCHPAD_STEP_FIRST_RESULTS`: "Next: run the tests so results reach TestChimp."
   - First open step is `LAUNCHPAD_STEP_VERIFY_TEST`: "Next: open a test in TestChimp, watch its video and Verify it."
   - `completed` is true: say nothing extra.

## Failure handling

The call is best-effort. If the tool is missing (older CLI/MCP), returns an error, or the backend answers 404, skip the hand-back silently — never fail or retry the workflow because of it. Never call `update-*` tools as part of this step; it is read-only.

# Onboarding next step (hand-back)

New TestChimp projects show a setup guide on the dashboard: create project → connect repo → connect your agent → initialize the project → author a few test plans → run QA → create a release → verify a test, then suggested next steps (view release health, invite the team, CI test execution, API schema coverage). The agent does most of these steps, so when a workflow finishes, tell the user what comes next instead of leaving them to work it out.

## When

At the very end of these commands (for catalog workflows, after the closing `report-agent-action`):

- `/testchimp check connectivity`
- `/testchimp project-init` (`project-init`)
- `/testchimp author plans` (`author-plans`)
- `/testchimp run-qa` (`run-qa`)
- `/testchimp create release` (`create-release`)
- `/testchimp invite team`
- `/testchimp configure execution of tests in CI`
- `/testchimp init` (`init`, legacy)

Skip it in `--mode=non-interactive` runs and for any other workflow.

## How

1. Call **`get-onboarding-status`** (MCP) or `testchimp get-onboarding-status` (CLI). Pass `userId` when you have the workspace user (same value you use for `report-agent-action`).
2. Read the response (protobuf JSON, camelCase):
   - `nextStepCommand` — the `/testchimp …` command to suggest next. Empty means the next step happens in the TestChimp UI, or setup is done.
   - `steps[]` — `{ id, state, command }` with ids `LAUNCHPAD_STEP_*` and states `LAUNCHPAD_TODO | LAUNCHPAD_DONE | LAUNCHPAD_SKIPPED`.
   - `followUps[]` — suggested next steps, same shape.
   - `completed` — every required step is done or skipped.
   - `visible` — the project is on the setup launchpad (new projects only).
3. If `visible` is not `true`, stop: existing projects get no hand-back.
4. Tell the user in one or two lines, using the first that applies:
   - `nextStepCommand` is non-empty: "Next: run `<nextStepCommand>`." plus a short reason from that step.
   - First open step is `LAUNCHPAD_STEP_CONNECT_REPO`: "Next: connect your repo in TestChimp (Project Settings → Integrations)."
   - First open step is `LAUNCHPAD_STEP_VERIFY_TEST`: "Next: open a test in TestChimp, watch its run video and Verify it."
   - `completed` is true: "Setup is done — see the suggested next steps in TestChimp (release health, inviting the team, CI)." Say it once per session at most.
   - Never suggest `/testchimp init`.

## Failure handling

The call is best-effort. If the tool is missing (older CLI/MCP), returns an error, or the backend answers 404, skip the hand-back silently — never fail or retry the workflow because of it. Never call `update-*` tools as part of this step; it is read-only.

# Onboarding next step (hand-back)

New TestChimp projects show a setup guide on the dashboard: create project → connect repo → connect your agent → initialize the project → author a few test plans → run QA → create a release → verify a test, then suggested next steps (view release health, invite the team, CI test execution, API schema coverage). The agent does most of these steps, so when a workflow finishes, tell the user what comes next instead of leaving them to work it out.

## When

At the very end of these commands (for catalog workflows, after the closing `report-agent-action`):

- `/testchimp connect-project`
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
   - `steps[]` — `{ id, state, command, subItems? }` with ids `LAUNCHPAD_STEP_*` and states `LAUNCHPAD_TODO | LAUNCHPAD_DONE | LAUNCHPAD_SKIPPED | LAUNCHPAD_STUCK`.
   - `followUps[]` — suggested next steps, same shape.
   - `completed` — every required step is done, skipped, or stuck (complete-with-gaps).
   - `visible` — the project is on the setup launchpad (new projects only).
3. If `visible` is not `true`, stop: existing projects get no hand-back.
4. Treat **`LAUNCHPAD_STUCK` and `LAUNCHPAD_SKIPPED` as closed** for sequencing. Do **not** re-suggest that step’s command, and do **not** mention its gaps (folder mapping, skipped git, and so on) on ordinary hand-backs. `nextStepCommand` already skips them; follow it.
5. Tell the user in **one short line**, using the first that applies:
   - `nextStepCommand` is non-empty: "Next: run `<nextStepCommand>`." Optionally one short reason for **that** next step only (from its title/purpose). Nothing about earlier stuck or skipped steps.
   - First **TODO** step is `LAUNCHPAD_STEP_CONNECT_REPO`: "Next: connect your repo in TestChimp (Project Settings → Integrations)."
   - First **TODO** step is `LAUNCHPAD_STEP_VERIFY_TEST`: "Next: open a test in TestChimp, watch its run video and Verify it."
   - `completed` is true: "Setup is done — see the suggested next steps in TestChimp (release health, inviting the team, CI)." Say it once per session at most.
   - Never suggest `/testchimp init`.
   - If you just ran `/testchimp connect-project` and `nextStepCommand` is still `/testchimp connect-project`, do not repeat it: follow [`connect-project.md`](./connect-project.md) (missing `TESTCHIMP_USER_ID` or an old CLI) and name the step after it.
6. **Do not** invent lines like "run `/testchimp project-init` (folder mapping still open)" or "After that, …" when `nextStepCommand` already names a later step. Mid-launchpad hand-backs are only the immediate next command (or the UI step above).

## After `/testchimp create release` only — git integration gap

When the workflow you just finished is **`create-release`**, after the normal next-step line above, check whether git is still missing:

- `LAUNCHPAD_STEP_CONNECT_REPO` is `LAUNCHPAD_SKIPPED` or `LAUNCHPAD_TODO`, **or**
- `LAUNCHPAD_STEP_PROJECT_INIT` is `LAUNCHPAD_STUCK` (folder mapping still open)

If so, add **one** extra sentence nudging the gap, for example: "Git is still not connected — connect the repo in TestChimp (Project Settings → Integrations) so folder mapping and team sync can finish." Do **not** re-run project-init from this hand-back; do **not** add this nudge after any other workflow.

CI executions can still bind without git (reporter path/title → stub SmartTests with empty script). Empty source in Studio after those runs means connect git + map the tests folder — see [`agent-quick-answers.md`](./agent-quick-answers.md#empty-smarttests-after-ci-when-git-was-skipped).

## Failure handling

The call is best-effort. If the tool is missing (older CLI/MCP), returns an error, or the backend answers 404, skip the hand-back silently — never fail or retry the workflow because of it. Never call `update-*` tools as part of this step; it is read-only.

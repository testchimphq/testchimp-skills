# Mocking strategy (TestChimp)

Opinionated defaults for **HTTP/API** vs **LLM** mocking for E2E testing. Use during **`/testchimp init`** (planning discovers existing setup; execution wires what the user opted into) and when authoring tests that need deterministic or error-path behavior.

## Principles

### Playwright `page.route` (HTTP / API)

- **Default choice** for selective HTTP/API stubbing in SmartTests: use Playwright’s native **[`page.route`](https://playwright.dev/docs/network#handle-requests)** (or `context.route`) to intercept requests and fulfill or abort with a controlled response.
- Use **when needed** for targeted outcomes (e.g. assert error UI when upstream returns **500**, empty list, validation error payload)—not as a way to avoid exercising the real stack unless the scenario is explicitly about that outcome.
- Prefer **shared helpers or fixtures** (see [`fixture-usage.md`](./fixture-usage.md)) so routes stay readable and reusable across specs.
- **Do not** add **MSW** as part of TestChimp’s default stack; teams that already use MSW may keep it, but new work should follow **`page.route`** unless there is a strong reason not to.

### AIMock (LLM / OpenAI-compatible traffic)

- **Optional during `/testchimp init`:** the agent **asks the user** whether to set up AIMock so LLM interactions in the stack can be **mocked during tests** with **record/replay when feasible** (see Phase 1 in [`init-testchimp.md`](./init-testchimp.md)).
- When enabled, use AIMock for **OpenAI-compatible** traffic (browser, backend, workers): streaming, record/replay, semantic matching—**not** generic REST stubs (use **`page.route`** or app-level test doubles for those).
- **Strongly recommended** for repos with LLM calls in the path under test: it **avoids ongoing LLM usage costs during test executions** compared to hitting real models every run. Users may **defer** AIMock and ask to wire it later; document **deferred** under `### Mocking Plan` with a short reason.

### Fixture location (AIMock record/replay)

- Store AIMock goldens/fixtures under **`<SmartTests root>/assets/goldens`** (the folder that contains `.testchimp-tests`).
- Point AIMock config (or CLI `--fixtures` / equivalent) at that path per [upstream AIMock docs](https://github.com/CopilotKit/aimock).

## What to record under `### Mocking Plan`

In `plans/knowledge/ai-test-instructions.md`, make the choices explicit, for example:

- **`http_mocking`:** `page.route` (default stance) | deferred | N/A — plus a one-line note if the repo uses something else (e.g. legacy MSW).
- **`aimock`:** enabled | deferred | not applicable — if deferred, **reason** (e.g. “set up in a follow-up init pass”).
- When AIMock is enabled or planned: **goldens path** (default `<SmartTests root>/assets/goldens`), **env/config** used to aim OpenAI-compatible traffic at AIMock during tests (e.g. `OPENAI_BASE_URL`), and **local vs CI** run notes.

## Plan vs execute

- **Planning phase:** Report what exists (any **`page.route`** helpers, AIMock packages, env vars for LLM base URL, existing goldens). Lock the above fields under `### Mocking Plan`. **AIMock** requires a **direct user decision** in init (see [`init-testchimp.md`](./init-testchimp.md)); do not treat AIMock as silently default-on.
- If the user uses another HTTP mocking approach, document it under `### Mocking Plan` and ask whether they want to align with **`page.route`** for new work.
- **Execution phase:**
  - Document or add **`page.route`** patterns as agreed—**no** default install of MSW.
  - **Only if `aimock: enabled`:** install AIMock per [upstream docs](https://github.com/CopilotKit/aimock), create `assets/goldens` if needed, refactor hardcoded OpenAI/base URLs into **config/env** for test runs, and ensure AIMock runs locally and in CI per vendor guidance.

## Upstream AIMock setup (authoritative detail)

Follow vendor documentation — do not duplicate it here:

- **Docs / repo:** [aimock.copilotkit.dev](https://aimock.copilotkit.dev), [CopilotKit/aimock on GitHub](https://github.com/CopilotKit/aimock)
- Typical patterns: OpenAI-compatible base URL aimed at the mock listener (often `OPENAI_BASE_URL` → `http://localhost:<port>/v1`), `npx` / config file, optional GitHub Action for CI, record/replay flags.

Map any upstream `fixtures` directory to **`<tests_root>/assets/goldens`** for consistency across TestChimp repos.

# Mocking strategy (TestChimp)

Opinionated defaults for **service** vs **LLM** mocking for E2E testing. Use during **`/testchimp init`** (planning discovers existing setup; execution installs and wires) and when authoring tests that need deterministic or error-path behavior.

## Principles

### MSW (Mock Service Worker)

- Use **when needed** for **generic HTTP/API mocking** — for example emulating a **specific** response so the UI can be asserted (error toast when upstream returns **500**, empty list, validation error payload).
- Use **sparingly**. MSW is **not** a shortcut to avoid running real flows end-to-end; prefer exercising the real stack unless the scenario is explicitly about handling a particular API outcome.
- Do **not** use MSW for **LLM** traffic — use **AIMock** (below).

### AIMock (LLM / OpenAI-compatible traffic)

- Use for **any LLM interaction** anywhere in the stack (browser, backend, workers, agents): OpenAI-compatible APIs, streaming, record/replay, semantic matching.
- **Do not** mock LLM calls with MSW — AIMock is built for streaming and realistic replay.

### Fixture location (AIMock record/replay)

- Store AIMock goldens/fixtures under **`<SmartTests root>/assets/goldens`** (the folder that contains `.testchimp-tests`).
- Point AIMock config (or CLI `--fixtures` / equivalent) at that path per [upstream AIMock docs](https://github.com/CopilotKit/aimock).

## Plan vs execute

- **Planning phase:** Report what exists (MSW, AIMock, env vars for LLM base URL, existing goldens). Lock requirements in `plans/knowledge/ai-test-instructions.md` under `### Mocking Plan`. This area usually needs **little user input** — the agent proposes where to wire AIMock and documents what was chosen.
- If the user uses some other solution for mocking in E2E tests - document that in the ai-test-instructions and continue to use that. However, ask whether they would like to move to TestChimp recommended defaults.
- **Execution phase:** Install dependencies, create `assets/goldens` if missing, refactor hardcoded OpenAI/base URLs into **config/env** (e.g. `OPENAI_BASE_URL` pointing at the AIMock server during tests), ensure AIMock runs for local and CI test runs as upstream recommends.

## Upstream AIMock setup (authoritative detail)

Follow vendor documentation — do not duplicate it here:

- **Docs / repo:** [aimock.copilotkit.dev](https://aimock.copilotkit.dev), [CopilotKit/aimock on GitHub](https://github.com/CopilotKit/aimock)
- Typical patterns: OpenAI-compatible base URL aimed at the mock listener (often `OPENAI_BASE_URL` → `http://localhost:<port>/v1`), `npx` / config file, optional GitHub Action for CI, record/replay flags.

Map any upstream `fixtures` directory to **`<tests_root>/assets/goldens`** for consistency across TestChimp repos.
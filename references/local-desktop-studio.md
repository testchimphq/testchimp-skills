# TestChimp Studio (LOCAL_DESKTOP)

Use this playbook when the agent runs **inside TestChimp Studio** (Electron desktop) or any local IDE against a folder that Studio mapped.

## Detect Studio / local desktop

Any of:

- Host is **TestChimp Studio** / OpenCode under Studio
- Workspace has **`<repo>/.testchimp/mcp.json`** (Studio writes this; gitignored)
- User says they are on Studio / local desktop (not ChimpHands CI)

Do **not** treat `CLOUD_AGENT` / GHA / `CHIMPHANDS_UI_ATTACHED` as Studio. Those use [`chimphands.md`](./chimphands.md).

## Shared worktree

- All agent **threads** share the **same** mapped workspace root.
- Do **not** assume a fresh clone or isolated worktree per thread.
- Prefer one branch / dirty tree awareness; coordinate edits so threads do not overwrite each other blindly.
- Global mapping registry is `~/.testchimp/projects.json` (desktop-owned; not committed).

## MCP config

1. Prefer **`<workspace>/.testchimp/mcp.json`** first when `TESTCHIMP_EXECUTION_SOURCE=LOCAL_DESKTOP` or the host is Studio (see **Finding project MCP config** in `SKILL.md`).
2. Studio Settings → MCP: edit **global** `~/.testchimp/mcp.json` (Cursor-like). Per-project MCP is `<workspace>/.testchimp/mcp.json` (edit in Code).
3. Export `TESTCHIMP_API_KEY` / `TESTCHIMP_PROJECT_ID` / optional `TESTCHIMP_USER_ID` / backend / ingress from that file’s `env` for runners.
4. Do **not** commit `.testchimp/` — it holds credentials. If it appears tracked or staged, stop and tell the user to unstage and keep `.testchimp/` in `.gitignore`.

## Skills

- Managed TestChimp skill is synced into **`.opencode/skills/testchimp`**.
- Settings → Skills → **Add from git**: paste a skill repo URL; Studio clones into **`~/.testchimp/skills/`** and materializes into **`.opencode/skills/<name>/`** for OpenCode.
- Refresh updates managed + user-registered skill repos.

## Playwright

- Prefer **Playwright Test CLI** (`npx playwright test …`) for authoring and runs.
- Do **not** enable or assume **Playwright MCP** by default (token-heavy). Only use Playwright MCP if the user explicitly configured it.

## Do not (Studio)

- Do **not** install or require GitHub Actions **ChimpHands** workflow files for local Studio runs.
- Do **not** follow the CI end-of-turn commit/push contract from [`chimphands.md`](./chimphands.md) unless the user explicitly asks for that CI flow.
- Do **not** launch Task/subagents for skill/doc lookup — read `.opencode/skills/testchimp/references/…` (or use the skill tool) in-thread. Studio denies Task and out-of-workspace path scans.
- Interactive approval still applies for catalog workflows unless `--mode=non-interactive` or policy allows otherwise.

## Meeting transcripts

Studio stores Meeting Bots transcripts under **`~/.testchimp/data/meetings/<meeting-id>/transcript.md`**. When a prompt says **`referring the meeting <meeting-id> as context`**, prefer that local file over cloud MCP. Full playbook: [`meeting-transcripts.md`](./meeting-transcripts.md).

## Init / keys

If `.testchimp/mcp.json` is missing, ask the user to **Map local folder** in Studio (or Project Settings → Key management → **Map local folder…**), or create/merge MCP config from [`../assets/sample-mcp.json`](../assets/sample-mcp.json) into `.testchimp/mcp.json` with real key + project id.

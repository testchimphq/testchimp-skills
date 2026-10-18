# testchimp-skills

TestChimp is the QA platform for coding agents. This repository is the **Claude Code plugin** (skill + hosted MCP) and the same skill pack other agents install from Git. Agents run pre-defined playbooks under **`references/`**; project-specific decisions live in **`plans/knowledge/policies/*.policy.md`**.

The plugin talks to the hosted MCP at **`https://mcp.testchimp.io/mcp`**. Sign-in is OAuth: you pick the TestChimp project on the consent screen, and every tool call is scoped to that project. Type **`/testchimp project-init`** and **`/testchimp init`** (same as other hosts). Claude Code’s `/` menu also lists **`/testchimp:<name>`** aliases for each testing workflow (`commands/*.md`). One person runs project-init once per repo. Everyone else runs only init. Plain language such as “set up TestChimp for this repo” also starts the skill.

## Claude Code plugin

Install from this marketplace, then sign in, then init. Do not invent extra commands.

1. **Install the plugin**

   ```
   /plugin marketplace add testchimphq/testchimp-skills
   /plugin install testchimp@testchimp
   ```

   On Claude Code v2.1.275+ you can do both in one step: `/plugin install testchimp --marketplace testchimphq/testchimp-skills`.

   **Restart the Claude Code session** after install. A session that is already running does not pick up the plugin until you quit and start it again.

2. **Sign in to the hosted MCP**

   Run **`/mcp`**, choose **`plugin:testchimp:testchimp`**, then **Authenticate**. The browser opens `https://mcp.testchimp.io/mcp` (OAuth through `https://featureservice.testchimp.io`).

   On the consent screen:
   - Pick the TestChimp project for **this** repository from the dropdown. That project is written into the token; every tool call is scoped to it. There is one global URL and no project IDs in the MCP config.
   - Leave **Use this connection as my QA bot** **unticked**. That box is for Grok Bot. Ticking it binds the connection as a QA bot instead of a normal coding-agent login.

   If you later open a repo that belongs to a different TestChimp project, `/testchimp init` will detect the mismatch and tell you to re-authenticate through **`/mcp`** and pick that repo's project.

3. **Init**

   | Who | Command | What it does |
   | --- | --- | --- |
   | One person, once per project | `/testchimp project-init` | Folder mapping, shared test env, CI, optional imports, team invites |
   | Every other teammate | `/testchimp init` | Confirm the plugin MCP, save a runner API key, wire the local stack |

   In Claude Code you can type those same commands, or pick **`/testchimp:project-init`** / **`/testchimp:init`** (and the other **`/testchimp:<name>`** workflow aliases) from the `/` menu. Other hosts use `/testchimp project init` / `/testchimp init`. Do not use `/testchimp:testchimp …`.

   **Time:** project-init with one-by-one tool approvals typically takes about **20 minutes** and on the order of **60 approval prompts**. Init is shorter. Pre-allow TestChimp's MCP tools (below) so you are not clicking through every call.

   Test runners (Playwright, k6, the CLI) still need a project API key. On hosted / plugin MCP, init calls `get-project-credentials` and writes the gitignored `.testchimp/mcp.json` with the file-write tool (never a shell command that contains the key). On local stdio MCP, it calls `save-workspace-creds` with only the folder. It does **not** write a second TestChimp server into the project's `.mcp.json`.

### Fewer approval prompts (Claude Code)

Add this to project **`.claude/settings.json`** or user settings so TestChimp MCP tools from this plugin do not prompt on every call ([permission rules](https://code.claude.com/docs/en/permissions), [plugin MCP names](https://code.claude.com/docs/en/mcp)):

```json
{
  "permissions": {
    "allow": [
      "mcp__plugin_testchimp_testchimp__*"
    ]
  }
}
```

That rule is `mcp__plugin_<plugin-name>_<server-name>__*`. This plugin's server key is `testchimp`, so the server segment is `plugin_testchimp_testchimp`. A single tool would be `mcp__plugin_testchimp_testchimp__get-project-init-status`. You can also choose **Always allow** the first time Claude Code asks for a TestChimp tool.

Update the plugin with `/plugin marketplace update testchimp`.

### What this plugin runs, sends and fetches

Installing the plugin loads this skill (`SKILL.md` and `references/`) and one remote MCP server:

- **Hosted MCP:** `https://mcp.testchimp.io/mcp` (Streamable HTTP). Claude Code signs in with OAuth. The authorization server is `https://featureservice.testchimp.io`. Tool calls send coverage, plans, issues, environments and similar QA data for the project you picked at consent.
- **Test runners / CLI (optional, after init):** `@testchimp/cli` on npm when a workflow runs CLI commands, plus the project's TestChimp API key stored in gitignored `.testchimp/mcp.json`. Ingress for reporters is `https://ingress.testchimp.io` unless the project overrides it.
- **Skill updates:** git fetch of `https://github.com/testchimphq/testchimp-skills` when you or the agent check for a newer skill version.

The plugin does not run a local MCP process and does not put an API key in Claude Code config.

## Primary commands

| Command | Workflow id | What it does |
|---------|-------------|--------------|
| `/testchimp init` (Claude Code menu: `/testchimp:init`) | `init` (One-Off) | Per-developer workstation: MCP sign-in, runner key, local env |
| `/testchimp project-init` (Claude Code menu: `/testchimp:project-init`) / `/testchimp project init` | `project-init` (One-Off) | One-time project setup: folder mapping, shared env, CI, optional imports |
| `/testchimp import` (Claude Code menu: `/testchimp:import-tests`) | `import` (One-Off) | Import existing E2E into SmartTests (Playwright as-is or translate) |
| `/testchimp import plans` (Claude Code menu: `/testchimp:import-plans`) | `import-plans` (One-Off) | Import existing plan markdown into mapped `plans/` |
| `/testchimp import-perf-tests` (Claude Code menu: `/testchimp:import-perf-tests`) | `import-perf-tests` (One-Off) | Import existing Locust/k6/JMeter/etc. into the TestChimp `k6/` folder |
| `/testchimp run QA` (Claude Code menu: `/testchimp:run-qa`) | `run-qa` | Full PR QA composite (plans → env → tests → smart smoke → ExploreChimp → TrueCoverage) |
| `/testchimp upkeep` (Claude Code menu: `/testchimp:upkeep`) | `upkeep` | Coverage / TrueCoverage / cleanup composite (periodic maintenance) |
| `/testchimp implement` | `implement` | Implement a story/scenario or a finetuned plan file end-to-end (skill-only; no Claude Code plugin command) |
| `/testchimp explore` (Claude Code menu: `/testchimp:explore`) | `run-explorechimp` | ExploreChimp UX analytics on SmartTest pathways |
| `/testchimp instrument` (Claude Code menu: `/testchimp:instrument-truecoverage`) | `instrument-truecoverage` | TrueCoverage / RUM instrumentation |
| `/testchimp create tests` (Claude Code menu: `/testchimp:create-tests`) | `create-tests` | Author/update SmartTests for a scope (plans, PR, or **API operation coverage**) |
| `/testchimp create policy` (Claude Code menu: `/testchimp:create-policy`) | `create-policy` | Author a `*.policy.md` for a catalog workflow |

**Synonyms (same workflow):** `/testchimp test` → **`run QA`**; `/testchimp evolve` (legacy `/testchimp audit`) → **`upkeep`**; `/testchimp plan` → **`author plans`**.

Thin / nested playbooks (also invokable on their own): **`connect-to-test-env`**, **`create-tests`**, **`execute-tests`**, **`run-smart-smoke`**, **`author-plans`**, **`fix-test-execution`**, **`fix-issue`**, **`cleanup`**, security scans, requirement quality, and more — see [Command routing](SKILL.md#command-routing) in **`SKILL.md`**.

Layout matches common single-skill repos (e.g. [bunnyshell/bunnyshell-environments-skill](https://github.com/bunnyshell/bunnyshell-environments-skill)): **`SKILL.md` at the repository root**, with **`references/`** and **`assets/`** beside it. **`name` in `SKILL.md` is `testchimp`**, so a git-clone install directory must be named **`testchimp`** (see [Agent Skills spec — `name` matches directory](https://agentskills.io/specification)).

## Install by host

| Host | Install |
| --- | --- |
| Claude Code | `/plugin marketplace add testchimphq/testchimp-skills` then `/plugin install testchimp@testchimp`, then **restart the session** |
| Any agent (skill only) | `npx skills add testchimphq/testchimp-skills` |
| Cursor | Cursor Marketplace (search TestChimp), or clone this repo as a Cursor plugin |
| Gemini CLI | `gemini extensions install https://github.com/testchimphq/testchimp-skills` |
| Kiro | Powers panel: import this repo (Agent Plugins `plugin.json`) |
| VS Code / GitHub Copilot | Install from the agent plugins gallery, or add the MCP server below |
| Codex / ChatGPT | Plugin directory once listed; or load this repo as a plugin |
| MCP only (hosted) | `https://mcp.testchimp.io/mcp` (OAuth, no API key in config) |
| MCP only (stdio) | `npx -y @testchimp/cli@latest mcp` with `TESTCHIMP_API_KEY` and `TESTCHIMP_USER_ID` |

See [`llms-install.md`](llms-install.md) for copy-paste MCP config.

**Entrypoint:** `SKILL.md` — then load the matching `references/*.md` (and default policy under `assets/policies/` when seeding).

---

## What’s new in 1.0.x (policy-aware skill)

From **v1.0.0** onward the skill is organized as a **modular workflow catalog**, not a handful of monolithic scripts:

1. **Playbooks** — battle-tested how-to in **`references/<workflow>.md`** (renamed to match catalog ids: `run-qa`, `upkeep`, `run-explorechimp`, `instrument-truecoverage`, …).
2. **Policies** — team overrides in the mapped repo under **`plans/knowledge/policies/<workflow-id>.policy.md`**. Init seeds defaults from **`assets/policies/`**. When a policy is missing, **`plans/knowledge/ai-test-instructions.md`** remains the fallback.
3. **Composites** — **`run-qa`** and **`upkeep`** declare **subflows** in their policy (e.g. author-plans → connect-to-test-env → create-tests → …). Agents follow the composite order and can still run a subflow alone.
4. **Traceability** — Plan phases mint a **`workflow_execution_id`** (ULID); plans live under **`plans/knowledge/workflow_plans/<workflow-id>/`**; upload via **`upsert-plans-support-file`** before Execute; mutating work reports via **`report-agent-action`** / inline **`agentTraceability`**. Details: [`references/policies-and-traceability.md`](references/policies-and-traceability.md).
5. **CLI/MCP** — workflow tools (`get-policy`, `list-policies`, `upsert-policy`, `list-workflow-catalog`, `get-last-run-workflow-detail`, …) plus **API operation coverage** (`list-api-operation-services`, `list-api-operations`, `get-api-operation-detail`, CLI ≥ **0.1.28**). Pin **`@testchimp/cli`** to at least **`required_cli_version`** in **`SKILL.md`**.

**Upgrade note:** If your installed skill is older than **1.0.0**, upgrade now (`/testchimp skill upgrade` / `git pull`). Policy and traceability tooling assume 1.0+.

Overview docs: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Project structure

```text
testchimp-skills/
├── .claude-plugin/
│   ├── plugin.json          # Claude Code / directory manifest
│   └── marketplace.json     # self-hosted marketplace "testchimp"
├── .mcp.json                # hosted MCP, global URL
├── SKILL.md                 # Entrypoint: preamble, routing, guardrails
├── commands/                # Claude Code only: /testchimp:<name> menu aliases (see SKILL.md Command routing)
├── README.md                # Install + 1.0 overview (this file)
├── LICENSE
├── scripts/
│   └── testchimp-preamble-check
├── references/              # One playbook (or deep dive) per concern
│   ├── init-testchimp.md
│   ├── project-init-testchimp.md
│   ├── run-qa.md            # /testchimp run QA (synonym: test)
│   ├── upkeep.md            # /testchimp upkeep (synonym: evolve)
│   ├── implement-requirement.md
│   ├── author-plans.md
│   ├── connect-to-test-env.md
│   ├── execute-tests.md
│   ├── run-smart-smoke.md
│   ├── run-smart-regression.md  # legacy stub → run-smart-smoke
│   ├── run-explorechimp.md
│   ├── instrument-truecoverage.md
│   ├── create-policy.md
│   ├── policies-and-traceability.md
│   ├── write-smarttests.md
│   ├── auth-flows.md        # Sign-up / OTP / MFA / reset without real inboxes
│   ├── cli.md
│   └── …
└── assets/
    ├── policies/            # Default policies seeded on init
    ├── logo-512.png
    ├── sample-mcp.json
    ├── sample-mcp.remote.json
    ├── template_smarttests.yml
    ├── guide/SAMPLE_PLANS.md
    └── template_*.config.*
```

In the **application repo** (after init / Git sync), policies live at:

```text
plans/knowledge/policies/
├── run-qa.policy.md
├── upkeep.policy.md
├── connect-to-test-env.policy.md
└── …
```

Product: [testchimp.io](https://testchimp.io)

---

## Skill-only install (git clone)

**Repository:** [https://github.com/testchimphq/testchimp-skills](https://github.com/testchimphq/testchimp-skills)
**Default branch:** `main`

Clone **into a directory literally named `testchimp`** under your host’s skills parent:

```bash
mkdir -p <skills-parent>
git clone https://github.com/testchimphq/testchimp-skills.git <skills-parent>/testchimp
```

If **`testchimp` already exists**, either update in place (see [Updating](#updating)) or replace:

```bash
rm -rf <skills-parent>/testchimp
git clone https://github.com/testchimphq/testchimp-skills.git <skills-parent>/testchimp
```

### `<skills-parent>` by host

| Host | Global | Project (workspace) |
|------|--------|----------------------|
| Claude Code | `~/.claude/skills` | `.claude/skills` |
| Amazon Kiro | `~/.kiro/skills` | `.kiro/skills` |
| Cursor | `~/.cursor/skills` | `.cursor/skills` |
| OpenAI Codex | `~/.agents/skills` | `.agents/skills` |
| GitHub Copilot | `~/.copilot/skills` or `~/.claude/skills` or `~/.agents/skills` | `.github/skills` or `.claude/skills` or `.agents/skills` |

### Copy-paste examples

**Claude Code (global skill, not the plugin):**

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/testchimphq/testchimp-skills.git ~/.claude/skills/testchimp
```

**Amazon Kiro (global):**

```bash
mkdir -p ~/.kiro/skills
git clone https://github.com/testchimphq/testchimp-skills.git ~/.kiro/skills/testchimp
```

**Kiro workspace (project):**

```bash
mkdir -p .kiro/skills
git clone https://github.com/testchimphq/testchimp-skills.git .kiro/skills/testchimp
```

### After install

Restart the IDE or CLI session if the skill does not appear.

**Amazon Kiro — skills vs steering:** This pack is a **skill** under **`.kiro/skills`** / **`~/.kiro/skills`**. **Steering** uses **`.kiro/steering/`** / **`~/.kiro/steering/`** ([Steering](https://kiro.dev/docs/cli/steering/) vs [Agent Skills](https://kiro.dev/docs/skills/)).

**Kiro / GitHub import:** [SKILL.md on `main`](https://github.com/testchimphq/testchimp-skills/blob/main/SKILL.md) ([Kiro import rules](https://kiro.dev/docs/skills/)). For ongoing updates, prefer a **git clone** install so **`git pull`** works.

**Slash / discovery:** **`/testchimp`**. Docs: [Cursor](https://www.cursor.com/docs/context/skills), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/skills), [Codex](https://developers.openai.com/codex/skills/), [Copilot skills](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills), [Kiro](https://kiro.dev/docs/skills/).

---

## Updating

Use this when the user or workflow wants the **latest skill content** from `main` (same as **`/testchimp skill upgrade`** / **`/testchimp update`**). Plugin installs should use **`/plugin marketplace update testchimp`** instead.

1. Resolve the skill root **`SKILL_DIR`** (the directory that contains **`SKILL.md`** and **`.git`**), e.g. `~/.claude/skills/testchimp` or `.cursor/skills/testchimp`.
2. Run:

```bash
git -C "$SKILL_DIR" fetch origin
git -C "$SKILL_DIR" merge origin/main
```

Or a single step (if `main` tracks `origin/main`):

```bash
git -C "$SKILL_DIR" pull origin main
```

3. **Restart** the IDE or agent session if the host caches skill files.

**If `SKILL_DIR` has no `.git`** (old copy-only install): run a fresh **clone** into a temp path, then replace the skill folder contents, or remove **`SKILL_DIR`** and re-run [Skill-only install](#skill-only-install-git-clone).

**Agents:** Search the user machine for **`testchimp/SKILL.md`** under known parents (`~/.claude/skills`, `~/.cursor/skills`, `~/.kiro/skills`, `~/.agents/skills`, project `.claude/skills`, `.cursor/skills`, `.kiro/skills`, `.agents/skills`, `.github/skills`) and use that directory as **`SKILL_DIR`**.

---

## Copy-only install (fallback)

If policy forbids **`.git`** under skills, use a one-off sync (no in-place `git pull` afterward):

```bash
git clone https://github.com/testchimphq/testchimp-skills.git /tmp/testchimp-skills-tmp
mkdir -p <skills-parent>
rsync -a --exclude='.git' /tmp/testchimp-skills-tmp/ <skills-parent>/testchimp/
rm -rf /tmp/testchimp-skills-tmp
```

Repeat that block (or re-clone) when you need updates.

---

## Usage examples

```
/testchimp init
/testchimp:init
/testchimp project-init
/testchimp:project-init
/testchimp project init
/testchimp run QA
/testchimp upkeep
/testchimp implement US-12
/testchimp execute tests tests/checkout in QA
/testchimp explore
/testchimp create policy for connect-to-test-env
/testchimp skill upgrade
```

Natural-language equivalents still route correctly (e.g. “Write tests for this PR” → **`run QA`**; “Analyze coverage gaps and fix them” → **`upkeep`**). Full table: **`SKILL.md`** → Command routing.

---

## MCP

**Two modes supported:**

1. **Hosted (OAuth)** — recommended, and what the Claude Code plugin bundles: `https://mcp.testchimp.io/mcp` with `type: http`. No API key in MCP config. The user picks the TestChimp project during sign-in. Plugin manifests in this repo (`.mcp.json`, `.cursor-plugin/plugin.json`, `gemini-extension.json`, `.codex-plugin/plugin.json`) register that same global URL. Test runners still need `TESTCHIMP_API_KEY` in the runner process environment.

2. **Stdio (local process)**: `npx -y @testchimp/cli@latest mcp` with `TESTCHIMP_API_KEY`, `TESTCHIMP_USER_ID`, and `TESTCHIMP_PROJECT_ID` in the server's `env` block. Use at project level (`.cursor/mcp.json` or `.mcp.json`) only when you are not using the plugin. Template: `assets/sample-mcp.json`.

During **`/testchimp init`**, agents keep a plugin-provided server if it is already connected. They do not write a second TestChimp entry. Full steps: **`references/init-testchimp.md`** (Workstation gate). Agents verify CLI compatibility via **Preamble checks** in **`SKILL.md`**.

Policy / workflow MCP tools (CLI ≥ **0.1.21**, skill **`required_cli_version`** may be higher): **`get-policy`**, **`list-policies`**, **`upsert-policy`**, **`list-workflow-catalog`**, **`report-agent-action`**, **`get-last-run-workflow-detail`**.

---

## Privacy and support

- **Privacy policy:** https://testchimp.io/privacy-policy
- **Terms:** https://testchimp.io/terms-conditions
- **Support:** https://testchimp.io/contact-us, contact@testchimp.io, or open an issue at https://github.com/testchimphq/testchimp-skills/issues
- **Docs:** https://docs.testchimp.io

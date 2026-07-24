# testchimp-skills

TestChimp skill for **policy-backed QA workflows** (skill **≥ 1.0.0**). Agents run pre-defined playbooks under **`references/`**; project-specific decisions live in **`plans/knowledge/policies/*.policy.md`**. Use with **`@testchimp/cli`** (≥ **`required_cli_version`** in **`SKILL.md`**) and **`TESTCHIMP_API_KEY`**.

**Primary commands**

| Command | Workflow id | What it does |
|---------|-------------|--------------|
| `/testchimp init` | `init` (bootstrap) | Set up QA infra, seed default policies, MCP / workstation gate |
| `/testchimp run QA` | `run-qa` | Full PR QA composite (plans → env → tests → regression → ExploreChimp → TrueCoverage) |
| `/testchimp upkeep` | `upkeep` | Coverage / TrueCoverage / cleanup composite (periodic maintenance) |
| `/testchimp implement` | `implement` | Implement a story/scenario end-to-end |
| `/testchimp explore` | `run-explorechimp` | ExploreChimp UX analytics on SmartTest pathways |
| `/testchimp instrument` | `instrument-truecoverage` | TrueCoverage / RUM instrumentation |
| `/testchimp create policy` | `create-policy` | Author a `*.policy.md` for a catalog workflow |

**Synonyms (same workflow):** `/testchimp test` → **`run QA`**; `/testchimp evolve` (legacy `/testchimp audit`) → **`upkeep`**; `/testchimp plan` → **`author plans`**.

Thin / nested playbooks (also invokable on their own): **`connect-to-test-env`**, **`create-tests`**, **`execute-tests`**, **`run-smart-regression`**, **`author-plans`**, **`fix-test-execution`**, **`fix-issue`**, **`cleanup`**, security scans, requirement quality, and more — see [Command routing](SKILL.md#command-routing) in **`SKILL.md`**.

Layout matches common single-skill repos (e.g. [bunnyshell/bunnyshell-environments-skill](https://github.com/bunnyshell/bunnyshell-environments-skill)): **`SKILL.md` at the repository root**, with **`references/`** and **`assets/`** beside it. **`name` in `SKILL.md` is `testchimp`**, so the install directory must be named **`testchimp`** (see [Agent Skills spec — `name` matches directory](https://agentskills.io/specification)).

**Recommended install:** **git clone** into **`<skills-parent>/testchimp`** and keep **`.git`** so agents can **`git pull`** for updates (`/testchimp skill upgrade`).

**Entrypoint:** `SKILL.md` — then load the matching `references/*.md` (and default policy under `assets/policies/` when seeding).

---

## What’s new in 1.0.x (policy-aware skill)

From **v1.0.0** onward the skill is organized as a **modular workflow catalog**, not a handful of monolithic scripts:

1. **Playbooks** — battle-tested how-to in **`references/<workflow>.md`** (renamed to match catalog ids: `run-qa`, `upkeep`, `run-explorechimp`, `instrument-truecoverage`, …).
2. **Policies** — team overrides in the mapped repo under **`plans/knowledge/policies/<workflow-id>.policy.md`**. Init seeds defaults from **`assets/policies/`**. When a policy is missing, **`plans/knowledge/ai-test-instructions.md`** remains the fallback.
3. **Composites** — **`run-qa`** and **`upkeep`** declare **subflows** in their policy (e.g. author-plans → connect-to-test-env → create-tests → …). Agents follow the composite order and can still run a subflow alone.
4. **Traceability** — Plan phases mint a **`workflow_execution_id`** (ULID); mutating work reports via **`report-agent-action`** / inline **`agentTraceability`**. Details: [`references/policies-and-traceability.md`](references/policies-and-traceability.md).
5. **CLI/MCP** — workflow tools (`get-policy`, `list-policies`, `upsert-policy`, `list-workflow-catalog`, `get-last-run-workflow-detail`, …). Pin **`@testchimp/cli`** to at least **`required_cli_version`** in **`SKILL.md`**.

**Upgrade note:** If your installed skill is older than **1.0.0**, upgrade now (`/testchimp skill upgrade` / `git pull`). Policy and traceability tooling assume 1.0+.

Overview docs: [QA on Autopilot (TestChimp + Claude)](https://docs.testchimp.io/qa-autopilot-claude/intro).

---

## Project structure

```text
testchimp-skills/
├── SKILL.md                 # Entrypoint: preamble, routing, guardrails
├── README.md                # Install + 1.0 overview (this file)
├── LICENSE
├── bin/
│   └── testchimp-preamble-check
├── references/              # One playbook (or deep dive) per concern
│   ├── init-testchimp.md
│   ├── run-qa.md            # /testchimp run QA (synonym: test)
│   ├── upkeep.md            # /testchimp upkeep (synonym: evolve)
│   ├── implement-requirement.md
│   ├── author-plans.md
│   ├── connect-to-test-env.md
│   ├── execute-tests.md
│   ├── run-smart-regression.md
│   ├── run-explorechimp.md
│   ├── instrument-truecoverage.md
│   ├── create-policy.md
│   ├── policies-and-traceability.md
│   ├── write-smarttests.md
│   ├── cli.md
│   └── …
└── assets/
    ├── policies/            # Default policies seeded on init
    │   ├── run-qa.policy.md
    │   ├── upkeep.policy.md
    │   ├── connect-to-test-env.policy.md
    │   └── implement.policy.md
    ├── sample-mcp.json
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

## Installation

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

**Claude Code (global):**

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

Use this when the user or workflow wants the **latest skill content** from `main` (same as **`/testchimp skill upgrade`** / **`/testchimp update`**).

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

**If `SKILL_DIR` has no `.git`** (old copy-only install): run a fresh **clone** into a temp path, then replace the skill folder contents, or remove **`SKILL_DIR`** and re-run [Installation](#installation).

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

**`@testchimp/cli`** is not part of this skill tree. Install it in the app repo (**`@testchimp/cli@latest`**, or pin ≥ **`required_cli_version`** in **`SKILL.md`** frontmatter). During **`/testchimp init`**, agents **create or merge** the **project-level** MCP config (Cursor: **`.cursor/mcp.json`**; Claude Code: **`.mcp.json`**) from **`assets/sample-mcp.json`**, including placeholders for **`TESTCHIMP_API_KEY`** and **`TESTCHIMP_PROJECT_ID`**. Use **`npx`** with **`@testchimp/cli@latest`** in **`args`**. Pair with **`@testchimp/playwright` ≥ 0.2.0** for execution device context on ingest. Full steps: **`references/init-testchimp.md`** (Workstation gate). Agents verify CLI compatibility via **Preamble checks** in **`SKILL.md`**.

Policy / workflow MCP tools (CLI ≥ **0.1.21**, skill **`required_cli_version`** may be higher): **`get-policy`**, **`list-policies`**, **`upsert-policy`**, **`list-workflow-catalog`**, **`report-agent-action`**, **`get-last-run-workflow-detail`**.

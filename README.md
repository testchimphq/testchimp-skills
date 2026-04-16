# testchimp-skills

TestChimp skill for **`/testchimp`** flows: `/init`, `/test`, `/audit`, plus **TrueCoverage** (`/testchimp setup truecoverage`, `/testchimp instrument` — see `references/truecoverage.md`). Use with **`testchimp-mcp-client`** and **`TESTCHIMP_API_KEY`**.

Layout matches common single-skill repos (e.g. [bunnyshell/bunnyshell-environments-skill](https://github.com/bunnyshell/bunnyshell-environments-skill)): **`SKILL.md` at the repository root**, with **`references/`** and **`assets/`** beside it. **`name` in `SKILL.md` is `testchimp`**, so the install directory must be named **`testchimp`** (see [Agent Skills spec — `name` matches directory](https://agentskills.io/specification)).

**Recommended install:** **git clone** into **`<skills-parent>/testchimp`** and keep **`.git`** so agents can **`git pull`** for updates.

**Entrypoint:** `SKILL.md` — then `references/*.md` and `assets/` as needed.

## Project structure

```text
testchimp-skills/
├── SKILL.md              # Skill entrypoint (routing + overview)
├── README.md             # Install notes (this file)
├── LICENSE
├── references/
│   ├── init-testchimp.md
│   ├── write-smarttests.md
│   ├── audit-coverage.md
│   ├── truecoverage.md
│   └── ai-wright-usage.md
└── assets/
    ├── template_playwright.config.js
    └── sample-mcp.json
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

Use this when the user or workflow wants the **latest skill content** from `main`.

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
Set up TestChimp in this repo (reporter, markers, MCP env)
Write a SmartTest for scenario #TS-102 from plans
Audit requirement coverage for tests/checkout and propose missing tests
Update the TestChimp skill from Git
```

---

## MCP

**`testchimp-mcp-client`** is not part of this skill tree. Install it in the app repo (**`testchimp-mcp-client@latest`**), ask user to configure **`TESTCHIMP_API_KEY`** in the env block of mcp.json (have a placeholder so that it is clear where to update). Use **`npx`** with **`testchimp-mcp-client@latest`** in **`args`** so **`npx`** picks up new releases. Sample: **`assets/sample-mcp.json`**. Full steps: **`references/init-testchimp.md`**. **`SKILL.md`** frontmatter includes **`required_mcp_client_version`** so agents can verify compatibility (see **Preamble checks** there).

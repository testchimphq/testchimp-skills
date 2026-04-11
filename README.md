# testchimp-skills

TestChimp skill for **`/testchimp`** flows: `/init`, `/test`, `/audit`. Use with **`testchimp-mcp-client`** and **`TESTCHIMP_API_KEY`**.

Layout matches common single-skill repos (e.g. [bunnyshell/bunnyshell-environments-skill](https://github.com/bunnyshell/bunnyshell-environments-skill)): **`SKILL.md` at the repository root**, with **`references/`** and **`assets/`** beside it. **`name` in `SKILL.md` is `testchimp`**, so the folder you install into must be named **`testchimp`** (see [Agent Skills spec — `name` matches directory](https://agentskills.io/specification)).

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
│   └── ai-wright-usage.md
└── assets/
    └── template_playwright.config.js
```

Product: [testchimp.io](https://testchimp.io)

---

## Installation

Install by copying this repository into **`<skills-parent>/testchimp/`** so **`SKILL.md`** ends up at **`<skills-parent>/testchimp/SKILL.md`**. Exclude **`.git`** unless you intend to nest a full clone.

Replace **`<repo-url>`** with this repository’s URL (or path to a local checkout).

### Option 1 — Global (user home)

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p <skills-parent>
rsync -a --exclude='.git' /tmp/testchimp-skills-tmp/ <skills-parent>/testchimp/
rm -rf /tmp/testchimp-skills-tmp
```

**`<skills-parent>`** examples:

| Host | Global `<skills-parent>` |
|------|---------------------------|
| Claude Code | `~/.claude/skills` |
| Amazon Kiro | `~/.kiro/skills` |
| Cursor | `~/.cursor/skills` |
| OpenAI Codex | `~/.agents/skills` |
| GitHub Copilot (user) | `~/.copilot/skills` or `~/.claude/skills` or `~/.agents/skills` |

**Claude Code (copy-paste):**

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p ~/.claude/skills
rsync -a --exclude='.git' /tmp/testchimp-skills-tmp/ ~/.claude/skills/testchimp/
rm -rf /tmp/testchimp-skills-tmp
```

**Amazon Kiro (copy-paste):**

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p ~/.kiro/skills
rsync -a --exclude='.git' /tmp/testchimp-skills-tmp/ ~/.kiro/skills/testchimp/
rm -rf /tmp/testchimp-skills-tmp
```

### Option 2 — Project (workspace)

From the **application repository root**:

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p <skills-parent>
rsync -a --exclude='.git' /tmp/testchimp-skills-tmp/ <skills-parent>/testchimp/
rm -rf /tmp/testchimp-skills-tmp
```

| Host | Project `<skills-parent>` |
|------|---------------------------|
| Claude Code | `.claude/skills` |
| Amazon Kiro | `.kiro/skills` |
| Cursor | `.cursor/skills` |
| OpenAI Codex | `.agents/skills` |
| GitHub Copilot | `.github/skills` or `.claude/skills` or `.agents/skills` |

**Kiro workspace (copy-paste):**

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p .kiro/skills
rsync -a --exclude='.git' /tmp/testchimp-skills-tmp/ .kiro/skills/testchimp/
rm -rf /tmp/testchimp-skills-tmp
```

### Existing checkout (no temp clone)

```bash
SOURCE=/path/to/testchimp-skills
mkdir -p <skills-parent>/testchimp
rsync -a --exclude='.git' "$SOURCE/" <skills-parent>/testchimp/
```

### After install

Restart the IDE or CLI session if the skill does not appear.

**Amazon Kiro — skills vs steering:** This pack is a **skill** under **`.kiro/skills`** / **`~/.kiro/skills`**. **Steering** directives use **`.kiro/steering/`** / **`~/.kiro/steering/`** ([Steering](https://kiro.dev/docs/cli/steering/) vs [Agent Skills](https://kiro.dev/docs/skills/)).

**Kiro / GitHub import:** You can import from a URL pointing at this repo’s **`SKILL.md`** on the default branch, or at the repo path that contains `SKILL.md` at the root ([Kiro import rules](https://kiro.dev/docs/skills/)).

**Slash / discovery:** **`/testchimp`** (or host equivalent). Docs: [Cursor](https://www.cursor.com/docs/context/skills), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/skills), [Codex](https://developers.openai.com/codex/skills/), [Copilot skills](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills), [Kiro](https://kiro.dev/docs/skills/).

---

## Usage examples

```
Set up TestChimp in this repo (reporter, markers, MCP env)
Write a SmartTest for scenario #TS-102 from plans
Audit requirement coverage for tests/checkout and propose missing tests
```

---

## MCP

**`testchimp-mcp-client`** is not part of this skill tree. Install it in the app repo, register MCP with **`TESTCHIMP_API_KEY`**. Steps: **`references/init-testchimp.md`**.

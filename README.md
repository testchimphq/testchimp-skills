# testchimp-skills

TestChimp skill for **`/testchimp`** flows: `/init`, `/test`, `/audit`. Use with **`testchimp-mcp-client`** and **`TESTCHIMP_API_KEY`**.

**Entrypoint:** `testchimp/SKILL.md` — route from there to `references/*.md` and `assets/` as needed.

```text
testchimp-skills/
  README.md
  testchimp/
    SKILL.md
    references/
      init-testchimp.md
      write-smarttests.md
      audit-coverage.md
      ai-wright-usage.md
    assets/
      template_playwright.config.js
```

Product: [testchimp.io](https://testchimp.io)

---

## Installation

Copy the **`testchimp/`** subtree (not the repo root) so you end up with **`<skills-parent>/testchimp/SKILL.md`** plus **`references/`** and **`assets/`**.

Replace **`<repo-url>`** with this repository’s clone URL (or use a local path to a checkout).

### Option 1 — Global (user home)

Pick the skills parent for your host, then run:

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p <skills-parent>
cp -R /tmp/testchimp-skills-tmp/testchimp <skills-parent>/testchimp
rm -rf /tmp/testchimp-skills-tmp
```

Examples — set **`<skills-parent>`** to one of:

| Host | `<skills-parent>` (global) |
|------|----------------------------|
| Claude Code | `~/.claude/skills` |
| Amazon Kiro | `~/.kiro/skills` |
| Cursor | `~/.cursor/skills` |
| OpenAI Codex | `~/.agents/skills` |
| GitHub Copilot (user) | `~/.copilot/skills` or `~/.claude/skills` or `~/.agents/skills` |

Concrete example for **Claude Code**:

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p ~/.claude/skills
cp -R /tmp/testchimp-skills-tmp/testchimp ~/.claude/skills/testchimp
rm -rf /tmp/testchimp-skills-tmp
```

Concrete example for **Amazon Kiro**:

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p ~/.kiro/skills
cp -R /tmp/testchimp-skills-tmp/testchimp ~/.kiro/skills/testchimp
rm -rf /tmp/testchimp-skills-tmp
```

### Option 2 — Project (workspace / repo)

From the **application repository root**:

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p <skills-parent>
cp -R /tmp/testchimp-skills-tmp/testchimp <skills-parent>/testchimp
rm -rf /tmp/testchimp-skills-tmp
```

Examples — set **`<skills-parent>`** to one of:

| Host | `<skills-parent>` (project) |
|------|-----------------------------|
| Claude Code | `.claude/skills` |
| Amazon Kiro | `.kiro/skills` |
| Cursor | `.cursor/skills` |
| OpenAI Codex | `.agents/skills` |
| GitHub Copilot | `.github/skills` or `.claude/skills` or `.agents/skills` |

Concrete example for **Kiro workspace**:

```bash
git clone <repo-url> /tmp/testchimp-skills-tmp
mkdir -p .kiro/skills
cp -R /tmp/testchimp-skills-tmp/testchimp .kiro/skills/testchimp
rm -rf /tmp/testchimp-skills-tmp
```

### Existing checkout (no temp clone)

```bash
SOURCE=/path/to/testchimp-skills
mkdir -p <skills-parent>/testchimp
rsync -a "$SOURCE/testchimp/" <skills-parent>/testchimp/
```

### After install

Restart the IDE or CLI session if the skill does not appear.

**Amazon Kiro — skills vs steering:** Install this pack as a **skill** under **`.kiro/skills`** (workspace) or **`~/.kiro/skills`** (global). **Steering** (always-on markdown directives) lives under **`.kiro/steering/`** / **`~/.kiro/steering/`**—that is separate; see [Steering](https://kiro.dev/docs/cli/steering/) vs [Agent Skills](https://kiro.dev/docs/skills/).

**Kiro UI import:** In **Agent Steering & Skills**, **Import a skill** from GitHub; the URL must point at the **`testchimp/`** subdirectory (or `SKILL.md` inside it), not the repository root.

**Slash / discovery:** Use **`/testchimp`** (or your host’s skill picker) when you need the skill explicitly. Vendor docs: [Cursor](https://www.cursor.com/docs/context/skills), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/skills), [Codex](https://developers.openai.com/codex/skills/), [Copilot skills](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills), [Kiro](https://kiro.dev/docs/skills/).

---

## Usage examples

```
Set up TestChimp in this repo (reporter, markers, MCP env)
Write a SmartTest for scenario #TS-102 from plans
Audit requirement coverage for tests/checkout and propose missing tests
```

---

## MCP

**`testchimp-mcp-client`** is not inside this skill folder. Install it in the app repo, register MCP with **`TESTCHIMP_API_KEY`**. Steps: **`testchimp/references/init-testchimp.md`**.

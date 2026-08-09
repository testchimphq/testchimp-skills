# Split-repo / multi-root workspaces

Teams may map a **TestChimp-only repo** (essentially `plans/` + `tests/`) while product application code lives in one or more other repositories. Local coding agents support this via a **multi-root workspace**.

## When to use

- The product spans **multiple repos**, or
- The team prefers the **TestChimp-mapped repo** to stay separate from the product repo(s) (plans/tests only).

## Workspace setup (local agents)

1. Create (or open) a workspace in the preferred agent/IDE (Cursor, VS Code, etc.).
2. Add the **product repo folder(s)** to the workspace.
3. Add the **TestChimp-mapped repo** (the one with `plans/` and `tests/`, and `.testchimp-plans` / `.testchimp-tests` markers) to the same workspace.

The agent reads product roots for **context**; it authors **plans** under the plans root and **SmartTests** under the SmartTests root.

## Write boundaries

| Artifact | Where to write |
|----------|----------------|
| Plans, policies, workflow plans, `ai-test-instructions.md` | Plans root (directory with **`.testchimp-plans`**) |
| SmartTests, fixtures, Playwright/Mobilewright config | SmartTests root (directory with **`.testchimp-tests`**) |
| Product application code | Product workspace root(s) — **only** when the user (or an explicit workflow like `/testchimp implement`) asks for product changes |

Do **not** invent product app code inside the mapped TestChimp repo when it is plans/tests-only.

## Read boundaries

When inferring journeys, routes, components, APIs, or PR/branch intent:

- Prefer **product workspace roots** for application source.
- Use the mapped repo for existing plans, specs, fixtures, and harness conventions.
- Still run Playwright / Mobilewright **only** from the SmartTests root (`SKILL.md` Agent guardrails).

## Detection (inform the user once)

Treat the setup as **likely split-repo** when **both** are true:

1. Markers live in a git root whose non-TestChimp content is **thin** — essentially `plans/`, `tests/` (or renamed mapped folders), markers, MCP config, scaffold/config files — little or no application `src/` / app manifests.
2. Other workspace roots look like **product apps** (substantial source trees, app `package.json` / Gradle / Xcode projects, etc.).

**When detected:** Tell the user once, briefly, that this looks like a split-repo workspace: product folders are for context; plans and tests stay in the mapped repo. Point them at the same multi-root approach above if a product folder is missing from the workspace.

Do **not** fail workflows solely because the mapped repo lacks product code — that is a supported layout.

## Cloud / single-clone agents

This pattern is primarily for **local multi-root** workspaces. Cloud or single-clone runners do **not** automatically see sibling product repos. If a cloud agent needs product context, that access must be configured separately for that runner — **do not assume** product siblings exist outside the cloned mapped repo.

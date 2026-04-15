# World states (`tests/setup/world-states`)

World states are **`*.world.js`** files under **`<test root>/setup/world-states`**. Each file exports a definition created with **`defineWorldState`** from **`playwright-testchimp/runtime`** (or `playwright-testchimp/worldstate`). They describe a **named, reusable seed** of the app (via APIs / env), so tests and agents can start from the same deterministic state.

## Shape

A world-state is a plain object that **`defineWorldState(def)`** validates and returns. Each **`*.world.js`** file should **`module.exports`** (or **`export default`**) that object—typically the return value of **`defineWorldState({ ... })`**.

**Imports** — Use **`defineWorldState`** (and, inside a file that orchestrates states, **`ensureWorldState`**) from **`playwright-testchimp/runtime`**.

### Fields (runtime contract)

| Field | Required | Purpose |
|--------|----------|---------|
| **`meta.id`** | Yes | Non-empty string. This exact value is passed to **`ensureWorldState('…')`**, **`teardownWorldState('…')`**, and listed in tooling. Use a **stable, kebab-case** id (e.g. `premium-org-admin-user-created`) so it stays merge-friendly and grep-friendly. |
| **`meta.description`** | Yes | Human- and agent-readable summary of what environment this state represents—use when choosing or reviewing states. |
| **`setup(ctx)`** | Yes | Function **`(ctx) => void` or `async (ctx) => void`**. Brings the environment to this state (HTTP seed APIs, DB fixtures, etc.). Prefer **`process.env.BACKEND_URL`** or service-specific **`*_BACKEND_URL`**; see **[`testing-process.md`](./testing-process.md)**. For how the deployment URL is chosen (persistent vs ephemeral, EaaS), see **[`environment-management.md`](./environment-management.md)**. |
| **`teardown(ctx)`** | No | If present, must be a function with the same **`ctx`** shape as **`setup`**. Omit if cleanup is unnecessary or handled elsewhere. |

Invalid definitions throw at load or at **`defineWorldState`** time (e.g. missing **`meta`**, **`setup`** not a function, **`teardown`** present but not a function).

### Registry and uniqueness

On the **first** call to **`ensureWorldState`**, **`getWorldStateById`**, or **`teardownWorldState`**, the runtime scans **`process.cwd()` recursively** for files named **`*.world.js`**, **`require`s** each file, reads **`module.exports`** or **`default`**, and validates it. **`meta.id`** values must be **unique** across all discovered files; duplicates throw with both paths.

**Implication for agents:** World-state files must live under the **test run working directory** (usually the repo’s tests root. Convention is `/setup/world-states` folder). Running from a different cwd may miss files or load a different set.

### `ctx` and teardown pairing

- **`ensureWorldState(id, ctx?)`** runs **`setup(ctx)`** with **`ctx`** defaulting to **`{}`** if omitted. It returns **`{ id, ctx, teardown }`** where **`teardown()`** calls **`teardown(ctx)`** on the **same object** **`setup`** received—so values you attach in **`setup`** (tokens, ids, handles) are visible in **`teardown`** when you use this return path.
- **`teardownWorldState(id, ctx?)`** looks up the definition and runs **`teardown(ctx)`** with **`ctx`** defaulting to **`{}`**. Use it when you did **not** keep the **`ensureWorldState`** return value (e.g. simplified-view codegen). **Do not** rely on **`teardownWorldState`** if **`teardown`** must see **`ctx`** mutated during **`setup`**; use **`ensureWorldState`** and its returned **`teardown`** instead.

### Minimal file example

```js
const { defineWorldState } = require('playwright-testchimp/runtime');

module.exports = defineWorldState({
  meta: {
    id: 'empty-cart-logged-in',
    description: 'Signed-in user with an empty cart.',
  },
  async setup(ctx) {
    // do data seeding - using seeding API endpoints
  },
  async teardown(ctx) {
    // do clean ups via API endpoint calls
  },
});
```

## Tests and agents

- **`await ensureWorldState('meta-id', ctx?)`** — Runs **`setup`** and returns **`{ id, ctx, teardown }`**. Semantics: **`ctx` and teardown pairing**; file discovery: **Registry and uniqueness**.
- **`await teardownWorldState('meta-id', ctx?)`** — Runs **`teardown`** only; default **`ctx`** is **`{}`** unless you pass one. Semantics: **`ctx` and teardown pairing**.
- **`getWorldStateById(id)`** — Returns the loaded definition; triggers the same registry scan. For tooling or debugging, not typical spec code.
- **Composition** — A world-state may call **`await ensureWorldState('prerequisite-id')`** at the start of its own **`setup`**. In **`teardown`**, tear down **your** state first, then prerequisites, so dependents clean up in reverse order.

## Planning vs execution (`/testchimp test`)

Phased detail lives in **[`testing-process.md`](./testing-process.md)**. In short:

- **Plan** — For each UI test, name the **target `meta.id`**, list **missing** `*.world.js` (and seed API gaps), and treat authoring those as **plan/setup** work—not an afterthought at the keyboard.
- **Setup** — Land the world-state scripts and seeds so **`ensureWorldState`** can run.
- **Execute** — **Apply the world-state** by running the world-state setup(), then** drive the app with **Playwright**. The agent brings the shared environment to the desired world-state **before** relying on browser actions to imply backend/data shape.

See also **[`write-smarttests.md`](./write-smarttests.md)** for SmartTest authoring patterns.

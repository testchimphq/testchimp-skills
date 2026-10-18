# Sample TestChimp plans

This file shows the **shape** of stories and scenarios. It does **not** assign ids.

**Never** put an `id:` (or any `US-…` / `TS-…`) in a new file yourself — not a real-looking number, and not a placeholder. Story and scenario ids come only from creating the entity through the author-plans tools. The platform assigns the ordinal.

## Create, then write

1. Call **`create-user-story`** or **`create-test-scenario`** (one at a time).
2. Read **`ordinalId`** and **`content`** from that response. The stub markdown already has the assigned `id:`.
3. Write that **`content`** to the mapped plans path. Edit the body if needed; keep the returned `id:` and (for scenarios) `story:`.

If this repo already has stories or scenarios, use **their** frontmatter `id:` values — never invent or copy an id from this guide.

## Story shape (do not save this as a file)

Call **`create-user-story`** first. The create response is what you write to disk. The body you add after that looks like:

```md
Summary and acceptance criteria.
```

## Scenario shape (do not save this as a file)

Call **`create-test-scenario`** after the parent story exists (use that story’s platform-assigned `US-…` as `userStoryOrdinalId`). The create response is what you write to disk. The body you add after that looks like:

```md
Prerequisites, steps, expected behaviour.
```

Link SmartTests with `{ type: 'scenario', description: '#TS-…' }` using the **same** id the create response assigned — not an id from this guide.

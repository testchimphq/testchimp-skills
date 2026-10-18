# Sample TestChimp plans

This file shows the **shape** of stories and scenarios. It does **not** assign real ids.

The platform issues ordinals when you call **`create-user-story`** / **`create-test-scenario`**. Those ordinals are remapped per project. Never copy `US-103`, `TS-104`, or any other literal id from a sample into a file or a SmartTest annotation.

## After you create entities

1. Call create for the story, then the scenario (one at a time).
2. Write the markdown using the **`ordinalId`** from that response (`id: US-<ordinalId>` / `id: TS-<ordinalId>`).
3. Link SmartTests with `{ type: 'scenario', description: '#TS-<ordinalId>' }` using the same returned id.

If this repo already has stories/scenarios, open those files and use **their** frontmatter `id:` values — not the placeholders below.

## Story shape

```md
---
type: story
id: US-<ordinalId>
title: Short title
---

Summary and acceptance criteria.
```

## Scenario shape

```md
---
type: scenario
id: TS-<ordinalId>
title: Short title
story: US-<parentStoryOrdinalId>
---

Prerequisites, steps, expected behaviour.
```

Replace every `<ordinalId>` / `<parentStoryOrdinalId>` with the integer the platform returned in this project. If you are only reading this guide, leave the placeholders as-is.

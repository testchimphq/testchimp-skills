# TrueCoverage instrumentation progress

This file tracks **planned vs completed** TrueCoverage event instrumentation for this repo.

- **Created/updated by**: `/testchimp init`, `/testchimp instrument`, `/testchimp audit`
- **What it is**: A durable source of truth for which semantic journey events should exist, grouped by **routes/pages**, and whether each is implemented.
- **What it is not**: A replacement for per-event docs under `plans/events/`. Those files are created when an event is actually instrumented.

## How to use

- **During init**:\n  - wire minimal TrueCoverage infra + a small initial event slice\n  - create `plans/events/*.event.md` only for events actually instrumented in init\n  - scan frontend routes/pages and fill out this file for the full planned set
- **During `/testchimp instrument`**:\n  - pick `planned` entries, implement emits in code, create the matching `plans/events/*.event.md`, then mark the entries `done` here
- **During `/testchimp audit`**:\n  - compare production gaps vs this plan; instrument missing `planned` items (or revise the plan if events are no longer meaningful)

## Status legend

- `done`: event emit exists in app code (and should have a matching `plans/events/<title>.event.md`)
- `planned`: event should exist but is not instrumented yet
- `deferred`: intentionally postponed (include a short reason)

## Last scanned

- Date: <!-- yyyy-mm-dd -->
- By: <!-- agent/human -->
- Frontend root(s): <!-- e.g. ui/, web/, apps/web -->

---

## Route/page: <route-or-page-name>

**Notes**: <!-- optional: what this page/journey does -->

- [planned] `<event-title-kebab-case>` — <short description of when it fires>
- [planned] `<event-title-kebab-case>` — <...>
- [done] `<event-title-kebab-case>` — <...>

**Related files** (optional):

- `<path-to-route-component-or-page>`
- `<path-to-analytics-or-emit-wrapper>`


# k6 dataset manifests

Commit manifests and synthetic examples, never credentials or production
payloads.

- `kind: "load"` describes a reusable synthetic identity pool. Concurrency is
  owned by the selected profile.
- `kind: "volume"` describes data cardinality/shape for a small number of
  tenants. Staircases use **one k6 run** that holds 1 VU at 10% / 50% / 100%
  of target (`volume_size` gauge). Naming: `volume-<kind>-{10,50,100}.json`.
  Ingest the **peak** (`-100`) dataset id as the comparison key.

`k6/scripts/seed.sh <manifest.json>` validates the common fields and passes the
manifest to the project-specific seed integration.

**Volume staircase seed contract:** `k6/scripts/run.sh` dispatches volume
journeys (via `testTypes: ['volume']` + `volumeKind`) to an internal
`run-volume-staircase.sh` helper. That helper sets `PERF_SEED_APPEND=1` and
calls `seed.sh` once per fraction. `SEED_COMMAND` must **append** tenants to
`PERF_TENANTS_FILE` (default `k6/artifacts/seed/tenants.json`). Each tenant
object MUST include numeric `volumeSize` of the data that VU will query. Do
not emit a fake `volume_size` ramp against one unchanged dataset.

```bash
SEED_COMMAND=<project seed> k6/scripts/run.sh journeys/foo.js
```

Do not call `run-volume-staircase.sh` from CI or playbooks.

Extend project manifests with domain fields, but preserve `schemaVersion`,
`id`, `kind`, `seed`, and `teardownRequired`. Bump the manifest `id` or
version whenever seeded shape changes so history comparisons cannot mix
datasets silently.

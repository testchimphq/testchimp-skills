# k6 dataset manifests

Commit manifests and synthetic examples, never credentials or production
payloads.

- `kind: "load"` describes a reusable synthetic identity pool. Concurrency is
  owned by the selected profile.
- `kind: "volume"` describes data cardinality/shape for a small number of
  tenants/VUs.

`k6/scripts/seed.sh <manifest.json>` validates the common fields and passes the
manifest to the project-specific seed integration. Extend project manifests
with domain fields, but preserve `schemaVersion`, `id`, `kind`, `seed`, and
`teardownRequired`. Bump the manifest `id` or version whenever seeded shape
changes so history comparisons cannot mix datasets silently.

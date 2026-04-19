# Test setup endpoints (seed, teardown, read)

Authoritative guide for **test-only** HTTP (or equivalent) surfaces used from Playwright harnesses, **fixtures** (`test.extend` setup/teardown), and assertions. These are **not** general product APIs: they are **controlled, guarded** entry points for QA automation.

For how fixtures call these endpoints, see **[`fixture-usage.md`](./fixture-usage.md)**.

---

## What to build

| Kind | Role |
|------|------|
| **Seed** | Create or transition data to a known posture (often idempotent). |
| **Teardown** | Remove or reset data safely between cases or after suites. |
| **Read** | Query or **probe** persisted and observable system state for assertions (and optionally to support **read-before-write** idempotency). |

---

## How to discover a strategy

Before inventing routes or table writes, **analyze the codebase**:

1. **ORM definitions and SQL schemas / migrations** — Map entities and **foreign key dependencies**. That ordering drives **creation sequences** (parents before children) and **teardown** (often reverse order).
2. **Frontend-facing or public CRUD APIs** — These usually implement the **real** create/update/delete workflows, including validation and **side effects** (derived rows, notifications, defaults).
3. **Application services and user flows** — Follow code paths that mirror production behavior when deciding what to call from tests.

**Frontend-facing APIs are a strong source** because they encode the workflows users actually hit; seed logic should use those workflows where possible.

**ORM/schema are a strong source** for **dependency order** and for understanding what must exist before a given entity can be created.

---

## Seed and teardown: prefer real implementation paths

Production handlers often create **derived data** that raw SQL or ad hoc inserts would skip. Example: an **`add_user`** flow may create profile rows, default settings, or enqueue jobs—logic that lives **only** in the service layer.

If a test-only seed endpoint **writes tables directly**, it can **miss** that derived data and will **drift** whenever the real implementation changes.

**Recommendation:** Where feasible, implement test-only endpoints that **delegate to** (proxy) the same services or HTTP APIs the product uses, wrapped in **test-only guards** (environment checks, feature flags, dedicated route prefixes like `/qa/` or `/internal/testdata/`).

Even when “direct” product endpoints exist, **still** expose **dedicated test routes** that call into them when appropriate: you get **non-production gating**, a single place to enforce env checks, and less risk of accidental misuse in production.

Use **DB/ORM analysis** and **reading existing flows** to determine **call order** when chaining multiple operations.

---

## Read endpoints

**Purpose:** After **UI** actions (e.g. create via the browser), assert **backend truth**—not only what the DOM shows. Reads are **entity- and state-oriented**: they return **persisted** or **observable** information the test needs to verify.

Reads are not limited to SQL: they may surface queue depth, job status, **Kafka** lag or message presence, **Firebase** or other external systems—whatever the scenario must observe.

**Test-only contract:** Same as seed/teardown—**guarded**, not for production clients. They may **proxy** existing internal or public read APIs if that keeps behavior aligned with production.

### Read endpoints and idempotency (read before write)

**Read** endpoints are also useful when implementing **idempotent** seed/teardown:

- **Read before write** — Before creating or mutating, call a read to see if the target state **already** exists (or matches a predicate). Skip or noop when appropriate so retries and parallel runs do not corrupt or duplicate data.

This keeps seed operations **safe to rerun** without relying solely on blind upserts.

---

## Relationship to fixtures

**Playwright fixtures** (see **[`fixture-usage.md`](./fixture-usage.md)**) are how tests **bring an environment to a known posture per test**. Fixture **`use` callbacks** typically invoke **seed** and **teardown** endpoints (or equivalent).

**Read** endpoints are primarily for **tests and fixtures** to **assert** state after actions; use them inside fixtures when you need to **verify** that a seed step completed. Use reads in specs or shared helpers when validating persistence after UI flows.

---

## Idempotency and safety

- **Seed** and **teardown** should be **idempotent** where possible: safe to retry, safe to run twice in a row.
- Use **read-before-write** (above), **natural keys**, **upsert** semantics, or **scoped reset** patterns as appropriate for your domain.
- Always enforce **non-production** guards on these routes.

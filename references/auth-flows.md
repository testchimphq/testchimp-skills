# Auth flows in SmartTests (sign-up, verify, OTP, MFA, reset)

Guide for agents authoring or running E2E that hit **sign-up**, **email verification**, **magic link**, **OTP / SMS**, **2FA / MFA**, or **password reset**. Goal: exercise the real UI without real inboxes, SMS numbers, or manual codes.

**Load this when:**

- **`/testchimp project init`** / **`connect-to-test-env`** discovers auth in the product, or
- **`/testchimp create tests`**, **`run QA`**, or **`write-smarttests`** scopes include an auth journey, or
- a headed run hits a verification / OTP / MFA step that would otherwise need a real code.

**Related:** [`connect-to-test-env.md`](./connect-to-test-env.md) (where the chosen approach is recorded), [`write-smarttests.md`](./write-smarttests.md), [`fixture-usage.md`](./fixture-usage.md), [`seeding-endpoints.md`](./seeding-endpoints.md).

**Out of scope:** Hosted inboxes, rented SMS numbers, Mailosaur / MailSlurp (or similar) as the default path. Do **not** buy numbers or inboxes.

---

## Default stance

Prefer **test-specific flags and provider / app test modes** chosen from the project's real auth stack. Automating production email or SMS delivery is flaky, costly, and often blocked. Follow **Plan → approve → Execute**: never add an auth bypass or change app auth code without explicit user approval in the plan.

---

## When to run detection

1. **During project init / connect-to-test-env** - once per project (or when auth infra changes). Record the result so later runs reuse it.
2. **Lazily** - when a scenario or live run touches sign-up, verify, magic link, OTP, SMS, MFA, or password reset and no recorded approach exists yet.

Ask the user **only** for what detection cannot resolve. Persist the answer (see [Where to record](#where-to-record)).

---

## Detection checklist

Inspect the **product** repo (and mapped SmartTests tree). In split-repo workspaces, search product roots too ([`split-repo-workspaces.md`](./split-repo-workspaces.md)).

### 1. Auth provider

Look for SDKs, env vars, and config that identify the stack, for example:

| Signal (examples) | Likely provider |
| --- | --- |
| `@clerk/`, `CLERK_` | Clerk |
| `auth0`, `@auth0/`, `AUTH0_` | Auth0 |
| `firebase/auth`, `FIREBASE_AUTH` | Firebase Auth |
| `@supabase/auth`, `SUPABASE_` + auth | Supabase Auth |
| `amazon-cognito`, `COGNITO_` | AWS Cognito |
| `next-auth`, `Auth.js`, `NEXTAUTH_` | NextAuth / Auth.js |
| `lucia`, `better-auth` | Lucia / Better Auth |
| Custom session cookies / JWT minting with no vendor SDK | Custom |

Do not invent a provider. If unclear, ask once with the candidates you found.

### 2. Existing test hooks

Before proposing new hooks, search for:

- Env flags such as `E2E`, `TEST_MODE`, `DISABLE_MFA`, `SKIP_EMAIL_VERIFY`, `AUTH_BYPASS` (names vary)
- Test-only routes or controllers (often gated by non-prod env)
- Seed / admin APIs that create **already verified** users (or MFA-enrolled users)
- Fixed test accounts documented in `.env-QA`, README, or policies
- Playwright **`storageState`**, **`setup/`** projects, or global setup that logs in once

### 3. What to ask the user

Only ask for gaps, for example:

- Which provider is canonical if detection is ambiguous
- Whether a provider **test mode** is already enabled in the target env
- Approval to add a **guarded** app-level bypass (if ladder step 2)
- Where CI secrets live for TOTP seeds / test passwords (names only; never paste values into chat)

---

## Decision ladder (prefer the first that applies)

| Step | Approach | When |
| --- | --- | --- |
| **1** | **Provider test mode** | Provider documents test emails, test phone numbers, or fixed codes for non-prod. Use those. |
| **2** | **App-level test flag / bypass** | Repo already has a guarded flag, **or** you propose a minimal one (non-prod only, env-gated) and get plan approval before coding. |
| **3** | **Seeded verified users** | Create users already verified (and MFA enrolled if needed) via seed / admin API; reuse login via Playwright `storageState` / setup project. |
| **4** | **TOTP 2FA from a secret** | Test user's TOTP seed lives in env / CI secrets; generate codes in-test with a standard library (e.g. `otplib` / `otpauth`). Never hardcode the seed. |
| **5** | **Last resort: manual / external** | Mark the scenario as needing a manual or external step and explain why. Do not buy inboxes or numbers. |

### Step 1 rules (provider test mode)

- **Verify current provider docs** before using any specific test email, phone, or code. Docs change; do **not** hardcode guessed values into the skill, plans, or committed tests.
- Prefer values supplied by the project's own env / secrets once confirmed against docs.
- Short provider notes (check docs; do not treat as frozen values):

| Provider | What to look up |
| --- | --- |
| Clerk | Test / development phone numbers and email testing guidance |
| Auth0 | Test connections, passwordless / MFA test configuration |
| Firebase Auth | Phone auth test numbers; email link / emulator options |
| Supabase Auth | Local / test OTP and email hooks |
| AWS Cognito | Test users; SMS sandbox / test message behavior |
| NextAuth / Auth.js | Credentials or test providers; how sessions are minted in non-prod |
| Lucia / Better Auth / custom | Project-specific test hooks; often step 2 or 3 |

### Step 2 rules (app flag / bypass)

- Prefer an **existing** flag over inventing one.
- If proposing a new flag: non-production only, behind an explicit env var, impossible to enable in production. Call that out in the plan and wait for approval.
- After adding seed or flag code, restart / reprovision per [`connect-to-test-env.md`](./connect-to-test-env.md) and [`seeding-endpoints.md`](./seeding-endpoints.md).

### Step 3 rules (seeded users + storage state)

- Seed or admin-create users in the required posture (verified email, enrolled MFA, etc.).
- Use Playwright **setup project** + **`storageState`** (or equivalent) so most tests start already authenticated.
- Keep at least one UI journey that still enters the real auth screens (see [Test design](#test-design)).

### Step 4 rules (TOTP)

- Read the seed from env / CI secrets only (e.g. `TEST_USER_TOTP_SECRET`).
- Generate the current code at runtime; never commit seeds or static codes.
- Mask codes in logs, traces, screenshots, and TestChimp reports (see [Security](#security)).

### Step 5 rules (last resort)

- Annotate the plan / scenario with why automation cannot close the loop.
- Prefer user takeover inside the **same** Playwright headed session for a one-off authoring capture ([`write-smarttests.md`](./write-smarttests.md) § User takeover), then convert to a durable step 1-4 approach afterward.

---

## Where to record

Persist so later agents reuse the choice without rediscovery:

1. **`plans/knowledge/policies/connect-to-test-env.policy.md`** - add or update an **`## Auth flows`** section (provider, ladder step chosen, env var names, setup/`storageState` paths, seed helpers). Call **`upsert-policy`**.
2. Workflow plan under **`plans/knowledge/workflow_plans/...`** for the run that decided it (detection evidence + approval).
3. Optional: short FAQ in an **existing** `ai-test-instructions.md` only if the team already maintains that file; do not create it solely for auth.

Do **not** commit secrets. Record **names** of env vars and secret store keys, not values.

Suggested policy skeleton (fill in project facts):

```md
## Auth flows

- Provider: <detected or confirmed>
- Ladder step: <1 provider test mode | 2 app flag | 3 seeded + storageState | 4 TOTP | 5 manual>
- Env / secret names: <e.g. TEST_USER_EMAIL, TEST_USER_TOTP_SECRET - names only>
- Setup / storageState: <path if used>
- Seed / bypass notes: <guarded flag name, seed helper, non-prod only>
- UI auth coverage: <which specs exercise full sign-up / OTP / MFA / reset>
```

---

## Test design

1. **One real UI path per auth flow** - Keep at least one scenario per flow (sign-up, verify, magic link, OTP, MFA, reset) that drives the real screens (enter code, submit, wrong / expired code) using the chosen test mechanism.
2. **Reuse auth for everything else** - Log in via `storageState` / setup (or a shared fixture) for non-auth scenarios so the suite stays fast and stable.
3. **Negative cases** - Where the mechanism allows: wrong code, expired code, resend limits, lockout.
4. **Traceability** - Annotate with scenario ids as usual (`annotation: { type: 'scenario', description: '#TS-…' }`). Apply suite tags from `global.policy.md`.
5. **Arrange** - Prefer fixtures + seed endpoints for verified users over clicking through sign-up in every test ([`fixture-usage.md`](./fixture-usage.md), [`seeding-endpoints.md`](./seeding-endpoints.md)).

---

## Security

| Rule | Detail |
| --- | --- |
| Secrets | TOTP seeds, test passwords, bypass tokens: env or CI secrets only. Never commit. |
| Masking | Codes and seeds must not appear in traces, screenshots, logs, or TestChimp reports. Prefer Playwright screenshot / trace redaction or avoid capturing the code field. |
| Production | Any bypass must be impossible to enable in production. State the guard in the plan before coding. |
| Chat | Never paste secret values into the conversation. |

---

## Plan → approve → Execute

When auth work needs app or harness changes:

1. **Plan** - Detection results, ladder step, proposed flag / seed / `storageState` / secret names, security guards, which scenarios get full UI vs reused state.
2. **Approve** - Explicit user approval (unless `--mode=non-interactive` or policy allows). Required before any bypass or auth-related product code change.
3. **Execute** - Implement approved items, restart / reprovision if needed, author/run SmartTests, update **`## Auth flows`** in the connect-to-test-env policy.

---

## Anti-patterns

- Guessing provider test codes or phone numbers without checking current docs
- Buying or renting inboxes / SMS numbers as the default
- Hardcoding TOTP seeds or OTPs in specs or plans
- Enabling MFA bypass in production builds
- Duplicating full sign-up / OTP in every test instead of `storageState` + one dedicated UI journey
- Skipping plan approval for a new auth bypass

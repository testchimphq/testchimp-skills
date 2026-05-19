# TrueCoverage

## What it is (all platforms)

TrueCoverage connects **real user behavior** (from production) with **test execution** so you can see which important journeys are under-tested. Instrument the **client app** with the platform RUM SDK; [`@testchimp/playwright`](https://github.com/testchimphq/playwright-testchimp-reporter) attaches **test identity** during SmartTest runs so emits from automation can be compared to real-user traffic in TestChimp.

| Surface | How test identity reaches the app |
|--------|-----------------------------------|
| **Web** | Reporter injects CI metadata into the page (e.g. `__TC_CI_TEST_INFO`) when fixtures use `installTestChimp` on the merged `test`. |
| **iOS / Android** | With **`installTestChimp(..., { uiFixture: 'screen' })`** on **`mobile/fixtures/index.js`** and Mobilewright UI projects setting **`use.platform`** (`ios` \| `android`), the plugin extends **`device`** so TrueCoverage **`SET`** runs **after** **`launchApp`** (via **`device.openUrl`** / `testchimp-rum://truecoverage/...`). **`afterEach`** flush as needed. The **app** must register URL scheme / intent filter and forward to **TestChimpRum** (see platform sections). |

**Runner timing vs in-app URL handling (native):** Improving **when** the runner sends **`SET`** (device fixture) does **not** replace **how** iOS/Android deliver automation URLs into your process. You still forward **`testchimp-rum://…`** into **`TestChimpRum`** from every entry point your UI stack actually receives (see iOS delegate + SwiftUI below).

**Critical implementation rule (do not misrepresent):** no additional “test-linking instrumentation” is required once SmartTests are wired correctly. If `fixtures/index.js` applies `installTestChimp()` from `@testchimp/playwright/runtime` to the merged `test` (the init scaffold default), runtime emit tracking is automatically augmented with test identity for coverage comparison. Do not plan extra linking hooks just to make emits count as test coverage.

As an intelligent QA workflow executor agent, TrueCoverage is a capability you can use to instrument the codebase to learn how real users interact with the app—sliced by dimensions you choose. Those events feed TestChimp for summarized insights, which you can read during **`/testchimp evolve`** to prioritize QA work.

### How to use TrueCoverage strategically

- **Fixture authoring:** Metadata slices that reference entity fields (see dot-notation metadata keys below) at an event help write fixtures that mimic real setups (for example: users without a form of payment attempting checkout—if you emit `user.has_fop` on checkout events, you can see how often that slice appears and prioritize fixtures and tests).
- **Covering common event sequences:** TrueCoverage APIs expose what events typically follow a given event (and frequency). Use that to find common journeys that are under-tested and author useful tests.
- **Funnels and gaps:** Per-event analytics follow the **4Ds** (RUM-based QA strategy—full mapping in [How TrueCoverage metrics work](https://docs.testchimp.io/truecoverage/how-it-works)): **Demand**, **Duration**, **Drop-off**, **Depth**. Together they prioritize which real-user paths deserve tests beyond raw transition lists.

### Authoritative SDKs (read before implementing)

| Platform | Package | Docs |
|----------|---------|------|
| **Web** | `@testchimp/rum-js` (npm) | [GitHub](https://github.com/testchimphq/testchimp-rum-js), [npm](https://www.npmjs.com/package/@testchimp/rum-js) |
| **iOS** | `TestChimpRum` (Swift Package) | [testchimp-rum-ios](https://github.com/testchimphq/testchimp-rum-ios) |
| **Android** | **JitPack** (primary for public installs), local module, optional Maven Central | [testchimp-rum-android](https://github.com/testchimphq/testchimp-rum-android) — **§ Android** |
| **SmartTests runner** | `@testchimp/playwright` | [playwright-testchimp-reporter](https://github.com/testchimphq/playwright-testchimp-reporter) — `installTestChimp`; mobile UI: **`use.platform`** in config ([`project-types-and-scaffolds.md`](./project-types-and-scaffolds.md)) |

**Product overview:** [TrueCoverage intro](https://docs.testchimp.io/truecoverage/intro)

---

## RUM environment tag (TrueCoverage analytics alignment)

**Contract:** **`@testchimp/rum-js`**, **testchimp-rum-ios**, and **testchimp-rum-android** all take an **`environment`** string in **`init` / `initialize`**. That value is the **logical tag on RUM sessions** and payloads. **They do not automatically read** shell **`TESTCHIMP_ENV`**, **`NODE_ENV`**, or other **process** environment variables—the **app integration must supply** `environment` explicitly (build-time bundle, plist/xcconfig, `BuildConfig` / product flavor, or a small bootstrap helper that reads **one** canonical source your team owns).

**Why it matters:** TrueCoverage **`ExecutionScope`** fields, **`list-rum-environments`**, and related MCP tools **filter on this tag**. Instrumenting with **project id + API key + deep link / reporter** alone is **not** sufficient for analytics alignment if **`environment`** is wrong, missing, or inconsistent—**base** vs **comparison** scopes will not line up with how the team thinks about deploys.

**Map team naming into the SDK:** Reuse the same vocabulary as SmartTests / backends where it makes sense—for example the logical name behind **`TESTCHIMP_ENV`** and **`.env-${TESTCHIMP_ENV}`** (e.g. `QA`, `staging`, `production`)—and pass **that** into **`environment`**, unless the product uses a different RUM taxonomy (then document it).

**Parity (test harness vs app):** If SmartTests default **`TESTCHIMP_ENV=QA`** (or similar), **recommend** the **native (or web) app** RUM tag for **local / simulator / CI** builds **match** that tag **unless** the team **deliberately** separates “automation / test RUM” from “real user RUM” environments. **Tradeoff:** if tags **diverge**, TrueCoverage **comparison** scopes must use the **same** `environment` values as the traffic being compared; arbitrary splits (e.g. app hard-coded `#if DEBUG` → `development` while MCP scopes use `QA`) **break** overlay analysis until scopes and tags are reconciled.

**Runtime overrides (optional):** Teams may support **staging** (or per-branch) tags **without** a full rebuild—e.g. **iOS:** Xcode scheme **Environment Variables**, **`ProcessInfo.processInfo.environment`**, or build-setting injection before **`initialize`**; **Android:** `BuildConfig` from flavor + `resValue` / manifest placeholders, or debug-only reads of **`System.getenv`** if policy allows—**only** if the project standardizes one pattern and documents it.

**Checklist (agents + implementers — do not skip on native):**

- [ ] **`environment`** is set on **every** code path that calls **`initialize`** / **`init`** (not assumed from process env).
- [ ] The tag **matches** the team’s **deploy / staging / prod** naming and what they will pass to **`list-rum-environments`** / **`baseExecutionScope`** / **`comparisonExecutionScope`**.
- [ ] **Parity** with SmartTests **`.env-*` / `TESTCHIMP_ENV`** is **explicit** (aligned **or** deliberately split, with scope implications written down).
- [ ] Recorded under **`### TrueCoverage Plan`** or **`## Environment Provision Strategy`** / notes in **`plans/knowledge/ai-test-instructions.md`** (and the app **README** for self-serve teams).

**Avoid:** Describing mobile TrueCoverage as only “install SDK + credentials + URL scheme / intent filter” **without** calling out **`environment`** mapping—**`#if DEBUG` defaults** alone often **won’t** match production TrueCoverage filters.

---

## Resolving `projectId` and `apiKey` (all platforms)

Before wiring RUM `init` / `initialize`, resolve credentials in this order:

1. **App/build config already set** — use existing env vars, plist keys, `BuildConfig`, or bootstrap helpers (preferred when the team already centralizes secrets there).
2. **Project MCP config (agent default when #1 is missing)** — From the SmartTests root (`.testchimp-tests`), walk **up** to the repo’s **project-level** MCP JSON (Cursor: **`.cursor/mcp.json`**; Claude Code: **`.mcp.json`**; same walk-up as **`SKILL.md`** Preamble **#4**). Read **`mcpServers.testchimp.env`**:
   - **`TESTCHIMP_PROJECT_ID`** → map to RUM **`projectId`**
   - **`TESTCHIMP_API_KEY`** → map to RUM **`apiKey`**
   - Skip values that are empty or match placeholders (`PASTE_YOUR_…`, `placeholder`, etc.). **Never print** secrets in chat.
3. **User prompt** — if both are still missing, ask the user to paste **project ID** and **API key** from **TestChimp → Project Settings → Key management** into the project MCP `env` block (see [`../assets/sample-mcp.json`](../assets/sample-mcp.json)) and/or the app’s build config, then reload MCP if needed.

During **`/testchimp init`**, the **[Workstation gate](init-testchimp.md#workstation-gate-always-first)** should already have created or merged that MCP file with placeholders; instrumentation runs should **consume** those values rather than inventing IDs.

---

## Web (browser) instrumentation

1. **Install:** `npm install @testchimp/rum-js` in the **app under test** (frontend / runtime bundle), not only in the SmartTests package.
2. **Init once** at app bootstrap: call **`testchimp.init()`** (see [library README](https://github.com/testchimphq/testchimp-rum-js)). Required top-level fields per README:
   - **`projectId`** — TestChimp project ID. Resolve per **[Resolving `projectId` and `apiKey`](#resolving-projectid-and-apikey-all-platforms)** (MCP **`TESTCHIMP_PROJECT_ID`** when app config does not already define it).
   - **`apiKey`** — project API key for RUM (same resolution order; MCP **`TESTCHIMP_API_KEY`** or app env).
   - **`environment`** — logical tag for the session (e.g. `production`, `staging`, `QA`); use one consistent scheme per deploy. **Not auto-filled** from **`TESTCHIMP_ENV`** on the shell: map build-time / runtime config into this parameter (see **[RUM environment tag](#rum-environment-tag-truecoverage-analytics-alignment)**).
   - Optional: `sessionId`, `release`, `branchName`, `sessionMetadata`, and nested **`config`** (see below).
3. Prefer **one helper** (e.g. `emitProductEvent`) that wraps **`testchimp.emit()`** after init. Read credentials from app build config when present; otherwise from project MCP `env` per the resolution section above. Avoid scattering raw `emit` calls. Do **not** put these secrets in SmartTests `.env-QA`—those are for test execution vars like `BASE_URL`.
4. **Vocabulary:** If you already use product analytics (PostHog, Segment, etc.), align event names where it helps—but TrueCoverage goals differ: prefer **semantic journey steps** (e.g. checkout-completed) over noise (“button clicked”). Keep **metadata cardinality** low; follow **Event constraints** in the [GitHub README](https://github.com/testchimphq/testchimp-rum-js) (title length, metadata keys/values, max serialized size).

### RUM `config` (volume / “sampling” behavior) — web

The library does not use a separate “sampling percentage” API; **event volume and repeat caps** are controlled via the optional **`config`** object passed to **`testchimp.init({ ..., config })`**. Defaults and meanings are defined in the [@testchimp/rum-js README — Configuration options](https://github.com/testchimphq/testchimp-rum-js). Use this table as the agent checklist (align with README for exact defaults):

| Option | Purpose |
|--------|--------|
| `captureEnabled` | If `false`, `emit` is a no-op (kill switch). |
| `maxEventsPerSession` | Cap total accepted events per session. |
| `maxRepeatsPerEvent` | Cap repeats of the same event **title** per session. |
| `eventSendInterval` | Ms between batch sends. |
| `maxBufferSize` | Buffer size before auto-flush. |
| `inactivityTimeoutMillis` | Session expiry; new load starts a new session. |
| `testchimpEndpoint` | RUM ingress base URL (override only if needed). |
| `enableDefaultSessionMetadata` | Session init metadata from client (`navigator` / `Intl`); set `false` if you want only your `sessionMetadata`. |

For a **first instrumentation slice**, prefer **conservative** limits (the README includes an example “high-frequency sampling” block). Reuse existing tuning from the repo when present.

Sampling can be done with custom logic on the app side: for the session, decide whether capturing should run, then set `captureEnabled`. Example:

```js
// Decide once per browser session (before or inside init).
SAMPLE_RATE := 0.01
roll := random_uniform_0_to_1()  // cryptographically weak RNG is fine here

captureEnabled := (roll < SAMPLE_RATE)

testchimp.init({
  projectId: "...",
  apiKey: "...",
  environment: "production",
  config: {
    captureEnabled: captureEnabled,
    // ...maxEventsPerSession, maxRepeatsPerEvent, etc.
  },
})
// When captureEnabled is false, emit() is a no-op for that session.
```

For **deterministic** cohorts (same user always in or out), hash a stable **non-PII** key (e.g. anonymous id or session id) to a bucket in `[0, 1)` and compare to `SAMPLE_RATE` instead of `random_uniform_0_to_1()`.

### After init (web)

- Use **`testchimp.emit({ title, metadata? })`** for journey events; call **`testchimp.flush()`** before navigation/redirect if you need immediate delivery.
- Invalid or over-limit events are **dropped** (console warning per README)—design titles and metadata accordingly.

---

## iOS (native) instrumentation

### Installing the Swift package (public repo — default)

For a **public** [testchimp-rum-ios](https://github.com/testchimphq/testchimp-rum-ios) repo, consumers do **not** need a GitHub token for normal SPM resolution: Xcode and SwiftPM fetch over **HTTPS** from the public Git URL.

1. **Pick a released version:** The upstream repo should publish **SemVer git tags** (e.g. `0.1.0`). Pin the app to **`from:` / “Up to Next Major”** on that tag (or an exact **`exact("0.1.0")`** if the team wants a lockstep pin). **Do not** depend on an un-tagged default branch in production apps unless the team explicitly accepts churn.
2. **Xcode:** **File → Add Package Dependencies…** → enter **`https://github.com/testchimphq/testchimp-rum-ios.git`** (or the org’s fork URL) → add product **`TestChimpRum`** to the app target.
3. **`Package.swift` (app or workspace package):**

   ```swift
   .package(url: "https://github.com/testchimphq/testchimp-rum-ios.git", from: "0.1.0")
   ```

   Adjust the URL and lower bound to match the tag you support.

**When a token *is* needed:** Only for **private** forks, **private** transitive deps, or unusual corporate proxies. Then the developer configures Xcode / git credential manager or a **read-only** PAT locally—**not** in chat, **not** in `plans/*.md`. The agent may ask: “Is the dependency public on GitHub?” and “Which **tag** should we pin?”—not “paste your PAT.”

**Publishing (maintainers):** SPM “release” = **push a SemVer tag** to the library repo (helper: **`./scripts/release-spm-tag.sh`** in that repo); consumers point the URL at that repo. No separate registry login (unlike npm). Optional: GitHub **Release** notes for humans; the tag is what SwiftPM uses.

### Instrumentation steps

1. **Add the library** (as above).
2. **Resolve credentials** per **[Resolving `projectId` and `apiKey`](#resolving-projectid-and-apikey-all-platforms)** — wire **`projectId`** / **`apiKey`** from xcconfig, Info.plist, or build settings (often populated from project MCP **`TESTCHIMP_PROJECT_ID`** / **`TESTCHIMP_API_KEY`** when not already in the app).
3. **Initialize once** (early app lifecycle), then emit from UI code:

   ```swift
   import TestChimpRum

   TestChimpRum.initialize(TestChimpRumConfig(
       projectId: "YOUR_PROJECT_ID",
       apiKey: "YOUR_API_KEY",
       environment: "staging"
   ))
   TestChimpRum.emit(TestChimpEmitInput(title: "button_tap", metadata: ["screen": "Home"]))
   ```

   Use `config:` / inner options for the same knobs as JS (`captureEnabled`, `maxEventsPerSession`, `eventSendIntervalMillis`, `testchimpEndpoint`, etc.)—see the package README.

   **`environment`:** Must follow **[RUM environment tag](#rum-environment-tag-truecoverage-analytics-alignment)**—do not ship with a placeholder (e.g. hard-coded `"staging"`) that does not match **`list-rum-environments`** or SmartTests **`TESTCHIMP_ENV` / `.env-*`** without an explicit team decision. Prefer **Info.plist / xcconfig / build setting → bootstrap**; optional **scheme env vars** or **`ProcessInfo`** for CI/local overrides without rebuilding if the project supports it.

4. **TrueCoverage + Mobilewright:** In **`mobile/fixtures/index.js`**, apply **`installTestChimp(mergeTests(...), { uiFixture: 'screen' })`**. Set **`use.platform: 'ios'`** on the iOS project in **`mobilewright.config.ts`**. Specs import that wrapped `test` (not raw `@mobilewright/test`) — see [playwright-testchimp-reporter README](https://github.com/testchimphq/playwright-testchimp-reporter).
5. **Register URL scheme** **`testchimp-rum`** for the app (Xcode **Info → URL Types** / `CFBundleURLTypes`), then forward incoming URLs to **`TestChimpRum.handleAutomationURL(_:)`** from **every path your app receives URL opens on** — commonly **both**:
   - **`UIApplicationDelegate`** — `application(_:open:options:)`
   - **SwiftUI** — `.onOpenURL { … }`  
   Using **both** is a **reliability** pattern (some stacks drop opens in one path when the app is already foreground); the device-fixture runner change does **not** remove this requirement unless you have verified a single path handles **all** automation opens for your shell.

   Example (illustrative — adapt names to your app):

   ```swift
   // AppDelegate
   func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
       TestChimpRum.handleAutomationURL(url)
   }

   // SwiftUI
   .onOpenURL { TestChimpRum.handleAutomationURL($0) }
   ```
5. **Default automation URLs** (overridable on the runner with **`TESTCHIMP_RUM_AUTOMATION_SET_PREFIX`** and **`TESTCHIMP_RUM_AUTOMATION_CLEAR_URL`** — see `@testchimp/playwright` README):
   - Set: `testchimp-rum://truecoverage/v1/set?p=<base64url(JSON)>`
   - Clear: `testchimp-rum://truecoverage/v1/clear`

Full detail: [testchimp-rum-ios README](https://github.com/testchimphq/testchimp-rum-ios).

---

## Android (native) instrumentation

### Installing the library — JitPack (canonical for public [testchimp-rum-android](https://github.com/testchimphq/testchimp-rum-android))

[JitPack](https://jitpack.io/) builds the repo on each **git tag** (or branch snapshot, e.g. `master-SNAPSHOT`) and serves Maven artifacts. Consumers add **`maven("https://jitpack.io")`** — **no** GitHub token for dependency resolution.

**Coordinates** match what [JitPack shows for this repo](https://jitpack.io/#testchimphq/testchimp-rum-android): **`com.github.testchimphq:testchimp-rum-android:<Tag>`** — use your **git tag** as `<Tag>` (e.g. `0.1.0`), or the version string JitPack lists for snapshots.

```kotlin
// settings.gradle.kts — dependencyResolutionManagement { repositories { … } }
maven(url = "https://jitpack.io")
```

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.github.testchimphq:testchimp-rum-android:0.1.0")
}
```

Always confirm the **exact** Gradle line on [jitpack.io/#testchimphq/testchimp-rum-android](https://jitpack.io/#testchimphq/testchimp-rum-android) after your tag builds (green log)—prefer **their** copy-paste if it differs.

**Agent / init workflow — what to ask the user**

1. **Version:** Which **git tag** to pin (must exist on GitHub and have a **green** JitPack build). Do **not** ask for GitHub PATs for JitPack installs.
2. **Fallbacks:** **Local Gradle module** (monorepo) if JitPack is blocked; **Maven Central** only when `io.testchimp:rum-android` is actually published there.

**Publishing (maintainers):** Bump **`libraryVersion`** in **`testchimp-rum/build.gradle.kts`**, commit, push, then run **`./scripts/release-jitpack.sh`** (or push the same SemVer as a git tag manually). Repo includes **`jitpack.yml`** (JDK 17 + publish tasks) and a **Gradle wrapper** for reproducible JitPack builds.

**Optional — GitHub Packages / PATs:** Only if the team chooses that path instead of JitPack: tokens stay in **CI secrets** and **local `gradle.properties`** (gitignored), never in chat or `plans/`. Prefer JitPack for public repos to avoid PAT rotation for consumers.

Full detail: [testchimp-rum-android README](https://github.com/testchimphq/testchimp-rum-android).

### Instrumentation steps

1. **Add the library** (as above).
2. **Resolve credentials** per **[Resolving `projectId` and `apiKey`](#resolving-projectid-and-apikey-all-platforms)** — e.g. `BuildConfig.TC_PROJECT_ID` / `TC_API_KEY` from `gradle.properties`, flavor config, or values copied from project MCP **`TESTCHIMP_PROJECT_ID`** / **`TESTCHIMP_API_KEY`** when not already defined.
3. **Initialize once** in `Application.onCreate`, then emit from UI code:

   ```kotlin
   TestChimpRum.initialize(
       this,
       TestChimpRumConfig(
           projectId = BuildConfig.TC_PROJECT_ID,
           apiKey = BuildConfig.TC_API_KEY,
           // Example only: map a dedicated RUM tag (e.g. BuildConfig.TC_RUM_ENV / flavor)—
           // not raw BUILD_TYPE unless your team uses "debug"/"release" as TrueCoverage filters.
           environment = BuildConfig.TC_RUM_ENV,
       ),
   )
   TestChimpRum.emit(TestChimpEmitInput(title = "button_tap", metadata = mapOf("screen" to "Home")))
   ```

   Use **`TestChimpRumConfig.Options`** for the same tuning knobs as JS (`captureEnabled`, `maxEventsPerSession`, etc.).

   **`environment`:** Must follow **[RUM environment tag](#rum-environment-tag-truecoverage-analytics-alignment)**. **`BuildConfig.BUILD_TYPE`** alone is usually **`debug` / `release`** and **does not** match typical **`QA` / `staging` / `production`** tags—define **`BuildConfig`** fields, **product flavors**, or **manifest placeholders** so the RUM tag matches team + MCP scope naming; use **runtime overrides** only if standardized (e.g. debug `System.getenv` behind a flag).
4. **TrueCoverage + Mobilewright:** Same as iOS — **`mobile/fixtures/index.js`** with **`{ uiFixture: 'screen' }`**, **`use.platform: 'android'`** on the Android config project — see [playwright-testchimp-reporter README](https://github.com/testchimphq/playwright-testchimp-reporter).
5. **Deep link:** Add an **`intent-filter`** on the activity that should receive automation (often the launcher activity) for **`VIEW`** + scheme **`testchimp-rum`**, host **`truecoverage`**, path prefix **`/v1`** (matches `…/v1/set`, `…/v1/clear`, `…/v1/flush`).
6. **Deliver to the SDK:** On each relevant lifecycle hook (**`onCreate`**, **`onNewIntent`**, and if needed **`onResume`** so repeated VIEW deliveries are not missed), obtain a **`Uri`** and call **`TestChimpRum.handleAutomationUri(uri)`**.

   **`Intent` vs `Uri`:** `TestChimpRum.handleAutomationIntent(intent)` delegates to **`intent?.data`**. Some **`VIEW`** deliveries leave **`getData()`** null while **`intent.dataString`** is still set—normalize first:

   ```kotlin
   val uri = intent.data ?: intent.dataString?.takeIf { it.isNotBlank() }?.let(Uri::parse)
   if (uri != null) TestChimpRum.handleAutomationUri(uri)
   ```

Full detail: [testchimp-rum-android README](https://github.com/testchimphq/testchimp-rum-android).

### SmartTests checklist (native)

- [ ] Mobilewright UI projects set **`use.platform`** (`ios` / `android`); specs use **`mobile/fixtures/index.js`** with **`installTestChimp(..., { uiFixture: 'screen' })`**.
- [ ] **`TESTCHIMP_API_KEY`** in the **runner** process (see **`SKILL.md`** — Preamble checks **#4**); MCP IDE env alone is not enough.
- [ ] **`export const test = installTestChimp(mergedTest)`** from **`fixtures/index.js`**; spec files import **`test`** from that barrel — **do not** import raw **`test`** from **`@mobilewright/test`** in specs (setup-only projects may differ).
- [ ] **`mobilewright.config.ts`**: **`platform`**, **`bundleId`**, **`installApps`** / APK path as required.

---

## Project decision: `plans/knowledge/ai-test-instructions.md`

TrueCoverage decisions are project-level and must be persisted in `plans/knowledge/ai-test-instructions.md` under `### TrueCoverage Plan` (not in workstation marker files).

### Default: opted in

**Unless** `ai-test-instructions.md` **explicitly** states that TrueCoverage is **opted out** (e.g. a clear `### TrueCoverage Plan` entry such as “opted out,” “disabled for this repo,” “not applicable,” or equivalent team decision the file names as permanent opt-out), agents MUST treat TrueCoverage as **opted in**:

- Plan **platform RUM install** (see **Web / iOS / Android** sections above), **init** / emit helper, **documented RUM `environment` tag mapping** (see **[RUM environment tag](#rum-environment-tag-truecoverage-analytics-alignment)**), **`@testchimp/playwright`** reporter + correct fixture barrels / **`use.platform`**, and **`plans/events/*.event.md`** for new or changed journeys as part of normal **`/testchimp init`**, **`/testchimp test`**, and **`/testchimp evolve`** work.
- Do **not** skip TrueCoverage because the TrueCoverage section is missing, empty, or says only “deferred,” and do **not** treat silence as “user declined.”

**Explicit opt-out only:** When the file **explicitly** records opt-out, skip new TrueCoverage instrumentation unless the user runs **`/testchimp setup truecoverage`** or otherwise asks to re-enable.

**Deferred during init:** “Deferred” is a **schedule snooze** (which emits land later), **not** an opt-out.

- During **`/testchimp test`**, treat TrueCoverage as **in-scope** for the PR: wire missing framework pieces, define/document the **event slice** for changed journeys, and update `plans/knowledge/truecoverage-instrument-progress.md` as appropriate.
- During **`/testchimp init`**, “deferred” means not finishing every planned emit in that init pass; the agent must not later assume TrueCoverage is unavailable or out of scope.

---

## Ongoing: `/testchimp test`

When there is **no explicit opt-out** in `ai-test-instructions.md` and the PR adds or changes **meaningful user journeys**:

1. **Plan:** Include TrueCoverage work: new or updated events, helper placement, env config, `plans/events/` docs, progress tracker updates.
2. **Execute:** Emit events from the app code where it adds signal; use **`plans/events/`** (below) to document event types and metadata for consistency.

If **`### TrueCoverage Plan`** explicitly records **opted out**, skip new instrumentation unless the user explicitly asks (e.g. `/testchimp setup truecoverage`).

---

## Instrumentation progress tracker: `plans/knowledge/truecoverage-instrument-progress.md`

To make TrueCoverage instrumentation incremental and resumable, maintain a single progress tracker under:

- `plans/knowledge/truecoverage-instrument-progress.md`

Purpose:

- Track **planned vs done** event instrumentation with a route/page-based breakdown (web) or **screen / flow** breakdown (mobile—adapt the grouping to how the product is structured).
- Let agents resume instrumentation consistently during `/testchimp instrument` and opportunistically during `/testchimp evolve`.

Init policy:

- `/testchimp init` should wire **basic TrueCoverage infra** and a **small initial event slice**.
- `/testchimp init` should also scan the app’s primary navigation surfaces (routes/pages on web; main screens/flows on mobile) and write the progress tracker for the **full planned event list**.
- Init should create `plans/events/*.event.md` files **only** for events actually instrumented in init; planned-but-not-yet-instrumented events remain tracked only in the progress doc until `/testchimp instrument` lands them.

Suggested format:

- Sections grouped by **routes/pages** (web) or **screens/flows** (mobile).
- Each event entry is marked `done | planned | deferred`.
- When an event is marked `done`, it should have a matching `plans/events/<title>.event.md` file.

How `/testchimp instrument` uses it:

1. Choose the next relevant `planned` events (often those impacted by the current PR).
2. Implement emits in app code via the shared helper wrapper.
3. Create/update `plans/events/<title>.event.md` for each newly-instrumented event.
4. Update `plans/knowledge/truecoverage-instrument-progress.md` by marking those entries `done`.

How `/testchimp evolve` uses it:

- Treat `plans/knowledge/truecoverage-instrument-progress.md` as the plan baseline.
- If MCP analytics show high-signal gaps that are already `planned`, prioritize instrumenting them.
- If analytics suggests missing events that are not in the tracker, add them as `planned` (or explain why they are out of scope).
- Full evolve workflow (Analyze → Plan → Execute), phase gates, and where to persist evolve plans: [`evolve-coverage.md`](./evolve-coverage.md).

## Ongoing: `/testchimp evolve`

When the project has **not** explicitly opted out of TrueCoverage in `ai-test-instructions.md`, after requirement coverage and execution history, use MCP tools (see **SKILL.md**). Requests mirror the platform TrueCoverage API (JSON bodies use **camelCase** field names). If explicitly opted out, omit TrueCoverage MCP analytics unless the user asks to re-evaluate.

### Execution scopes (mental model)

Analytics messages embed **`ExecutionScope`**: environment, time window, optional release/branch/metadata filters, optional **`platform`**, and optionally **`automationEmitsOnly`**.

| Scope field | Typical use |
|-------------|-------------|
| **`baseExecutionScope`** | **Real-user / production** (or the environment that best reflects real behavior). Drives funnel stats: relative frequency, funnel position, histograms, terminal %, session counts. |
| **`comparisonExecutionScope`** | **Secondary** window (often **QA / staging**) used to answer “did **automated tests** cover this event?” Coverage badges compare base vs this scope. |
| **`coverage_scope`** (child event tree) | Same idea as comparison: “which **next** events were seen under coverage” when drilling into transitions. |
| **`platform`** | **`WEB_EXECUTION_PLATFORM`**, **`IOS_EXECUTION_PLATFORM`**, or **`ANDROID_EXECUTION_PLATFORM`** — limits analytics to RUM rows stamped at ingest. Web/iOS/Android SDKs send **`testchimp-rum-platform: 1|2|3`** on **`/rum/session/start`** and **`/rum/events`**. Use on base and comparison scopes in multi-platform repos so web prod traffic is not mixed with native mobile. |

Set **`automationEmitsOnly: true`** on **`comparisonExecutionScope`** or **`coverage_scope`** when you want coverage to count **only RUM emits that carry test identity** (`test_id` from the Playwright reporter, including native mobile when CI automation URLs are wired). That **excludes manual sessions** on the same environment so “covered” is not polluted by ad-hoc QA. Omit the field or set **`false`** to include all traffic in that scope (legacy behavior). **Do not rely on `automationEmitsOnly` on the base scope** for filtering real-user metrics—the platform ignores it for base aggregates; use it only on comparison/coverage scopes.

### Recommended flow

1. **`list-rum-environments`** — Lists environment tags present in data; pick env values for scopes.
2. **`get-truecoverage-events`** — Body: `baseExecutionScope`, optional `comparisonExecutionScope` (add `automationEmitsOnly` on comparison when you want test-only coverage; set **`platform`** on each scope for web vs iOS vs Android — see [`cli.md`](./cli.md) § `ExecutionScope`). **Returns** `eventSummaries[]` with `eventTitle`, `relativeFrequency`, `coverageStatus` (PRESENT/ABSENT vs comparison), position/histogram summaries, `numUniqueSessions`, terminal %.
3. Choose high-impact gaps, then for the identified events that you want to drill in to:
   - **`get-truecoverage-event-details`** — Time series, sample sessions, **metadata** breakdown with per-value **comparison coverage** (use `automationEmitsOnly` on `comparisonExecutionScope` to align metadata “covered” with test-tagged emits only).
   - **`get-truecoverage-child-event-tree`** — Top **next** events after the current title; pass **`coverage_scope`** with `automationEmitsOnly` when transition coverage should ignore manual paths.
   - **`get-truecoverage-event-transition`** / **`get-truecoverage-event-time-series`** — Deeper transition and metric series as needed.
4. Turn gaps into a prioritized plan (tests and scenario coverage first; instrumentation only when truly missing in product code).

### Interpreting "not covered" events (strict)

When TrueCoverage marks an event (or metadata slice) as under-covered, the default interpretation is:

- Production sees that emit path, but automated tests are not traversing that path (or not traversing the same slice).
- The primary fix is **not** to add synthetic emits or shallow "just hit event once" tests.
- The fix is to identify the relevant **business scenarios** where the event occurs, ensure those scenarios exist in plan artifacts, and author/extend SmartTests or API tests that execute those scenarios end-to-end with meaningful assertions.

Required remediation order:

1. Map uncovered event/slice to business behavior and user scenario(s).
2. If scenario/story artifacts are missing, add them to the plan and create them **after user approval** per workflow guardrails.
3. Author or update tests for those scenarios; add `// @Scenario:` links with real IDs.
4. Validate that tests now traverse the previously uncovered event path/slice.

Do not resolve gaps by writing minimal "emit tick" tests that are detached from business use cases.

### Metadata keys and “coverage”

Use metadata for gap analysis **only when the key is a meaningful product dimension** (e.g. role, plan tier, payment readiness) where behavior or risk differs.

For priority setting, treat metadata slices as first-class coverage targets: when a high-impact event is "covered" overall but important slices are not (for example a specific role/tier/state), plan tests for those slices using business-relevant scenarios and fixture posture aligned to those slice values.

Hard rule: **do not emit identifiers** as metadata keys or values (or plan for them in `plans/events/*.event.md`). In practice this means avoiding keys like `project_id`, `org_id`, `user_id`, any `*_id`, UUIDs, raw emails, or other high-cardinality identifiers. These explode cardinality and are not useful for sliced coverage.

Also avoid **free-text** or other high-cardinality dimensions unless the product logic genuinely branches on a small bounded set of values—the platform can mark keys as high-cardinality; prefer skipping those for coverage prioritization.

When in doubt, refer documentation: https://docs.testchimp.io/truecoverage/how-it-works

### Dot-scoped metadata (entity attributes)

**Mental model:** **`testchimp.emit()`** (browser) or the native **`TestChimpRum.emit`** equivalent is how you **learn how real users move through the product** at the level of *journeys + slicing dimensions*, not raw logs. Before instrumenting, ask: *What slices matter for risk, for prioritizing tests, and for building fixtures that resemble production?* (examples: role, org tier, cart state, entitlements.)

**Convention (domain entities only):** When metadata describes a **domain entity** (eg: user, org, cart, subscription, …), prefer keys shaped **`{entity}.{attribute}`** with a **stable, low-cardinality** first segment:

- `user.role`, `user.has_fop` (boolean or enum—not raw payment instrument ids)
- `org.plan_tier`
- `cart.line_item_count_bucket` or `cart.is_empty` (buckets/enums, not SKUs)
- `product.availability_class` (small enum: `in_stock` / `backorder` / …)

Use **flat** keys for cross-cutting dimensions that are not “owned” by one entity (e.g. `entry_surface`, `experiment_cohort`) if that reads clearer—dot notation is a **scoping aid**, not a strict schema.

**Per-event minimalism:** Attach only fields that **change how you interpret that event** for coverage and QA. Do **not** dump whole domain objects onto every emit. The goal is to answer: *which kinds of entities perform which actions, how often, and are those slices exercised in automated tests?*—without cardinality explosion.

**Feedback loop (fixtures and tests):** Production-like traffic → distributions and transitions in TrueCoverage (e.g. `get-truecoverage-event-details`, `get-truecoverage-event-metadata-keys`, child event trees, time series) → **gaps** (common real slices with weak or missing test coverage) → **seed/probe endpoints** and **Playwright fixtures** (`mergeTests`, `<tests_root>/fixtures/`) that recreate those world-states → **SmartTests / API tests** → requirement scenarios where the product is under-specified. Dot-scoped keys make it obvious *which fixture dimensions* to extend (e.g. a `viewer` role fixture when `user.role=viewer` dominates a critical event).

Dot notation **does not** relax the rules above: it is **namespacing** for allowed, low-cardinality dimensions—not permission to add PII, ids, or unbounded text.

---

## Commands

TrueCoverage setup and ongoing instrumentation is part of `init` and `test` workflows. Below is for when just TrueCoverage specific tasks are needed to be done.

| User intent | Action |
|-------------|--------|
| `/testchimp setup truecoverage` (or setup-truecoverage) | Walk through RUM install for the app’s platform, env vars, helper, reporter; persist the decision and notes under `### TrueCoverage Plan` in `plans/knowledge/ai-test-instructions.md`. |
| `/testchimp instrument` | Instrument current PR work with emits; run setup first if TrueCoverage is not yet enabled and the user wants it. |

---

## Event documentation: `plans/events/`

Events do **not** require server-side registration. To avoid duplicate names and document metadata for agents, add one **`*.event.md` file per event type** under **`plans/events/`** (under the mapped plans root). The platform treats these as **`EVENT_FILE`** (distinct from **`plans/knowledge/`** markdown).

**Dual purpose:** Each file is both (1) a **schema note** for metadata and (2) **durable planning memory**. On later runs—especially **`/testchimp evolve`** and when calling TrueCoverage MCP tools to interpret funnels, coverage gaps, and metadata slices—the agent should **re-open the matching `*.event.md`** so instrumented titles are not “mystery emits.” Write the body so a **future agent** (often you, in a new session) can recover **why** the event exists, **what** you hoped to learn from analytics, and **how** that ties to product risk and requirements.

**Frontmatter:**

| Field | Description |
|-------|-------------|
| `title` | kebab-case; match the event file basename (without `.event.md`). |
| `description` | Short factual line: when the event fires (user-visible moment or journey step). |
| `added-on` | Date instrumentation was added (ISO date). |
| `significance` | 1–5 for gap prioritization during evolve runs (1=low, 5=high). |

**Body — required sections (in this order):**

1. **`## Rationale`** (required; this name is preferred so tools and humans can grep it—acceptable synonyms: **`## Instrumentation rationale`**, **`## Why this event`**)

   Write for **your future self** when interpreting TrueCoverage stats and planning next steps. Include plain-language coverage of:

   - **Thinking / intent** — Why instrument *here* (not elsewhere), what product or UX question this emit is meant to illuminate, and any tradeoffs (e.g. kept title coarse to limit cardinality).
   - **Hypotheses / questions** — What you expect or want TrueCoverage data to answer (e.g. “Do users with `user.has_fop=false` abandon after this step disproportionately?”).
   - **Business criticality** — Why this journey slice matters (revenue, compliance, trust, activation, etc.).
   - **Requirement links** — Point to the **user stories / test scenarios** this event supports: `#US-…` / `#TS-…` ids and/or paths to markdown under `plans/stories/`, `plans/scenarios/`, or branch plans, so evolve and test planning stay grounded in the same scenarios you had in mind when adding the emit.

   This section is **not** a substitute for `description` in frontmatter; `description` stays short and factual; **`## Rationale`** holds the narrative and planning context you will need when MCP returns time series, transitions, and metadata breakdowns.

2. **`## Metadata keys`** (or keep the heading `## Metadata` if you prefer)

   Document each metadata key using the **dot-scoped** form when it refers to a domain entity (`user.role`, `org.plan_tier`, …). For each key, specify **allowed values or value type**—prefer small **enums** or buckets (booleans, `low|med|high`) over free text. Note cardinality intent (e.g. “bounded set of roles only”). Non-entity dimensions may stay flat if clearer. Avoid documenting identifier-like keys; they must not be emitted.

---

## MCP tools (TrueCoverage)

Configured via **`@testchimp/cli`** with `TESTCHIMP_API_KEY`: `list-rum-environments`, `get-truecoverage-events`, `get-truecoverage-event-details`, `get-truecoverage-child-event-tree`, `get-truecoverage-event-transition`, `get-truecoverage-event-time-series`, `get-truecoverage-session-metadata-keys`, `get-truecoverage-event-metadata-keys`.

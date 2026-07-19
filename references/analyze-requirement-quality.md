# Analyze requirement quality (DeFOSPAM — local agent)

Use this playbook when the user asks:

```text
/testchimp analyze requirement: story <ordinalId>
/testchimp analyze requirement: scenario <ordinalId>
```

Requires **`@testchimp/cli` ≥ 0.1.19** (`get-requirement-quality-report`, `report-requirement-quality-findings`, plus plan fetch tools).

**MCP-only:** Call the same kebab-case tools via the TestChimp MCP server — never UI session routes (`/requirement-quality/*`).

## Prompt parsing

| User input | `subjectType` | `ordinalId` |
|------------|---------------|-------------|
| `story 42` / `US-42` | `STORY` | `42` |
| `scenario 107` / `TS-107` | `SCENARIO` | `107` |

## Flow (strict order)

1. **Fetch prior report (dedupe)** — MCP/CLI **`get-requirement-quality-report`**
   - Body: `{ subjectType, ordinalId }` (or `subjectEntityId` when known).
   - Save **`report.subject.subjectEntityId`** from the response (needed for report on later steps).
     The platform resolves entity id from ordinal even when no prior analysis exists.
   - Treat findings with **`userState`** **`IGNORED`** or **`APPLIED`** as **do-not-repeat** on re-run (match by **`fingerprint`** or same analyst + title + excerpt).
   - Do **not** re-report equivalent issues for IGNORED/APPLIED rows.

2. **Load requirement markdown (platform SoT)** — prefer MCP over inventing from stale local files:
   - **Story:** `get-user-stories --user-story-ordinal-ids <n>`
   - **Scenario:** `get-test-scenarios --scenario-ordinal-ids <n>`; for linked stories call **`get-user-stories`** for each **`userStoryOrdinalIds`** entry.
   - Use returned **`content`** as the analysis input. Local `plans/` files are a fallback only when MCP content is unavailable.

3. **Run DeFOSPAM analysis locally** (full skill below) — produce a single **`RequirementQualityReport`** JSON object (camelCase, protobuf JsonFormat shape):
   - **`metrics`**: scores 0–100 + severity counts among **ACTIVE** findings you emit.
   - **`findings`**: cap **50**, highest severity first; each new finding **`userState`** = **`ACTIVE`**.
   - **`subject`**: `{ subjectType, ordinalId, title, subjectEntityId }` — **`subjectEntityId`** is **required** for report:
     - Prefer **`report.subject.subjectEntityId`** from step 1.
     - Else use **`subjectEntityId`** from a prior **`report-requirement-quality-findings`** response.
     - Else pass **`--subject-entity-id`** on report when the user/platform supplied it.
   - **`source`**: omit or `LOCAL_AGENT` (server sets on persist).

4. **Report findings** — **`report-requirement-quality-findings`**
   - `--report-file /path/to/report.json` **or** `--json-input '{"report":{...}}'`
   - Convenience flags merge into **`report.subject`**: `--subject-type`, `--ordinal-id`, `--subject-entity-id`
   - Backend merges carry-forward for IGNORED/APPLIED findings not re-sent.
   - Persist **`report.subject.subjectEntityId`** from the response for future re-runs.

5. **Summarize for the user** — counts by severity, top findings, metrics; link to TestChimp plan UI when helpful. Do **not** dump raw JSON unless asked.

## DeFOSPAM methodology (local agent)

Attribution: methodology from OpenRequirements.AI / Business Story Method (Paul Gerrard). This is a **distilled** TestChimp pack (7 lenses, condensed prompts) — enough for `RequirementQualityReport` findings. For the full 7-analyst prompts, business-story generation, and Specification-by-Example companion skill, install **`openrequirements`** from [github.com/AgenticTesting/OpenRequirementsAI](https://github.com/AgenticTesting/OpenRequirementsAI) (`.claude/skills/openrequirements/SKILL.md` or equivalent) — optional, not required for this playbook.

### Lenses

Analyze using **DeFOSPAM** (Definitions, Features, Outcomes, Scenarios, Prediction, Ambiguity, Missing):

| Analyst | Lens | Look for |
|---------|------|----------|
| Dorothy | Definitions | Undefined terms, ambiguous nouns/verbs, synonym collision, conflicting definitions, missing business rules |
| Flo | Features | Unclear boundaries, missing decomposition, workflows without steps, mixed concerns |
| Olivia | Outcomes | Missing “so that” / value, unmeasurable outcomes, outcome–feature gaps |
| Sophia | Scenarios | Missing G/W/T coverage, happy-path only, edge/error gaps, scenario–story mismatch |
| Paul | Prediction | Missing expected results, unverifiable checks, missing preconditions |
| Alexa | Ambiguity | Vague qualifiers, open-ended “etc.”, unclear actors, temporal ambiguity |
| Maya | Missing | Missing actors, data, constraints, NFRs, error handling, dependencies, acceptance criteria |

**Severity:** `CRITICAL` (blocks understanding/testability), `MAJOR` (significant gap), `MINOR` (polish). **Confidence:** 1–10.

### Metrics (0–100)

- **clarity** — definitions / terminology  
- **completeness** — outcomes / missing data  
- **testability** — scenarios / prediction  
- **consistency** — conflicts across defs/features  
- **ambiguityRisk** — inverse weight of ambiguity findings  
- **scenarioCoverage** — story only: linked scenarios vs implied behaviors  
- **overall** — weighted blend  
- **criticalCount / majorCount / minorCount** — among **ACTIVE** findings emitted in this run  

### Prior findings rule

When step 1 returned IGNORED/APPLIED findings, **skip** re-reporting equivalent issues. New **ACTIVE** findings are allowed when the requirement changed or a genuinely new defect appears.

## SuggestedFix schema notes

Wire JSON uses **camelCase** (protobuf JsonFormat):

```json
{
  "kind": "REWORD_EXCERPT",
  "summary": "…",
  "agentPrompt": "Imperative instructions for an apply agent…",
  "rationale": "…",
  "replacements": [
    {
      "originalExcerpt": "exact substring from markdown",
      "suggestedText": "replacement text",
      "contextBefore": "optional anchor",
      "contextAfter": "optional anchor"
    }
  ]
}
```

| `kind` | Notes |
|--------|--------|
| **`REWORD_EXCERPT`** | **Must** include **`replacements`** with **`originalExcerpt`** + **`suggestedText`**. |
| **`REWRITE_SECTION`**, **`ADD_CONTENT`**, **`CREATE_SCENARIO`**, **`CREATE_STORY`**, **`LINK_OR_UNLINK`**, **`OTHER`** | Use **`agentPrompt`**; replacements optional unless excerpt-based. |
| **`DELETE_SCENARIO`**, **`DELETE_STORY`** | **Destructive** — server sets **`isDestructive: true`**. Require explicit user approval before any apply/delete workflow; never auto-apply. |

Always set **`agentPrompt`** with imperative instructions. Server derives **`isDestructive`** from kind for DELETE_* kinds.

## CLI examples

```bash
# Prior report + subject resolution (preferred first step)
testchimp get-requirement-quality-report --subject-type STORY --ordinal-id 42

# Fetch platform story markdown
testchimp get-user-stories --user-story-ordinal-ids 42

# Report structured findings (after local DeFOSPAM)
testchimp report-requirement-quality-findings \
  --report-file ./defospam-us-42.json \
  --subject-type STORY \
  --ordinal-id 42 \
  --subject-entity-id "<from-get-report-or-prior-response>"
```

Advanced bodies:

```bash
testchimp get-requirement-quality-report --json-input '{"subjectType":"SCENARIO","ordinalId":107}'
testchimp report-requirement-quality-findings --json-input @report.json
```

## Related

- Plan authoring: [`test-planning.md`](./test-planning.md)  
- CLI reference: [`cli.md`](./cli.md) § Requirement quality  
- Preamble **#4**: export **`TESTCHIMP_API_KEY`** (+ **`TESTCHIMP_BACKEND_URL`** when configured) before CLI calls  

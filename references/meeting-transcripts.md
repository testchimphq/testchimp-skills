# Meeting transcripts as agent context

## Cloud (authoritative)

Meeting Bots use **Recall cloud bots**. Persisted transcripts live in TestChimp cloud.

Fetch via MCP (API key auth):

`POST /api/mcp/get_meeting_transcript`

```json
{ "meetingId": "<meeting-id>", "summaryOnly": true }
```

Response includes `title`, `startMillis`, `summaryMd`, `summaryStatus`, and `transcriptMd` (empty when `summaryOnly` is true).

- `meeting-id` is the calendar event id when joined from a connected calendar.
- For ad-hoc paste-URL joins (no matching calendar event), `meeting-id` is a stable hash of the normalized meeting URL.

## Summary first, transcript when needed

Transcripts are large. Always start with the summary:

1. Call `get-meeting-transcript --meeting-id <id> --summary-only` (CLI ≥ **0.1.82**).
2. If `summaryStatus` is `MEETING_SUMMARY_READY` and the summary answers the objective, stop there.
3. Fetch the full transcript (no `--summary-only`) only when you need exact wording, quotes, speaker attribution, details the summary omits, or the summary is missing / not ready (`MEETING_SUMMARY_PREPARING`, `MEETING_SUMMARY_FAILED`, …).

## Local Desktop SDK (deprecated)

Local `~/.testchimp/data/meetings/<meeting-id>/transcript.md` was used by the old Desktop SDK Join path and is **no longer the primary source**. Prefer cloud MCP.

## Prompt pattern: single meeting

```
/testchimp referring the meeting <meeting-id> as context, do the following : [describe objective]
```

1. Resolve `<meeting-id>` from the prompt.
2. Fetch the summary (`--summary-only`), then the transcript only if needed (see above).
3. Use it as context for the objective.

## Prompt pattern: meeting set

Created from the Meetings page (filter or search, then **Start Chat**):

```
/testchimp using meeting-set context <meeting-set-id>, [do the following]
```

1. Call MCP / CLI **`get-meeting-set --meeting-set-id <meeting-set-id>`** (CLI ≥ **0.1.82**, `POST /api/mcp/get_meeting_set`).
2. The response `meetingSet` contains:
   - `filters`: what the user filtered on (`labels`, `startDateMillis` / `endDateMillis`, `participants`, `participantDomains`, `searchText`). Use these to understand the intent; `searchText` tells you what to look for inside transcripts.
   - `meetings[]`: `meetingId`, `title`, `startMillis`, newest first.
   - `truncated`: true when more meetings matched than were captured (tell the user the set is capped).
3. For each relevant meeting, fetch the **summary only** first. Fetch full transcripts only for the meetings where the summary is insufficient (or where `searchText` must be located verbatim). Don't pull every full transcript up front.
4. Cite meetings by title and date when reporting findings.

A meeting set only includes meetings the creator could see when it was created. Don't try to widen it by listing other meetings.

**Expired or unknown set:** sets expire after **7 days**. On HTTP 410 (expired) or 404, tell the user to create a new one from the Meetings page (**Start Chat**) and paste the new prompt. Don't guess the meeting list.

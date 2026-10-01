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

A meeting set only includes meetings the creator could see when it was created. When the user hands you a meeting set, stay within it: don't widen it with `list-meetings`.

**Expired or unknown set:** sets expire after **7 days**. On HTTP 410 (expired) or 404, tell the user to create a new one from the Meetings page (**Start Chat**) and paste the new prompt. Don't guess the meeting list.

## Search meetings

Use when the user asks about meetings without giving a meeting id or meeting-set id ("what did acme.com raise in last month's calls", "summarise Sales meetings that mention pricing"). CLI ≥ **0.1.83**.

**Scope:** only meetings shared with **all team members** are returned. Private meetings (participants only / specific users) never appear. If the user expects a private meeting, ask them to share it team-wide or create a meeting set from the Meetings page (**Start Chat**).

1. **Discover exact filter values** (when the prompt names a customer, person, or label):
   `list-meeting-filter-options` (`POST /api/mcp/list_meeting_filter_options`) returns `labels[]`, `participants[]` (`key`, `email`, `displayName`), and `domains[]` seen on team-wide meetings. Map the user's words to these values: a company name maps to a `domains` entry, and a person maps to a participant `key` (their email also works).
2. **List / search:**
   `list-meetings` (`POST /api/mcp/list_meetings`), newest first. All filters combine with AND; values within one filter combine with OR.
   - `--from` / `--to`: inclusive; `YYYY-MM-DD` means whole local days, or pass an ISO datetime or epoch millis. Resolve relative phrases ("last month") to concrete dates yourself.
   - `--label`, `--participant`, `--domain`: repeatable or comma-separated.
   - `--search "<text>"`: full-text over title + transcript (web-search syntax: `"exact phrase"`, `OR`, `-exclude`). Hits carry a `searchSnippet` with matches wrapped in `⟦ ⟧`.
   - Page with `--page-token <nextPageToken>`. Default page size is 50 (max 200, and max 25 with `--search`). Stop paging once you have enough meetings for the objective.
3. **Read:** for each relevant hit, call `get-meeting-transcript --meeting-id <meetingId> --summary-only` first. Fetch the full transcript only when needed (see [Summary first](#summary-first-transcript-when-needed)). Use `searchSnippet` to decide which meetings are worth opening.
4. Cite meetings by title and date when reporting findings. If there are no results, say which filters you applied and suggest loosening them rather than guessing.

```bash
testchimp list-meeting-filter-options
testchimp list-meetings --from 2026-09-01 --to 2026-09-30 --domain acme.com
testchimp list-meetings --label Sales --search "pricing OR discount" --page-size 25
```

Response (`list-meetings`): `meetings[]` with `meetingId`, `title`, `startMillis`, `labels`, `participants[]` (`displayName`, `email`, `mode`), `summaryStatus`, `searchSnippet` (search only), plus `nextPageToken` when more results exist.

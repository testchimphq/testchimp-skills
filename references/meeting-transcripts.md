# Meeting transcripts as agent context

## Cloud (authoritative)

Meeting Bots use **Recall cloud bots**. Persisted transcripts live in TestChimp cloud.

Fetch via MCP (API key auth):

`POST /api/mcp/get_meeting_transcript`

```json
{ "meetingId": "<meeting-id>" }
```

Response includes `transcriptMd`.

- `meeting-id` is the calendar event id when joined from a connected calendar.
- For ad-hoc paste-URL joins (no matching calendar event), `meeting-id` is a stable hash of the normalized meeting URL.

## Local Desktop SDK (deprecated)

Local `~/.testchimp/data/meetings/<meeting-id>/transcript.md` was used by the old Desktop SDK Join path and is **no longer the primary source**. Prefer cloud MCP.

## Prompt pattern

When the user asks to act on a meeting:

```
/testchimp referring the meeting <meeting-id> as context, do the following : [describe objective]
```

1. Resolve `<meeting-id>` from the prompt.
2. Call MCP / CLI `get_meeting_transcript`.
3. Use the transcript as context for the objective.

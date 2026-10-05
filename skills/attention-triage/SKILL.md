---
name: attention-triage
description: Triage the Outlook inbox, including the Jira and Confluence notifications inside it, into one comprehension-first digest ranked by Q3 OKR relevance. Use on "triage my inbox", "what's in my email", "what needs my attention", "catch me up on notifications".
---

# Attention Triage — skill

Triage the notification firehose (Outlook + the Jira/Confluence notifications inside it) into one comprehension-first digest, ranked by OKR relevance. Full design and rationale: `docs/ATTENTION-TRIAGE.md`. This file is the runnable procedure.

**Run it** standalone (`/attention-triage`) or let `/morning` dispatch the `attention_triage` routing rule. Config lives in `agent-manager-config.yml` under `attention_triage:`.

## The one hard rule (do not violate)

Comprehension first. This is not inbox-zero automation; it is situational awareness. Never present an item as a bare action. Never action, acknowledge, reply, or archive without the item's WHY and source link visible. Never hide or silently handle anything — Handled and Noise are always listed and expandable. If a step would trade understanding for speed, don't take it.

## Inputs (from config)

- `attention_triage.email_provider` — `microsoft365` (Outlook via the Microsoft 365 MCP).
- `attention_triage.okr_source` — the OKR yardstick (`01-sprint-operations/current/okrs-q3-2026.md`).
- `attention_triage.mode` — `classify_only` (pilot: no drafts, no sends) or `with_drafts`.
- `attention_triage.enrich_via_atlassian` — resolve each notification to the real ticket/page.
- `attention_triage.triage_log` — the running audit trail.

If any MCP (Microsoft 365, Atlassian) is not connected, say so at the top of the digest and degrade — never fabricate a summary, a priority, or a sender.

## Procedure

### Step 1 — SENSE the inbox (read-only)
Pull recent messages from Outlook via the Microsoft 365 MCP: unread, plus anything from roughly the last 24-48h (or since the last triage-log entry). For each message classify the *kind*:
- **Jira notification** (from the Jira notification address) — carries an issue key + event (comment, mention, assignment, status change).
- **Confluence notification** — carries a page + event (mention, comment, edit request).
- **Direct email** — a real person writing to you.
- **Automated/other** — digests, system mail, marketing.

Do not act on anything. This step only reads and classifies kind.

### Step 2 — ENRICH via Atlassian (read-only)
For each Jira/Confluence notification, resolve the **real underlying object** through the Atlassian MCP: the issue's current status/assignee/last change, or the page's actual mention/comment text, plus its links to epics/OKRs. Reason over the real object, not the email subject line — this is what makes the WHY trustworthy. If Atlassian is down, mark the item "unenriched (Atlassian offline)" and rank it conservatively; do not guess its content.

### Step 3 — SCORE against OKRs
Read `okr_source`. For each item compute an inspectable priority from these signals (never a black-box number):
- **OKR link** — match the item against each KR's `match_keywords` / `match_entities`. Record which KR(s) hit. (highest weight)
- **Waiting on you** — a direct @mention, an assignment, an explicit reply-needed, a real person's question. (high; qualifies on its own even with no OKR link)
- **Time pressure** — deadline, decision window, experiment past its read date.
- **Ownership** — your ticket/page/commitment vs cc/FYI-only.
- **Reversibility** — a hard-to-undo decision outranks a routine ack.

Record, per item, exactly which signals fired. That list *is* the WHY.

### Step 4 — BUCKET
- **📖 Read this yourself** — needs your judgment specifically (irreversible / strategic / ambiguous ownership / high OKR stakes). Keep this list short and honest.
- **✍️ Draft ready** — a routine reply/ack is safe to pre-write. In `classify_only` mode, still bucket it here but write **no draft** — just note "draft available in with_drafts mode."
- **🟢 Handled / FYI** — understood, no action needed. Classification only; nothing is done on your behalf.
- **🔇 Noise** — batchable, safe to skip. Group similar items. Never auto-archive.

### Step 5 — COMPOSE the digest
Write it in this order (the order enforces comprehension):

1. **State of your world** — 3-5 lines synthesising what is moving today and why, before any item list. What is heating up, who is waiting, what decision is live.
2. **📖 Read this yourself** — each item: `WHAT · WHY (signals + KR) · HOW (what to decide) · deep link`.
3. **✍️ Draft ready** — each item: `WHAT · WHY · HOW`. In `with_drafts`, show the draft preview + what it is based on + source link, each with `[show full / approve & send / edit / skip]`. In `classify_only`, no draft, just the WHY and the note.
4. **🟢 Handled / FYI** — each item: `WHAT · WHY informational · HOW (conclusion)`.
5. **🔇 Noise** — grouped counts, each expandable.
6. **Calibration** — invite corrections: "anything mis-bucketed?" A correction re-ranks and is written to the triage log so it tunes to your judgment.

Use the layout in `docs/ATTENTION-TRIAGE.md` ("The digest format").

### Step 6 — LOG (audit trail for situational awareness)
Append to `attention_triage.triage_log`: date, counts per bucket, and every item's `{kind, source ref, KR match, bucket, why}`. This is how awareness persists across days and how precision is measured during the pilot. Note any degraded source.

### Step 7 — Actions (gated, never auto)
Only in `with_drafts` mode and only after Step 5, per item, with a fresh yes:
- Sending a reply, posting a Jira/Confluence comment, acknowledging, or archiving is a `never_auto` action. Confirm the exact target and show the exact content before doing it. One item at a time.
- Nothing in Handled or Noise is ever actioned. Those buckets are classification only.

## Pilot mode reminder

Default `mode: classify_only` for week 1. Produce the digest, buckets, and WHY only. Each morning, spot-check the bucketing against what you'd have done by hand, correct mis-buckets (they train the ranker), and only move to `with_drafts` once the read-yourself/noise split is reliably right. If it ever feels like autopilot, that is a bug against the one hard rule — stop and fix comprehension.

## Failure handling
- Microsoft 365 MCP not connected → digest header says "inbox not read (M365 offline)"; do not invent messages.
- Atlassian offline → items stay "unenriched," ranked conservatively, flagged.
- No OKR source → rank on waiting-on-you + time-pressure only, and say so; do not fabricate KR links.

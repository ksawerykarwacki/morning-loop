---
description: "Load a morning brief by its #id (or a date, or 'latest') and pull in everything around it: the plan file, that day's agent drafts, the run-log entry, and the delivery receipt. Use when you want to pick up a morning brief in conversation."
argument-hint: "[#21 | 21 | 2026-08-05 | latest | last 3]"
---

# Brief: reopen a morning brief with its full context

Resolve `$ARGUMENTS` to one or more morning briefs and load everything attached to them, so the conversation can continue from what the loop already sensed instead of re-deriving it.

## Resolving the argument

The index is `05-automation/agent-manager/brief-index.json` (`{next_id, briefs: {"<id>": {id, date, plan_file, subject}}}`).

| argument | means |
|---|---|
| `#21`, `21` | brief id 21 |
| `2026-08-05` | the brief whose `date` matches |
| `latest`, empty | the highest id present |
| `last 3`, `3 latest` | the 3 highest ids, oldest first |
| `yesterday`, `monday` | resolve to a date in `owner.timezone`, then match |

If the id does not exist, say so and list the nearest ids with their dates. Never load a different brief than the one asked for and never guess. If the index is missing, fall back to globbing `01-sprint-operations/current/morning-plan-*.md` and number by date order, and mention that the index was rebuilt from filenames.

## What to load, in this order

1. **The plan file** (`briefs[id].plan_file`) in full. This is the brief itself and the primary source.
2. **That day's agent drafts**: every file in `01-sprint-operations/current/agent-drafts/{date}/`. These are what the loop drafted after the gate; a brief plus its drafts is the complete picture of that morning. If the directory does not exist, the gate was never answered that day, which is itself worth stating.
3. **The run-log entry** for that date from `05-automation/agent-manager/run-log.md`. This carries what actually ran, what degraded, and what was honestly not done.
4. **The delivery receipt** `05-automation/agent-manager/delivery-receipts/{date}.json`, if present: whether the brief was delivered, when, and to where. If the receipt says `failed` or is absent for a working day, flag it.
5. **The commitments ledger** (`paths.commitments_ledger`) only if the question needs cross-day state. It is large; do not pull it reflexively.

## Then orient, don't recite

The user was there that morning and has the email. Do not replay the brief back at them. Open with a short orientation and then wait, or answer the specific question they asked alongside the argument:

```
Brief #{id} · {date} ({weekday}, sprint {n}/{len})
Delivered: {yes at HH:MM / no + why}
Loaded: plan + {n} drafts + run-log entry

Top item that morning: {the one thing}
Still open now: {items from that brief that today's board says are unresolved}
Closed since: {items that have since moved}
```

**"Still open" and "closed since" require checking, not remembering.** The brief is a snapshot of a past morning. If the user is working from an older brief, re-verify anything time-sensitive against live Jira before treating it as current, and say plainly which facts you re-checked and which you are quoting as-of that date. A stale ticket status presented as current is the main way this command could mislead.

## Multiple briefs

When several are requested, load them oldest first and lead with **what changed across them** rather than summarising each: which items persisted, which aged, which resolved, and which appeared and vanished without resolution. A run of briefs is a trend, and the trend is usually the point.

## Notes

- Read-only. This command loads context and never dispatches, drafts, or ships anything. Dispatch is `/morning`.
- The email footer prints the reference (`morning loop #21`), so plain mentions of that phrase in conversation should resolve the same way this command does, without needing the slash prefix.

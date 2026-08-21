---
name: stall-escalation
description: Turn a stalled ticket into a named next action with an owner, rather than a nag. Use on "what's stuck", "stalled tickets", "this has been in code review for days", "escalate this". The stall detection engineers said actually worked.
---

# stall-escalation: turn a stalled ticket into a named question

**Audience: engineer** (useful to anyone owning delivery).

**Why this exists.** Stall detection is the one thing every engineer said worked. Andres: the nudges on tickets sitting too long in Code Review or Ready for release "already caught real things I'd have noticed later than I should have." Daniel Zhu's entire five-run report reduced to one detection, KM-11720 stuck in Ready for release, and one question: *who is the release-floor owner, and on what cadence do these reach PROD?*

And that is exactly where the loop used to stop. It reported the stall, day after day, while the number climbed from 11 to 18 to 154 days. **Detecting a stall is not the job. Closing it is.** This skill converts a detection into an ASK with a name on it, or a SOLVE where the next step is mechanical.

**Fires on** `jira_state`: a ticket you own, or that blocks your work, stalled beyond its status threshold.

---

## Thresholds by status

Age alone is not a stall. A ticket in Backlog for 90 days is a backlog; a ticket in Code Review for 5 days is a problem. Thresholds are per status because the meaning differs:

| status | stalled after | what it usually means |
|---|---|---|
| Code Review | 2 days | nobody was asked, or the reviewer is away |
| Ready for release | 3 days | **no release-floor owner**: the most common and most expensive |
| In Progress | 5 days | blocked but not marked blocked, or larger than estimated |
| Ready | 5 days in an active sprint | unassigned, or the sprint took on more than it can finish |
| Blocked | 2 days | the blocker has no owner or no date |

## What to produce

For each stall, work out **why** it is stalled, then emit one of:

- **SOLVE** where the next step is mechanical and needs no decision: request the review from a named person, move the ticket to the status it has actually reached, link the dependency someone forgot, or draft the release note. Do it on approval.
- **ASK** where one fact unblocks it, phrased closed, with a name. *"KM-11720 has been in Ready for release 154 days: who owns the release floor for this queue, and does it go out this week?"* Not "KM-11720 is very stale."

Never emit a stall as an observation with no type. That is the failure this skill exists to end.

**Escalate the ask, don't repeat it.** Track how many runs a stall has been reported. On the second report, the question goes to the person's lead as well. On the third, it stops being a ticket problem and becomes a process finding for the retro, and you say so: a queue where "Ready for release" does not promise a release floor is broken independently of any single ticket.

## Output

```markdown
# Stalled ({n})

## {KM-XXXX} · {status} {N}d · {goal-critical | goal-adjacent | loose end} · reported {M}×
{one line: why it is stalled, from the changelog, not guessed}
→ **{SOLVE: the mechanical next step}** or **{ASK {person}: {closed question}}**

## Process finding
{only when a stall has been reported 3+ times: what is structurally broken}
```

## Rules

- **Read the changelog, not the status field.** A status field says where a ticket is; the changelog says when it got there and what happened before. A field edit is not a status change, and mistaking one for the other has already put a three-week-old event on a plan as though it were yesterday's.
- **Verify the ticket is in your squad's scope** before surfacing it. `KM` is shared across squads.
- **Do not surface the same stall in the same words twice.** If nothing changed, either escalate the ask or say plainly that it has been asked N times and nobody answered, which is a different and more serious finding.
- A ticket stalled because of a conscious decision is not stalled. Check the Decision Log first.

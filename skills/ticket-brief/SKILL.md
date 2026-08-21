---
name: ticket-brief
description: Write an implementation kickoff brief for the engineer picking up a ticket: what to build, what to watch for, what is out of scope. Audience is the engineer, not the PO. Use on "brief me on this ticket", "kickoff brief", "what do I need to know before starting KM-xxxxx".
---

# ticket-brief: implementation kickoff brief for an engineer

**Audience: engineer.** The first drafter in the package written for the people building, rather than for a PO or a lead.

**Why this exists.** Xitong had to write his own version because the package shipped nothing for engineers, and twice in one sprint he hand-wrote tickets that a live run would have drafted from the previous day's meeting, at roughly 40 minutes each. This is that job, generalised.

**Fires on** `jira_state`: a ticket assigned to you that just moved to In Progress, or one you own that has been stalled 3+ days. One brief per ticket, never a batch digest.

---

## What it produces

A short brief that answers the four questions you actually open a ticket wondering about, in this order:

1. **What am I building, in one paragraph, in my own domain terms.** Not the ticket description reworded. If the ticket says "reuse the existing mini-profile API", say which endpoint and where it lives.
2. **What has already been decided about this**, from the Decision Log and the meeting notes, with dates. This is the part that saves the most time: decisions get made in meetings you were in three weeks ago and then you rediscover them by reading code.
3. **What is not decided yet**, phrased as the closed questions that need answering before or during the work, each with the person who can answer.
4. **Where it touches**, from the codebase and the ticket links: files, endpoints, migrations, feature flags, and any ticket that must land first.

## How to build it

- **Read the ticket, its parent epic, its subtasks and its links.** Parent stories often sit in Refinement while the real state lives in subtasks, so never assess a story from its own status alone.
- **Search the Decision Log** (`decision_log` in config) for this ticket key and for its feature name. Quote decisions verbatim with their date and who made them. A decision you cannot find a source for does not go in.
- **Search the meeting notes** for the ticket key and feature name over the last two sprints. Same rule: quote and attribute, or leave it out.
- **Read the code only where the ticket points.** Do not survey the repo. If the ticket names an API, find it and give the path. If it does not, say the touch points are unclear and make that one of the open questions.
- **Check for a blocking dependency**: any linked ticket not yet Done that this work needs. Name it and say whether it actually blocks or merely relates.

## Output format

```markdown
# {KM-XXXX} kickoff, {summary}
{status} · {assignee} · {estimate if set} · {sprint} · {goal-critical | goal-adjacent | loose end}

## Building
{one paragraph, domain terms, concrete}

## Already decided (do not relitigate)
- {date} · {decision, verbatim} ({who}, {which meeting})

## Not decided, needs an answer
- **{closed question}** → {person}   ← blocks {what}
- **{closed question}** → {person}   ← does not block, but changes {what}

## Touch points
- {path/endpoint/flag} · {why}
- Blocked by: {KM-YYYY, or "nothing"}

## Not covered here
{anything you could not verify, named plainly}
```

## Rules

- **Never invent acceptance criteria.** If the ticket has none, that is a finding for `ticket-quality-check`, not a gap for you to fill with a plausible guess.
- **Never invent a decision.** An unattributed "the team decided" is worse than silence, because it will be believed.
- **Quote, don't paraphrase, decisions.** Paraphrasing a decision is how its meaning drifts.
- **One paragraph means one paragraph.** An engineer reading this at 09:00 will not read a page. If the brief is longer than a screen, the ticket needs refinement, not a longer brief, and you should say so.
- Meeting summaries are paraphrases: never attribute a quote to a named person from a summary-level source.

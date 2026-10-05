---
description: "The coaching loop outside the morning brief: answer today's nudge, run the weekly review of what moved, or read the long-term development plan. The daily nudge itself arrives in the morning brief; you never have to call for it. Feedback on one meeting from its transcript is meeting-self-review."
argument-hint: "[empty for status | acted|declined|deferred | review | plan]"
---

# /coach

The daily nudge is delivered by `/morning` in the brief. This command is for the three things around it. `$ARGUMENTS` selects.

## Empty: where coaching stands

```
python3 05-automation/agent-manager/scripts/coach.py threads
python3 05-automation/agent-manager/scripts/coach.py log --limit 5
python3 05-automation/agent-manager/scripts/sharpen.py log --limit 5
```

Report per thread: raised, acted, declined, parked, last touched. Then name **any nudge with no outcome recorded**, because an unanswered nudge is the coaching equivalent of a carried item. Ask for the outcome of the most recent one, once. Do not chase the rest.

## `acted` / `declined` / `deferred`: close today's nudge

```
python3 05-automation/agent-manager/scripts/coach.py respond --id {the latest nudge id} --outcome {outcome} [--note "..."]
```

Same for a product challenge, with `sharpen.py respond --id {s..}` and `engaged|declined|deferred`.

**Record `declined` as declined.** Declining twice parks that thread or topic for thirty days, and that mechanism is the only thing keeping daily coaching from becoming daily nagging. Softening a decline into a deferral disables it and the loop keeps asking. Never editorialise about the choice.

## `review`: the weekly pass, and the one worth protecting

```
python3 05-automation/agent-manager/scripts/coach.py review --since {a week ago}
```

It prints movement per thread and the **draft-versus-posted pairs** from the outbound ledger. Then do the work the script cannot: for each pair, read the draft and the thing that was actually published, and report **what he changed**, quoting both sides.

Two outputs from that one pass, and both matter:

- **For him:** the pattern across the edits, not a list of them. What he consistently cuts, softens, refuses to claim without a source, or adds because he knew the room. That is his judgment in observable form and there is no better material for coaching.
- **For the loop:** the same diffs are the highest-quality drafter-improvement signal available, better than any rubric, because they are his revealed standard rather than a written one. Feed them to the skill's failed-check histogram.

Record what you learn as observations (`coach.py observe`), not as a document nobody re-reads.

## `plan`: read the long-term plan

```
python3 05-automation/agent-manager/scripts/coach.py plan
```

The plan is not recited in the daily brief, on purpose and by his request. **It is never withheld when asked.** Print it in full, and if he edits or deletes a thread, that changes the coaching immediately, because `coach.py` parses that file and nothing else. Never claim there is no plan.

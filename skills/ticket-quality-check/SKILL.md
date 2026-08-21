---
name: ticket-quality-check
description: Check whether a ticket is actually ready to build: testable acceptance criteria, clear scope boundary, named dependencies. Audience is the engineer, run before starting rather than after getting stuck. Use on "is this ticket ready", "check this ticket", or before refinement.
---

# ticket-quality-check: is this ticket actually ready to build?

**Audience: engineer.** Runs before you start, not after you are stuck.

**Why this exists.** A morning run flagged that KM-13401 had no acceptance criteria and surfaced it as the top open question **instead of inventing them**. That was the single clearest piece of value any engineer reported from the loop, and it deserves to be a first-class job rather than a lucky side effect of a verifier.

**Fires on** `jira_state`: a ticket assigned to you entering In Progress or sitting in Ready, and on `calendar` before a refinement you are attending.

---

## The checks

Run each independently and report `pass` / `fail` / `n/a` with one sentence. Default to `fail` when uncertain: a ticket you are unsure about is a ticket worth a question.

| check | fails when |
|---|---|
| `acceptance_criteria` | no AC, or AC that cannot be tested as written ("works well", "is fast") |
| `scope_boundary` | it is unclear what is explicitly **out** of scope, on a ticket that was narrowed in refinement |
| `dependency_named` | work depends on another ticket, endpoint or decision that is not linked or named |
| `design_available` | UI work with no linked mockup, or a mockup older than the last design decision about it |
| `instrumentation` | ships a user-facing change whose success metric is not named, or names an event that does not exist in Amplitude |
| `owner_of_open_question` | an open question exists on the ticket with nobody assigned to answer it |
| `estimate_sanity` | the estimate predates a scope change |
| `decision_conflict` | the ticket describes behaviour the Decision Log has since **rejected** |
| `comms_scaffold` | an epic with a user-visible change has no `Communications - {Epic Name}` story, or its sub-tasks are still open while the epic approaches launch |
| `metrics_defined` | an experiment ticket with no primary metric, no secondary metric, or no guardrail stated in the description |
| `launch_plan_current` | the ticket describes a launch mode or date that has since changed, and the comms artifacts were never re-briefed |
| `role_not_person` | a scaffold ticket is addressed to a named individual instead of a role, or was assigned to whoever was nearest rather than the role holder |

`decision_conflict` is the one that catches the expensive mistakes. A spec that describes a rejected approach will be built as written, because nobody re-reads a spec they have already read. This has happened: a screening spec continued to describe signals the team had ruled out on legal grounds.

## Output

```markdown
# {KM-XXXX} readiness: {READY | NEEDS N FIXES}
{summary}

## Blocking
- **{check}** · {what is missing} → **ASK {person}: {closed question}**

## Worth fixing, not blocking
- **{check}** · {what is missing} → {suggested fix}

## Passed
{check names, one line, no commentary}
```

## Rules

- **Never fill a gap you found.** Writing the missing acceptance criteria yourself converts a ticket-quality problem into a hidden assumption with your name on it. Surface it as an ASK with the person who owns the answer.
- **A failed check must name the person who can clear it.** "AC missing" is a complaint; "AC missing → ask Tomek whether partial saves count as completion" is a finding that closes. This is about who answers your question, not about who the work belongs to: launch-scaffold tickets stay addressed to a role and unassigned until the role holder takes them.
- **Do not re-report a check that was waived.** If a fix was consciously declined, record that and stop raising it. Waived is not the same as unfixed.
- Verify event existence against Amplitude rather than assuming from the name. Events get renamed and deliberately withdrawn, and a withdrawn event is a normal end state, not a fault.

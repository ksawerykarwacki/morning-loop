# What to take from Daniel's plan-drafting package, and what each thing fixes

**2026-09-25.** Assessment of `daniel-zhu/agents-work-log/packages/plan-drafting` against morning loop v4. Six items worth taking, four to leave. Every item below names the defect it fixes and the number that proves the defect is real, because "it looks useful" is how a loop grows features nobody uses.

**The headline:** the package is an engineering tool and does not fit. One of its components fixes the single defect that has blocked this loop for a month, and it is not the component the pattern discussion was about.

---

## 1. `questions.md` plus `parse_questions()` ,  capture without a command

**The defect, measured.** Between 2026-08-28 and 2026-09-24 the loop asked **9 things** (7 coaching nudges, 2 product challenges) and recorded **0 answers**. The autonomy assessment on 09-07 established the cause is not unwillingness: on the two days with recorded engagement Tomek made 10 ticket decisions and 2 hand sends. He acts. What he never does is run `coach.py respond` afterwards, because answering requires a second, separate act in a terminal.

The same cause sits under the carry ladder: the `testDirection` question reached `carried 3x` and the milestone page `carried 8x`. They carried because they went unanswered, and they went unanswered because answering was expensive.

**What his mechanism does differently.** The human types under `**Answer:**` in a file. A parser counts a question open until the span between `**Answer:**` and the next `---` holds non-whitespace. **No command at all.** Tested against our own ASK shape: unanswered `(1, 1)`, answered `(1, 0)`, empty file `(0, 0)`.

**How it lands in v4.** The ASK bucket stops being prose inside the brief and becomes `questions-{DATE}.md` in the review dir, next to `meeting-actions.md`. Tomek answers inline in a file he already has open at the gate. The next run parses it, and an answered question becomes a `question` item in the action queue with `derived_from` pointing at the ask, so the answer lands in provenance and the circle closes.

**What improves, and how we will know.** Two numbers that do not exist today: open questions per run, and answered-within-N-runs. Both are currently unmeasurable because nothing records an answer. This is the highest-value item in the package and the reason to do the adoption at all.

**Cost:** vendor one function. About half a day including the brief and gate wiring.

---

## 2. His materiality rule for options, which is better than the one I wrote

**The defect.** `V3-TO-V4.md` section 6 says the pattern is "**1 to 3 candidate plans** plus the agent's own open questions". A range invites padding to the middle of it, and I flagged the risk in the same paragraph without fixing it: three candidate plans on a mechanical job is theatre.

**His rule.** Options appear **only** where the candidate answers change the outcome in materially different ways: a day of work, a different surface, a different default. Where there is one defensible answer there is **no options list**; the agent states the answer it would take and the question becomes a confirmation. A clean ticket gets **zero** questions. The count is bounded by the blocker test, not a quota.

**How it lands.** Replace the "1 to 3" wording in section 6 and in `morning.md` with the materiality test.

**What improves.** The review cost is bounded by how contested the work actually is rather than by a number I picked. It makes the scoping advice structural instead of a warning.

**Cost:** a wording change.

---

## 3. Two-tier output ,  the only item that attacks the stated bottleneck

**The defect.** Tomek's ruling on 09-24: nothing auto-ships, he is the final gate on everything. He also named the consequence himself: **the review is the bottleneck.** There are **144 drafts across 38 days** and **15 ledger rows**. Today's review packet inlines up to 400 lines per draft, so reading it is unbounded work, which is the exact thing that does not scale under his own ruling.

**His shape.** A review layer on top (what, why, approach, rejected alternatives, risks, what done means, **no file paths**) and an execution layer underneath (real paths, snippets, verify commands). **The reviewer can approve from tier 1 alone.**

**How it lands.** The review packet grows a tier-1 block per item and moves the inlined body below a fold. The trust header already does half of this: it tells him which claims were re-queried and which are carried, so reading depth becomes a decision. Tier 1 finishes the job by making the decision possible without scrolling.

**What improves.** Time-to-review per item, which is the number his own ruling makes load-bearing and which nothing currently measures.

**Cost:** a change to `trust.py packet`. A few hours.

---

## 4. Content-hash invalidation ,  freshness as a computed fact

**The defect.** The trust layer holds a draft when a correction lands mid-session, and `morning.md` tells the gate to re-verify volatile claims before shipping. That second one is a **prompt instruction, not code**, and prompt instructions are what the whole trust layer exists to replace. Live example from today: 17 decisions are drafted from Maria's pages and waiting on ticks. If she edits one of those pages tomorrow, the tick stands and nothing notices.

**His mechanism.** Hash the source content. Approval drops back to `drafting` when the hash changes, so a plan signed off against a ticket that has since moved cannot be executed.

**How it lands.** The action queue stores a hash of `source.excerpt` plus its page version at draft time. `sync` refuses a tick whose source has changed underneath it and says which.

**What improves.** The staleness rule stops depending on the agent remembering to re-check, which is the same class of fix as computing the verdict instead of asserting it.

**Cost:** one field and one check in `tickets.py`. An hour or two.

---

## 5. "Absence and zero must not look identical" ,  and we currently break this

**The defect, and it is mine.** His rule: write the questions file even when there are none, because its absence and "no questions" must not look the same. I built the opposite twice on 2026-08-28. `morning.md` says of the product challenge: *"`{"challenge": false}` is the normal answer and the brief then carries no such section"*, and of coaching: *"`{"nudge": false}` means nothing is due, and then the brief carries no coaching section at all."*

So **a quiet day and a broken `sharpen.py` produce an identical brief.** That is the exact failure mode the whole loop was built to remove, reintroduced by me in the two newest features.

**How it lands.** Always render the section. "No challenge today: no decision signal" is one line and is information. Absence is not.

**What improves.** A silent failure in either engine becomes visible on the day it happens rather than whenever someone thinks to check the logs.

**Cost:** two lines in the brief template.

---

## 6. Convergent design worth noting rather than adopting

His `**Why it matters:**` field is our `changes_what` gate on the `research` kind, and "never ask a question the code already answers" is our ASK discipline. **We already have these**, arrived at independently, which is decent evidence both are right. The only gap: ours are enforced in the **meeting-action queue** and not in the **brief's ASK bucket**. Unify them rather than adopt anything.

---

## What not to take

- **Code grounding, the surfaces map, `codegraph_explore`.** Engineering-specific. There is no counterpart in a PO register.
- **The ticket label state machine and the `Ready → In Progress` move.** Not Tomek's job, and it writes to tickets.
- **The Mattermost notify step.** `notify.py` already does this, with receipts.
- **The autonomy contract as written.** It has the agent post a ticket comment and move a ticket unattended. That is correct for Daniel's register and **would violate Tomek's ruling 1 from 2026-09-24** if it travelled unchanged.

---

## Dependencies before any of this starts

1. **Daniel's repo is private to him.** Adopting means either vendoring `plan_state.py` into `morning-loop` with credit, or asking him to publish it where the squad can depend on it. A private single-owner dependency is the reusability problem this package exists to solve, reintroduced.
2. **Section 6 left packaging as his call**, and he has now done the packaging work. Ask before taking.

## Order

| # | item | fixes | size |
|---|---|---|---|
| 1 | Always render the section (item 5) | a silent failure in the two newest features looks like a quiet day | 10 min |
| 2 | `questions.md` + parser (item 1) | 0 of 9 asks answered in a month | half a day |
| 3 | Materiality rule (item 2) | my own "1 to 3" invites padding | wording |
| 4 | Two-tier packet (item 3) | the review is the bottleneck, by his own ruling | a few hours |
| 5 | Content hash (item 4) | a tick that survives its source changing | 1 to 2 hours |

Item 1 first because it is ten minutes and it is a live defect I introduced. Item 2 is the one that matters.

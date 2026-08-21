# Morning loop: v2 → v3

> **Looking for the overview to share with the team? Read `V2-TO-V3.1.md`.** This file is the per-release detail.


**Written 2026-08-21.** Every row below traces to something that actually happened, either in the run log or in a squad member's report-back on KM-14119. Nothing here is a good idea somebody had; if a change has no evidence column, it should not be in the release.

**The one-line version:** v2 made the loop proactive. **v3 makes it produce work.** Across seven consecutive v2 prep runs the loop planned 2 to 6 items every morning and dispatched zero of them, and every adopter reported the same thing in different words.

---

## The upgrades

| # | Area | v2 | v3 | Why, with the evidence | Asked for by |
|---|---|---|---|---|---|
| 1 | **Sensing** | `/standup`'s steps run end to end in one growing context | **Parallel fan-out.** Each probe is a sub-agent with its own bounded context | The chain dropped whatever sat at its tail. Run log: *"no Every.to; no ExoClick; commitments ledger still unreconciled (4th run)"*. First v3 run reconciled the ledger for the first time in 14 days, closing 9 items and surfacing 2 fired triggers nobody had seen | Derived from the run log |
| 2 | **Probe output** | Prose findings | **Claim + verbatim evidence contract.** A probe that cannot quote its source returns `unavailable`, never a softened claim | Four runs matched on a label instead of the row. The fourth retracted a finding that had been correct | Derived from the run log |
| 3 | **Findings** | Only drafts were verified, against rubrics. The brief was not | **A grounding gate before delivery.** Every claim asserting a status, number, absence, change or experiment state is checked by an independent skeptic | Every correction in the run log is a finding that went out unchecked: the false alarm carried 4 runs, the -12% that was really -2.5%, the retraction | Derived; sharpened by Maria |
| 4 | **Verifier method** | Not specified | **The verifier re-runs the query itself.** It never grades a claim against the probe's own output, and never batches by claim | *"KM-14064 has nine subtasks"* reached a delivered brief. The truth was six. The number came from our own probe conflating two result sets | **Maria (KM-14354 Q2)** |
| 5 | **Disagreement** | No tie-break. Two verifiers could contradict each other with no rule | **A third agent judges.** It sees the artifact, the disputed checks only, and both verdicts without knowing who said what. A block-severity fail *both* verifiers agree on is never adjudicated | On the 08-19 GC update the voice verifier passed 17 of 17 while the structure verifier found 3 block-severity failures, including a ticket called unowned that was assigned to Tomek | **Maria asked (Q3); Tomek chose the judge** |
| 6 | **The gate** | Asked permission to **start** work. Drafting was gated behind a human | **Pre-drafting moved into the unattended prep.** The prep drafts and verifies; the gate asks what to **ship** | 7 prep runs, 2 to 6 items each, **0 dispatched**. On the last one, 4 of 5 items expired at ceremonies happening that same day | Derived; **independently asked for by Xitong** (see below) |
| 7 | **Carried items** | A soft "carried-item discipline" paragraph | **A numeric convergence ladder.** Escalate at 2 carries, auto-promote to SOLVE at 3 if the loop can write the file, lead with the count at 4. Dedupe against everything ever surfaced | One config fix reached *"6th time of asking"*. The ledger went unreconciled 4 runs. Both were detected correctly every time and closed by nobody | Derived from the run log |
| 8 | **Config** | Reported stale values | **Repairs them.** If the correct value is verifiable from a live source, the loop edits the config and logs the diff. Never touches permissions, delivery, schedule or sprint cadence | `decision_log.current_page_id` pointed at Sprint 3 for two weeks and was reported six times. Fixed on the first v3 run, from one verified read | Derived from the run log |
| 9 | **Ordering** | Sense → plan → deliver | **Deliver before drafting.** The brief goes out on time with the drafts marked `drafting…`, then the same brief is updated in place under the same `#id` | Drafting six items with verification takes far longer than sensing. The brief must never wait behind the slowest thing in the run | Design consequence of #6 |
| 10 | **Meeting capture** | `ceremony_capture` wrote a file for every sensed meeting, squad ceremonies included | **`meeting_capture`.** Squad ceremonies are excluded because Maria records them. The loop captures 1:1s, design sessions, cross-squad and stakeholder calls instead | A second unofficial record of a ceremony someone else owns creates two sources of truth, and ours is the weaker one. The meetings with no scribe are where commitments actually go missing | **Tomek**, answering Maria's Q4 |
| 11 | **Failure diagnosis** | Grepped the **cumulative** log for auth strings | **Scoped to the current run's slice**, with a separate branch for machine sleep | Once *"Please run /login"* appeared on 2026-07-27, every later exit-1 reported as "Claude login expired" regardless of cause. **Four earlier miss diagnoses are unreliable** | Found while fixing Maria's Q5 |
| 12 | **Scheduler survival** | Bare `claude --print` under launchd | **Wrapped in `caffeinate -i`** | 2026-08-20: launchd woke the Mac at 08:01:04 (DarkWake), the run started, macOS returned to Maintenance Sleep at 08:01:49. **45 seconds.** The failure only surfaced at 08:12 when the lid opened | Derived from `pmset -g log` |
| 13 | **Notifier** | `top` was whatever the first ASK happened to be; numbered items were not counted at all | **Reads the brief's own `TOP OF YOUR LIST`**, and counts numbered items | Mis-picked the top item on 4 consecutive runs. The 08-19 brief announced "0 to draft" while carrying three drafts; the 08-20 brief counted 2 asks when it had 5 | **Maria (Q5)** |
| 14 | **Health check** | Verified the brief landed | **Also reports the drafted-but-never-shipped streak** (`0 shipped of 11 drafted across 4 days`) | A run of days producing drafts nobody ships is the same class of silent failure as a brief that never arrived, and it is the one the loop actually had | Derived from the run log |
| 15 | **Model tiering** | Everything on the session model | **Cheap probes routed down** (`sense.probe_model_cheap`) | Bounded extraction (run a JQL, read a chart, list an inbox) does not need the session model. Judgment lives in the plan and the verifiers | Cost, not a defect |
| 16 | **Run-log metrics** | Ready-without-edit rate and a failed-check histogram | **Two more: claims killed at the finding gate, and pre-drafted-but-never-shipped** | The first two measure output quality. The new two measure whether the loop is aimed at work anyone wants, which is the failure v2 actually had | Derived from the run log |

---

## What Maria's v3 review changed

Five questions on KM-14354, and **three of them changed the design rather than clarifying it.** She was blocking the trial on them, correctly.

| Her question | Outcome |
|---|---|
| Does a watchdog timeout reset the 5-day counter? | **Criterion changed.** Five successful scheduled runs, **not consecutive**. A failed day costs a day and nothing else |
| Does the verifier re-query, or check the probe's cached output? | **Now explicit in the spec**, plus a rule against batching by claim, which would quietly turn the gate back into self-agreement |
| What is the tie-break when verifiers disagree? | **A third agent judges the disputed checks.** Tomek's call, and better than the "any block-severity fail stops it" rule that was going in |
| Ceremony capture has no rubric. In scope or excluded? | **Excluded from the trial**, and the ownership question underneath it settled: ceremonies are Maria's |
| Is the notifier top-pick bug fixed before the trial? | **Fixed**, and it turned out to be two bugs |

She has not replied to the answers yet.

---

## Independent confirmation, which is the strongest signal in this release

**Xitong asked for v3's central change without seeing v3**, and framed it better than the release does. From his 08-21 report-back:

> One missing piece: gate matching blast radius — auto-run `external_action: none` drafts at prep time (all 4 lost drafting days were local-only).

That is #6, arrived at independently from his own run data, and his version is sharper: **a draft that ships nowhere does not need a gate at all.** v3 pre-drafts everything and still holds every item at the gate. Xitong's point is that local-only items could skip the gate entirely and simply be done. That is a v3.1 candidate, noted below.

He also gives the first real verify-pipeline numbers from an adopter: **first-pass READY 3 of 4**, one NEEDS-EDIT failing a single check, one revision round to 9/10 READY. That is the rung-three loop working on someone else's machine.

Three others confirmed the same bottleneck in their own words:

- **Daniel Zhu:** *"drafters ran for first time day 5 — dispatch gate is the bottleneck"* (Xitong's phrasing; Daniel's own v2 report was `0 of 21 working days delivered unattended`)
- **David Predusel:** *"No drafter has ever executed once. Not underperforming — never run."*
- **Chris Gamrot:** *"My JTBD has 14 automatable jobs; exactly 1 is automated."*

---

## What v3 does NOT fix, and the team asked for all of it

This is the honest half. v3 is an orchestration release. Every item below is a gap in **coverage**, and none of it moves.

| Gap | Who raised it | Status in v3 |
|---|---|---|
| **The dev drafters have never run for anyone.** `ticket-brief`, `ticket-quality-check`, `stall-escalation` are config entries with no installed skill | Daniel Zhu (*"literally never executed"*), Xitong (*"a local dev drafter I had to write myself"*), David (*"I cannot review them at all"*) | **Untouched.** Xitong reports `ticket-brief` works well once he wrote his own |
| **There is no CM drafter** | Chris Gamrot | **Untouched.** He did not migrate to the package and runs his own loop at 21/21 unattended |
| **There is no designer drafter**, and nothing in the release was shaped by a designer's needs | Flagged to Mathieu, who has not responded on the ticket | **Untouched** |
| **David is blocked by an org admin**, not by the loop: Rovo MCP needs API-token auth enabled | David Predusel | **Not fixable by the loop.** Twelve scheduled runs, zero output, empty run log and empty drafts folder |
| **Portability.** Maria is on Windows, Xitong and Daniel Zhu on OpenCode, Daniel Blam on Cursor. Every one of them patched the runner | Maria (UTF-8 + a Windows port), Xitong (three distinct OpenCode failure classes), Daniel Zhu (`--model` pin), Andres (13 fixes across two sessions) | **Untouched.** The package still assumes Claude Code on macOS |
| **Zero ASKs in 21 runs** for a community-manager profile | Chris Gamrot | **Untouched.** The ASK type does not fire for CM work, which suggests it is tuned to PO-shaped jobs |

---

## v3.1 candidates from this week's feedback

Not in v3. Recorded so they are decided rather than forgotten.

1. **Skip the gate for local-only drafts** (Xitong). `external_action: none` items ship nowhere, so holding them at a gate buys no safety and costs the day.
2. **Template slots in the brief, not prose instructions** (Andres). *"Brief sections need template slots, not just prose instructions."* The brief's shape drifts run to run because the spec describes it in sentences.
3. **Never let the agent reconstruct a sub-procedure from memory** (Andres). *"Don't let agent reconstruct sub-procedure logic from memory — invoke the real thing."* Applies directly to Phase 1 re-implementing `/standup` steps instead of calling them.
4. **A rubric for meeting capture**, which is the reason it is excluded from the trial.
5. **Two tools Andres is offering to the squad** (`ac-timesheet`, `ac-email-digest`, documented in his claude-tools repo). Worth noting against the L2 reusability KR: this is the first automation someone other than Maria has offered for others to use.
6. **The morning-feedback round is 28 days overdue** (Daniel Zhu's count).

---

---

## Run #30 (2026-08-21): the first unattended v3 run, and what it taught

This section is written from the artifacts on disk, not from recollection. It is the most useful run in the file because it went further than any previous run and then failed in a new place.

**What worked, and three of these are firsts:**

| | Evidence |
|---|---|
| **Fired exactly on time**, 07:52:01 | First on-time fire in the log. Previous fires landed at 08:01, 08:07 and 08:36 because the Mac was waking from sleep. `caffeinate -i` held |
| **Brief delivered unattended**, 08:09:37 | Receipt `status: sent`, brief #30, 17 minutes into the run |
| **Phase 2p ran unattended for the first time** | 5 draft files written to `agent-drafts/2026-08-21/`, 08:31 to 08:40, between 5.7KB and 37KB each |
| **The delivery-before-drafting ordering paid off, measurably** | Brief out at 08:09. Drafts 08:31 to 08:40. Watchdog kill 08:42. **The kill cost nothing that had not already been delivered**, which is exactly the claim the ordering was designed to make true |

**Then the watchdog killed it at 08:42:02, exit 143, at exactly the 50-minute limit.** Four findings follow, and they are the substance of this section.

### 1. The bottleneck moved, and it moved somewhere worse

v2's ceiling was **the gate**: a decision nobody made. v3's ceiling is **the clock**: a timer that cuts the work in half. Six pre-drafts do not fit in 50 minutes.

This release told you `dispatch.max_predrafts` was the cost ceiling and to lower it if the loop felt expensive. That was the wrong lever. **The binding constraint is wall-clock, not tokens**, and the honest reading is that either the limit goes up, the item count comes down, or the drafts get cheaper.

### 2. A watchdog kill mid-pre-draft is completely silent

The runner only diagnoses a failure when the plan file is **missing**. The plan existed, so the branch taken was `delivery: already delivered today, nothing to do`, **no alert fired and no diagnosis was written.** Nobody was told the drafting had been cut short.

That is the exact failure the loop's own contract calls out: *"a silent failure is worse than no automation, because you think you are covered."* v3 fixed that for missing briefs and reintroduced it for truncated drafting.

### 3. Six were planned, five were produced, and the sixth vanished without a word

The brief lists six items. Five files exist. The missing one is item 6, *"the missing 2026-08-20 run-log entry"* — the loop repairing its own evidence trail — and it was the smallest job on the list.

Two things follow. **Nothing reports a planned-but-unproduced item**, so the gap is invisible unless you count files by hand. And the **ordering is wrong**: completion timestamps run 08:31, 08:32, 08:33, 08:35, 08:40, with the largest artefact finishing last and the smallest never running. A shortest-job-first tiebreak inside the priority band would have landed all six.

### 4. None of the five drafts carries a verify stamp, so the gate cannot say what is shippable

Every file opens straight into content. No per-check results, no READY or NEEDS-EDIT label. The draft → verify → revise → label pipeline did not complete for any of them.

**This is the most important finding in the run**, because v3's promise was not "drafts exist" but "finished, graded drafts waiting for a yes". What landed was finished, **ungraded** drafts, which puts the reading burden back on you and is most of what v2 already did.

The cause is structural rather than a bug: **verification is batched behind drafting instead of running per item.** A kill therefore leaves zero graded drafts rather than N graded drafts. The same applies to the brief, which still reads `drafting…` in its 🤖 section and permanently understates what is on disk, because Phase 2p updates the brief once at the end instead of after each draft.

### What run #30 changes in this release

| Change | Why |
|---|---|
| **Verify each draft immediately after it is written**, not as a batch at the end | So a kill leaves graded work behind. This is a one-line reordering of Phase 2p with a large payoff |
| **Update the brief after each draft lands**, not once at the end | So the delivered brief always reflects what exists on disk |
| **Treat a watchdog kill as a reported outcome**: `killed at N min, M of P drafts complete, K verified` | The runner currently only diagnoses a missing plan file, so this whole class is invisible |
| **Report planned-but-unproduced items** in the health check | Five files against six planned items should not need counting by hand |
| **Shortest-job-first inside the priority band** | The smallest item was the one lost |

**Honest scoring against KM-14354.** Run #30 is the closest thing to a pass so far: it fired on time, delivered unattended, and produced real drafts with no human present. It does **not** count, because the criterion requires a drafted **and independently verified** artefact and none of the five was verified. **Day count still zero of five.**

## How to tell whether v3 worked

Not "does it feel better". Four numbers, and the last two are new:

| Number | v2 baseline | What a bad value means |
|---|---|---|
| **Scheduled runs that produced a verified draft unattended** | **0 across 7 runs** | The release did not land. This is the acceptance criterion on KM-14354: five successful runs, not necessarily consecutive |
| **Ready-without-edit rate** | Xitong: 3 of 4 first-pass | The drafters are not shippable; fix the skill via its failed-check histogram |
| **Claims killed at the finding gate** | n/a, the gate did not exist | High means the probes assert things they cannot ground; fix the probe contract. **Zero on day one means the gate is not actually running** |
| **Pre-drafted but never shipped** | n/a, nothing was pre-drafted | The loop is aimed at work you do not want; fix the routing rules, not the drafters. This is the number that would have caught seven dead runs on day two instead of day fourteen |

**Current state, stated plainly.** Day one (08-19) was hand-invoked. Day two (08-20) fired on schedule and died after 45 seconds of DarkWake. Day three (08-21, run #30) fired exactly on time, delivered the brief unattended, and produced five real drafts before the watchdog killed it at 50 minutes with none of them verified.

So the trajectory is right and the count is still **zero of five**. The scheduler problem is solved. The remaining gap is that pre-drafting does not finish inside the window and does not leave graded work when it is cut off, both of which are addressed by the five changes in the run #30 section above.

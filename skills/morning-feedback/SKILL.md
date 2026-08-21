---
name: morning-feedback
description: Collect structured feedback from someone who has been running /morning for about a week, reading their own run-log for objective signal, so the one shared loop improves. Fired by /morning around day 7, and on demand via "morning feedback", "how is the loop working for X".
---

# Morning Feedback — improve the shared agent-manager loop

Collects structured feedback from someone who has been running `/morning` for about a week, so the **one shared loop** gets better from everyone's real use. It reads the adopter's own run-log for objective signal, asks a short set of questions, writes a feedback file, and drafts a summary to route to the loop's owner (Tomek). Nothing is sent externally without the adopter's explicit confirmation.

This is triggered automatically by `/morning` (the `feedback_due` check) around day 7, and can also be run on demand: `/morning-feedback`.

---

## When it fires
`/morning` surfaces this once when, per the adopter's `feedback` config block:
- `feedback.enabled: true`, AND
- today ≥ `first_run` + `after_days` (default 7), AND
- no feedback file exists yet for this round in `collection_dir` (or `reminder_every_days` has elapsed since the last one).

If `first_run` is blank, stamp it from the earliest dated entry in the adopter's `run_log`, or from today, and write it back to the config.

---

## Step 1 — Gather objective signal (no questions yet)
Read the adopter's `paths.run_log` and count, across their runs since `first_run`:
- **Runs completed** (how many days they actually ran it).
- **Drafts produced** vs **shipped** vs **discarded**.
- **Ready-without-edit rate** — the share of drafts the verifier marked `READY` that shipped without a rewrite. This is the rung-three signal; it matters more than any opinion.
- **Which drafters scored low repeatedly** (candidates for the offline skill-improvement loop).
- **Degradations** logged (MCPs unavailable) — a tooling problem, not a loop problem.

Carry these numbers into the summary so feedback is grounded, not just vibes. If the run-log is thin (< 3 runs), say so and keep the questions lighter — a week of barely using it is itself a signal.

## Step 2 — Ask the adopter (keep it ~5 min, 5 questions)
Ask these directly (use the question UI if available; one at a time is fine):
1. **Time:** roughly how much time per day does the loop save you vs doing it by hand? (none / <15m / 15–30m / 30–60m / >60m)
2. **Trust:** of the drafts it produced, what share could you ship with no rewrite? (does the objective number above match your feeling?)
3. **Best + worst:** which one job is most worth keeping, and which drafter most often needs a rewrite (or which routing rule fires when it shouldn't)?
4. **Missing:** is there a recurring job of yours the loop *should* be running but isn't? (a routing gap)
5. **One change:** if you could change one thing about the loop, what?
Plus an open field for anything else, and a rung self-assessment: is your loop at Assisted (you still trigger + fix) or genuinely Orchestrated (fires on schedule, ships with light review)?

## Step 3 — Write the feedback file
Write to `feedback.collection_dir` as `{owner-slug}-{DATE}.md` with:
```markdown
# Morning-loop feedback — {name} ({role}, {squad}) — {DATE}
Running since {first_run} · {runs} runs · ready-without-edit {r}% · time saved ~{x}/day (self-reported)

## Objective (from run-log)
- drafts {n} · shipped {s} · discarded {d} · avg verifier score {q}/10
- weakest drafter: {skill} ({avg score}) → skill-improvement candidate
- degradations: {list or none}

## What they said
- Time saved: {…}
- Ready-to-ship share: {…}
- Best job / worst drafter: {…}
- Missing job (routing gap): {…}
- One change: {…}
- Rung self-assessment: {Assisted | Orchestrated} — {why}
- Other: {…}

## Recommended actions (for the shared loop)
- [ ] {config/template change, routing default, or skill-quality-loop target}
```
Derive the "Recommended actions" from the answers: routing-default changes and template wording go to the shared template/command; a weak *drafter* goes to the offline skill-improvement loop (`focused-skill-improvements.md`), which raises that skill's baseline — keep the two loops distinct (this feedback tunes the *loop*; that loop tunes a *skill*).

## Step 4 — Route a summary to the loop owner (gated)
Draft a 3–5 line summary for `feedback.route_to` (Tomek) — the numbers + the single most important change. Then **ask** whether to:
- post it to `feedback.route_channel` (e.g. KM Growth Mattermost), or
- just leave the file for Tomek to read, or
- send nothing.
Posting to a channel is a `never_auto` action — never send without an explicit yes. Default to leaving the file if no answer.

## Step 5 — Close
Mark this round done (the file's existence is the marker; the `feedback_due` check won't re-fire until `reminder_every_days` elapses). Append one line to the run-log:
`{DATE} feedback: {name} round-{k} collected (ready-without-edit {r}%, top change: {…})`.

---

## For the loop owner (Tomek): reading the aggregate
When several feedback files exist, the signal to act on:
- **Ready-without-edit rate trending up** across adopters = the loop is reaching rung three. That is the real KR3.3 evidence, not "N people installed it."
- **The same drafter weak across people** = point `focused-skill-improvements.md` at it.
- **The same routing rule flagged as noisy/missing across people** = change the *template* default so new adopters inherit the fix.
- **Someone stuck at Assisted after 2 weeks** = a setup/config problem (too many rules, or a scheduling gap) — pair with them, don't just tune skills.
Roll the aggregate into a short note for the GC / squad-leader forum: adoption count, median ready-without-edit rate, top-3 changes shipped to the shared loop this round.

# Morning Loop v2: what changed and why

v1 asked you to remember to run it. v2 arrives on its own.

Everything below came out of the KM-13612 adoption round: 7 people, ~40 logged runs, and a set of findings that were sitting in personal repos and Jira comments where nobody else could use them. This file is the fold-back. Statuses in `docs/history/MODIFICATIONS.md` are updated to match.

---

## The loop is now proactive

**v1:** scheduled pre-run wrote a plan file to your laptop. If you didn't open Claude Code, the sensing might as well not have happened. Every adopter independently reported the same thing, in different words: the loop is good, but it only helps on days you remember it.

**v2:** the run has four parts instead of two.

```
RUN  ──▶  DELIVER  ──▶  NOTIFY  ──▶  HEALTH
07:52     the whole      one line    verify the END
prep      brief, to      so you      deliverable exists,
          somewhere      don't have  not that a script
          you open       to remember exited 0
```

Configure it in one block (`schedule` / `delivery` / `notify` / `health` in your config). Pick a `delivery.channel` you **actually open**. The v1 default of `local_file` is why nobody read their brief on a day away from their desk.

The safety contract did not change. Delivery sends already-sensed read-only output to **your own address only**, with no cc, no replies, and no other recipient. Dispatch still happens at the interactive gate, and anything addressed to another human is still `never_auto`. The one new permission, `deliver_brief_to_self`, is deliberately that narrow.

## Delivery costs zero setup, and that was the hard-won part

The first cut of this delivered by email. It worked, and it was still wrong, because it failed on **adoption** rather than on engineering. Getting one brief into one inbox meant: an MCP connector that refuses write tools, so fall back to SMTP; SMTP needs an account; the obvious free account needs 2FA enabled before it will issue a credential; and that credential page is often hidden on new accounts or silently resolves to the wrong signed-in account. I hit every one of those in a single morning while building it.

If the person who built the loop is fighting a provider at 8am, nobody on the squad is going to set it up, and **a brief nobody configured delivery for is worth exactly as much as no loop.** So the default changed, and the email path was removed outright rather than left in as an option nobody should pick:

- **`macos`** (default): native notification with the counts and your single top item, plus the brief rendered as a local web page, opened with `open -g` so a 07:52 run never steals focus. Nothing to sign up for. Works offline.
- **`mattermost`**: one incoming-webhook URL. No account, no 2FA, no MCP, and we already live there. Use this if you want it on your phone or you are not on a Mac.

`scripts/SETUP-DELIVERY.md` is the two-minute version. `run-prep.sh` also carries a shell-level safety net: if no `sent` receipt exists by the end of a run, it delivers the brief itself, so delivery never depends on the model remembering to call a script.

The general lesson is the part worth keeping, because it will apply to the next thing we add: **measure a step's adoption cost, not just whether it works.** A step that requires an account is a step most people will not complete.

## Every brief has an id, so you can pick it up later

The sender numbers each brief and puts it in the subject: `☀️ Morning Brief #21 · 2026-08-05`. Later, in your terminal, `/brief 21` (or just mentioning `morning loop #21`) reloads that brief's plan file, that day's agent drafts, its run-log entry and its delivery receipt, so you can continue from what the loop already sensed instead of re-deriving it. `/brief last 3` leads with what changed across them, since a run of briefs is usually more informative than any single one.

The index lives in `brief-index.json`. One rule is baked into the command: a brief is a **snapshot of a past morning**, so anything time-sensitive gets re-verified against live Jira before it is treated as current, and the command says which facts it re-checked and which it is quoting as-of that date.

## Why HEALTH is not optional

The most useful finding in the adoption round was a failure.

Maria's Monday briefing failed silently, twice. The scheduled task had never been re-registered after a laptop migration, and the check that was supposed to catch it reported healthy, because the *cloud half* of a two-stage routine had succeeded while the actual end deliverable was missing.

The same class of bug was live in this workspace while v2 was being written: a cloud routine, enabled, firing every weekday since 27 July, that had **never delivered a single brief**. Its tool allowlist excluded every MCP tool, so it could not read Jira, could not read the inbox, and could not send. Nothing surfaced that, because nothing was checking the end artifact.

So `health` checks four things. The one that matters most is `check_previous_run`: **a working day with no run-log line is a silent miss, and gets reported.** A silent failure is worse than no automation, because you think you're covered.

## The other changes

**Phase 0, MCP preflight.** Every run now probes its sources first and prints `Atlassian ✅ · M365 ✅ · Amplitude ⚠️ degraded (reason)` before sensing anything. Three adopters hit a confusing first failure that turned out to be a permission gap, not a broken loop. It also distinguishes a *denied tool name* from an *absent server*, because the fix differs: allowlist entry vs reconnect. Watch for stale aliases: an allowlist entry for a tool that has since been renamed denies silently forever.

**Namespaced config resolution.** `/morning` now resolves `$MORNING_CONFIG` → `agent-manager-config.<you>.yml` → the default path, and **stops with the paths it tried** if none resolve. Raised twice in the adoption round, worked around with personal overrides, now actually fixed.

**Squad-scope guard, mandatory.** `KM` is shared across squads. Every ticket must be JQL-verified against your `owner.jira_boards` before it reaches your plan. Pattern matching on ticket keys pulled the same two other-squad tickets into a plan twice.

**`daily_spine` is a slot, not a product.** Documented properly: map it to whatever answers "what needs *me* today" for your role. `/standup` is the PO default and is built around squad-toward-OKRs. A dev maps it to `/team-standup`; a POC or support role to their own daily-overview. Run one spine, not two.

**`owner.timezone`.** The day boundary follows your morning, not CET midnight. Matters for anyone outside Berlin time, and it was quietly corrupting "since last run" diffs.

**Ceremony capture writes files.** Sensed meetings are now written to `paths.meeting_notes_dir` as artifacts. Reasoning about a transcript inside a run and then discarding it does not count as captured. That gap alone was missing a capture target by mechanism rather than by anyone's choice. Also: never attribute a quote to a named person from a summary-level source. Summaries paraphrase, and their speaker attribution is not reliable.

## Findings are typed now: SOLVE, ASK, or HUMAN

The biggest behavioural change, and the one that makes this feel less like a report and more like a colleague.

v1 emitted findings as prose for you to act on, which meant it described the same problem every morning without ever closing it. Real example from this workspace: a ticket sat in Ready for release while the loop faithfully reported it at 11 days, then 14, 16, 18, and eventually 154. Reporting a stall is not the same as closing one.

So every finding now has exactly one type:

- **SOLVE**: the agent has everything it needs. It does the work on your approval and does not ask you about it.
- **ASK**: the agent knows the fix but is missing exactly **one** fact, so it asks **one closed question with a name attached**. "This is 21 days old and nobody has answered it" is a complaint. "Did KM-13557's redirect ship at 100% or roll back?" is an ASK, and answering it in one sentence unblocks the agent to finish the job.
- **HUMAN**: genuine judgment, relationship or authority. Handed over with the context already gathered so you do not start cold.

If a gap cannot be phrased as one closed question, it is not an ASK: either the agent already has enough (SOLVE) or it needs judgment (HUMAN).

Alongside it, a loose-ends rule. Every carried item must **escalate** into an ASK or SOLVE, **close** as overtaken by events, or **park** with an explicit date. Silently re-listing an item for a fourth day is now a failure of the plan phase, and the carry count is shown, because a high count is itself the finding. Sprint goal is stated at the top of every brief and each item is tagged goal-critical, goal-adjacent or loose end, so the goal outranks age. Loose ends still surface, because that is how work rots, but they sit below the goal and they are candidates for pruning rather than attention.

## The Decision Log is now an input, not a parallel universe

The squad's Confluence Decision Log records **why the world is the way it is**. The loop detects **what changed**. Both are good; neither was reading the other, and the gap produced a fake crisis.

Two Amplitude events went dark. The loop reported it as broken instrumentation, attributed the events to the wrong hypothesis, and escalated it as a critical decision item on four consecutive days, on its way into a Growth Circle update. The Decision Log had the answer the whole time: the team had deliberately withdrawn those events days earlier, to cut event volume in Amplitude, once the experiment they belonged to hit 100% rollout. Nothing was broken.

Two compounding mistakes: treating a dark metric as necessarily a fault, and guessing which hypothesis owned it. So the loop now **checks the Decision Log for an explaining decision before escalating any anomaly**, and never asserts which KR or hypothesis a metric serves without verifying ownership. The reverse check matters too: a decision in the log with no corresponding change in the world is also a finding, and usually a better one.

Keep the Decision Log going. It is doing work the loop cannot do.

## There is finally a dev package

This was the largest gap in v1, stated plainly: three developers adopted the loop and the package shipped **zero** drafters that served them, so one of them wrote his own out of necessity.

Copy `skills/agent-manager-config.engineer.yml` instead of the generic template. Six fields to fill, `daily_spine: team-standup` rather than the PO standup, and none of the PO/lead drafters, so you are not left wondering which of `growth-circle-update` or `okr-tracker` you were supposed to run. Three new drafters, each traceable to something an engineer actually reported rather than to a guess about what engineers might want:

- **`ticket-brief`**: implementation kickoff brief. What you are building, what has **already been decided** about it (quoted and dated from the Decision Log and meeting notes), what is still open as closed questions with names, and where it touches. Built because a dev hand-wrote tickets twice in one sprint that a live run would have drafted from the previous day's meeting, at roughly 40 minutes each.
- **`ticket-quality-check`**: is this actually ready to build? Acceptance criteria, scope boundary, dependencies, design availability, instrumentation, and whether the ticket describes behaviour the Decision Log has since **rejected**. It never fills a gap it finds, because writing the missing acceptance criteria yourself converts a ticket problem into a hidden assumption with your name on it.
- **`stall-escalation`**: per-status thresholds, since a ticket in Code Review for 5 days means something different from one in Backlog for 90. Every stall becomes an ASK with a name or a mechanical SOLVE. After three unanswered reports it stops being a ticket problem and becomes a process finding for the retro.

`pr_description` and `test_scaffold` were both asked for by name and are **not built**. They are listed as proposed so the next feedback round decides build order rather than me guessing.

## What v2 still does not fix

These gaps are the input to v3.

**No designer drafter, and no designer input.** The engineer gap is closed; this one is not. There is exactly one designer on the squad, he did not get to file feedback in the v1 round, and nothing in this release was shaped by a designer's needs. A design-review digest and a Figma-to-frontend handoff check are the obvious candidates, but they should be specified by the person who would use them, not by me.

**`meeting-debrief` is PO-shaped.** It self-describes as calibrated for PO operations, meaning stakeholder implications and escalation paths. An engineer needs *my commitments, decisions that change my implementation, blockers I own*. The proposed `perspective: owner-role` parameter is not built yet. Related: the PO/lead-only drafters (`growth-circle-update`, `sprint-report`, `okr-tracker`, `ops-update`, `stakeholder-comms`) should carry an `audience:` label so adopters skip them instead of wondering.

**No `install.sh`.** It is still easy to half-adopt: working config, drafts, and a run-log, but `/morning` itself never runs because the command files were never copied into an active commands dir. Three people rediscovered this independently on three different clients. A bootstrap script plus a client-portability matrix (Claude Code / Cursor / OpenCode all use different dirs) is proposed, not written.

**Local schedulers are still machine-dependent.** `health` + a cloud backstop makes a miss *visible*, which is a real improvement over silent. It does not make the miss stop happening. The honest end state is a cloud-reachable home for the package so a cloud routine can run the *same* files everyone edits, rather than a hand-synced copy. That decision is still open and it is the prerequisite for the whole squad clearing the automation bar.

**Ready-without-edit is still mostly self-reported.** Run-logs do not consistently record per-draft verifier verdicts, so the headline quality number is an estimate rather than a computed rate. The run-log convention exists in v2's format string; it needs a few weeks of actual use before the number means anything.

**Refinement-prep "Key Questions" is the weakest drafter.** Measured against a real meeting: agenda sourcing matched 3/3 and DoR-gap flagging was accurate, but every question that actually mattered came from live squad domain judgment, not ticket-text analysis. The fix is to reframe it as "known unknowns": flag open unknowns and ambiguous ownership explicitly instead of guessing questions from ticket text. Not done yet.

## Upgrading from v1

1. Pull the package. Read this file and `docs/RUN-AND-NOTIFY.md`.
2. Add the four new blocks to your config: `schedule`, `delivery`, `notify`, `health`. Fill every `<PLACEHOLDER>`.
3. Add `owner.timezone` and `owner.jira_boards`.
4. Add the `routine_health` and `ceremony_capture` routing rules.
5. Point `delivery.channel` at something you open when you're not at your desk.
6. Run `/morning --prep` once by hand and **confirm the brief actually arrived**. If it didn't, the preflight line in the output tells you which tool was missing.
7. Turn `health` on the same day you set up delivery, not next week.

If your MCP tools are permission-gated, check your allowlist before blaming the loop, and check it for *stale names* as well as missing ones.

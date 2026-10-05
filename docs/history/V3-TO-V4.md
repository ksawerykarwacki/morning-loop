# Morning loop v3.1 to v4: what changes, why, and where it came from

**Written 2026-09-08.** Every row below traces to a specific adopter report on KM-14354, a defect in
the run log, or a measurement taken this week. Nothing here is on the list because it would be
interesting to build.

`V4-OPTIONS.md` (2026-08-22) argued the strategy: **you can give away exactly as much work as you can
check without reading it.** That still holds and the new evidence strengthens it. This document is the
change list, and it adds one thing `V4-OPTIONS.md` did not have: a rung underneath verification
throughput, which is that **the trigger does not fire.** Not one cause but three, and they need three
different fixes: a sleeping machine (Daniel Zhu), a scheduler that dispatches on app launch while the
machine is wide awake (David), and headless auth that expires (David again, 21 failures out of 21).

It also adds group F, which `V4-OPTIONS.md` had no equivalent of: **trust that graduates per skill on
recorded evidence**, so that reviewing every output is a starting state rather than the permanent one.

**v4 is an upgrade, not a re-adopt.** Eight people have customised their loop. Section 3 is the
contract that keeps their work.

**Updated 2026-09-09** with David Predusel's JTBD audit (KM-14493 comment 175153), which added rows
A5, A6, B6, B7 and E5 and corrected the substrate diagnosis in group A.

---

## 0. What this is, and what I am asking of you

This is a **change list for review, not a release.** Nothing here is built yet. I want the argument
checked before I write any code, because the last two releases each shipped something that was wrong
in a way one of you spotted in a day and I had not seen in a month.

**Read your own row first.** Section 5 says what changes for each of you specifically, including the
several cases where the answer is "nothing, and here is why that is deliberate."

**Updated 2026-09-24. Two things changed since this was first written, and they change what I am
asking for.**

**The four questions in section 6 are now answered.** I made the calls on 2026-09-24 and they are
recorded there in full, with the reasoning. The two that change the most for you:

- **Nothing auto-ships in v4.** Rung 2 is the ceiling and I am the gate on everything. Group F is out.
  Daniel Blam's argument, that a human pass belongs even on local-only work, is upheld.
- **The plan-drafting pattern is v4's one new capability.** 1 to 3 candidate plans plus the agent's
  own open questions, posted before a human looks, instead of one finished artifact.

**Your branches are merged.** `main` is at `b3f140c`: David's 8 commits, Andres's, and Maria's,
rebased in that order, 31 files, +1943 / -176. Section 3 promised v4 would not ship over the top of
your fixes and that promise is now kept rather than stated. Two conflicts needed a judgement call and
both are written up in MR 5, so **Andres and Maria, please check mine against yours**: I took David's
`find_workspace_root` probe over Andres's `parents[0]` fix in `notify.py`, because it handles all
three layouts and subsumes the standalone case, and I took David's `install-skills.sh` block over
Maria's manual copy table in the README, with a pointer added so the Windows runner stays findable.

**Xitong, your branch is the one thing still outstanding**: the three OpenCode failure classes and
your dev drafter. I am not holding v4 for it, so the OpenCode path ships known-unfixed unless it
arrives first.

**What I am asking for, by Friday 2026-10-02:**

1. Tell me if a row that cites your report **misstates it.** Nine of the 37 rows are attributed to
   something one of you wrote and I may have sharpened it past what you meant.
2. **Read the four rulings in section 6 and tell me if one of them breaks something for you.** They
   are decided, not open, but a ruling that makes your own loop worse is worth hearing about now
   rather than after it is built.
3. If a row is on the list and you think it is not worth doing, say so. I would rather cut three rows
   now than ship them and find out nobody wanted them.
4. **Write your own calibration target**, per job family, answering one question: *what would make me
   ship this without editing it?* Name a reader who is not you and what they do next. Mine is done and
   it changed the base rubric for everyone, because the old bar was "Tomek could ship it as-is", which
   is a person rather than a standard and is why engineer drafts were being failed for not sounding
   like me. Yours is not mine and I am not writing it for you.

**What I am not asking for:** adoption. Do not upgrade anything yet. I will run v4 on my own loop
first, get the unattended count off zero, and only then package it. **The order of the last three
releases was backwards** and it cost each of you a week.

**One thing I owe you before any of this.** Nine fix commits from David, a Windows `notify.py` port
from Maria, thirteen bug fixes from Andres, three OpenCode failure classes from Xitong and a `--model`
pin from Daniel Zhu are all real fixes to shared code that are **still not in the shared code.** Push
rights are now open on the repo. The first thing v4 delivers should be your own fix coming back to
you, and until that has happened the rest of this document is not worth reviewing.

---

## 1. The change table

Grouped by the constraint chain, in the order the constraints actually bind. Everything in group A
sits underneath everything else, which is why it goes first.

### Group A. Substrate: make the run happen when nobody is there

| # | What changes | Why | Where it came from |
|---|---|---|---|
| A1 | **The cloud routine becomes the default deliverer.** Local scheduler demoted to the internal-network post only (Mattermost, kaufmich.com), which is the one thing cloud cannot reach | **1 of 21** of Tomek's briefs landed within 15 minutes of the 07:52 fire; 19 of 21 landed 30+ minutes late, median about 70 minutes, one at 8h23m. That is the catch-up-on-wake signature, not a scheduled run. The only two clean unattended records in the squad both avoid this substrate: Chris 29 of 30 working days on a cloud routine, Daniel Blam 5 of 5 on Windows Task Scheduler | Receipt-lag measurement 2026-09-08. Chris (KM-14354 c8), Daniel Blam (c9). **The pattern was already written in our own `docs/RUN-AND-NOTIFY.md` and the package never defaulted to it** |
| A2 | **`schedule.substrate` stops being a closed list.** Accepts `cloud_routine`, `inapp_task` and a free-form string alongside the two local values | The enum is `local_launchd \| local_task_scheduler`, so **the config cannot represent either of the two setups that actually work.** David: *"my value is honest rather than valid"* | David Predusel (c13) |
| A3 | **Delete the `caffeinate -i` guidance.** Replace with mains power on weeknights plus `sudo pmset repeat wakeorpoweron MTWRF 07:50:00`, and say plainly that a laptop on battery is Assisted infrastructure | `-i` asserts PreventUserIdleSystemSleep and does not hold a launchd maintenance wake open. `-s` is documented AC-only. `-u` is untested and turns the display on. Three docs plus the adopt checklist read as a solved problem; `docs/RUN-AND-NOTIFY.md` already states the accurate version and the caffeinate note contradicts it | Daniel Zhu (c15, then corrected himself in c16), David correcting his own advice (c17). Daniel Zhu's fire: 08:01:23, froze, thawed on lid-open 12:11:03, **4h10m against a 30-minute watchdog** |
| A4 | **Watchdog default raised and made wall-clock aware.** A run that freezes with the machine must report `slept`, not `timeout` | The shipped 20-minute default left Daniel Zhu 45 seconds of margin with pre-drafting off. `sleep(1)` suspends with the machine, so the run and its own watchdog froze and thawed together | Daniel Zhu (c11, c15) |
| A5 | **`claude setup-token` becomes a required adopt step**, and the runner fails loudly with a named remedy when headless auth is absent | David's launchd path **failed 21 of 21 times between 31.07 and 20.08** with *"OAuth session expired and could not be refreshed"*, which is why he fell back to the in-app scheduler in the first place. This is the one genuine instance of the "login expired" class: on the PO loop the same string was a misclassification (a cumulative-log grep), here it is real. **It also means A1 to A4 cannot be applied on his machine until this is fixed** | David Predusel (KM-14493 c175153), archived at `archive/launchd-failures-2026-07-31_2026-08-20.log` |
| A6 | **The desktop app's in-app scheduled task is documented as NOT an unattended substrate.** `schedule.substrate: inapp_task` is accepted for honesty (A2) and warns that it cannot produce an unattended run | **This is a second and completely different failure from DarkWake, and it changes the diagnosis.** David's machine was up **6 days continuously** with `pmset -g log` recording **no Sleep/Wake transition** on any of four runs, so sleep cannot be the cause. The in-app scheduler dispatches **on app launch**: 09-07 fired 3s after app start, 09-08 fired 5s after. His words: **"a human-gated trigger wearing a cron expression."** `pmset repeat wakeorpoweron` does nothing for this case | David Predusel (c175153) |

### Group B. Discoverability: stop shipping features that are switched off

| # | What changes | Why | Where it came from |
|---|---|---|---|
| B1 | **Fix the permission-model drift.** Both shared templates still read `gated_at_morning_approval: [run_drafting_subagents]` while `morning.md` implements `ship_any_draft_externally`. Reconcile to v3's model | One line of drift is why two careful readers each concluded that using the headline feature meant loosening a permission ADOPT tells them not to touch. **It does not: Phase 2p references no `permissions.*` key at all.** Verified still live 2026-09-08, six days after it was reported | David (c13) |
| B2 | **`doctor.py` reports an absent `dispatch:` block as a visible gap**, warning not failure. A present-and-false block reads `off (explicit)` | Three adopters found the same missing switch by three routes: Daniel Zhu by reading source, David by running the clean-clone gate, Andres by living with it for eight days (*"it was never set so the pre-draft phase never ran once in 8 days"*). **A feature that is off on purpose is fine. A feature that is invisibly off is the bug** | Daniel Zhu asked for it (c14), David implemented it (c17), Andres is the independent confirmation (c12) |
| B3 | **Routing rules get an exact-name invocation contract.** A rule's `skill:` must be invoked by its literal name, never substituted for a topically related tool, even an already-connected one | Andres's Mattermost inbox digest never ran. The model reached for a connected Mattermost MCP instead, which lacks the read-pointer fields real unread-detection needs. **`doctor.py` cannot catch this: the failure is at invocation time, not resolution time.** The fixed 9 probes have a reads/must-return contract; config-driven rules have no equivalent anywhere | Andres Cagua (c7) |
| B4 | **`render: section` on a routing rule.** Default stays `bullet`, so no existing rule changes | Rich `bucket: auto` output was flattened into "Already done" one-liners. A 7-day hours grid became one sentence; a categorised email digest lost its categories. Andres's case for why it matters: if a digest surfaces 4 DMs needing different replies, *"4 need a reply"* means you go open Mattermost yourself, which defeats sensing it at all | Andres Cagua (c7), already working in his config (c12) |
| B8 | **The meeting-notes source becomes one CQL query, `ancestor = <root> AND type = page ORDER BY lastmodified DESC`.** No hardcoded sprint-block page id, no depth-1 child listing | **Verified live 2026-09-09 and it is a silent-empty-result bug of exactly the kind B2 exists to catch.** Both shared templates set `confluence_parent_page_id: "5481365612"`, but that page's direct children are season containers, a team roster and a template. **The meetings sit three levels down** (`5481365612` to `5784207365` Q3 Summer to `5783846996` Sprint 4-6 to the meeting pages). Worse, that sprint page's descendants come back ordered by `childPosition` and **paginated**: page one returns 2026-08-03 to 2026-08-20 with a `next` cursor, so a naive read builds today's brief from three-week-old meetings and reports no error. The CQL form returned `2026-09-09 Refinement` and `2026-09-09 Daily` first, crossed every season folder, and needs no page id that goes stale at the next boundary. **The PO config has no meeting source page id at all** | Tomek 2026-09-09; measured this session. Removes the same staleness class that forced two `decision_log.current_page_id` self-repairs |
| B5 | **Clean-clone gate becomes a release blocker**, and the release notes may only claim a fix that the gate confirms | Tomek's own clean-clone test found three bugs. David then ran it and found three more, plus four already fixed by a merge that he dropped rather than report as live: *"reporting fixed bugs as live would be this release's own failure mode"* | Tomek (ticket description), David (c13) |
| B6 | **`doctor.py` reports a declared signal type with no consuming routing rule.** Same treatment as an unresolvable skill: a visible gap | The config declares `metric_event` as a signal type and **no rule consumes it**, so experiment read-outs never fire even though the Amplitude MCP is reachable and the skill exists. It cost real accuracy: KM-13013's state *"went unverified in every run"* on 09-07 and 09-08. A signal with no consumer is coverage the config describes and does not have, which is the same disease as B2 | David Predusel (c175153) |
| B7 | **`delivery.channel: file` is reported as non-delivery, not as success.** The brief's own health check must treat `rendered_not_sent` as a miss with a named remedy | Three of David's four receipts read `"status": "rendered_not_sent", "sent_at": null, "channel": "file"`. **0 shipped of 9 drafted across 3 drafting days**, so every "carried Nx, still unanswered" line in his run log described a question that was never actually sent. His read, and it matches ours: *"a routing and permissions gap, not a drafting one, and it is worth more than any new drafter"* | David Predusel (c175153), whose own `rendered_not_sent` status made this visible (KM-14354 c13) |

### Group C. Grading: every person's bar, not Tomek's

| # | What changes | Why | Where it came from |
|---|---|---|---|
| C1 | **`calibration_target` moves out of `_base.rubric.yml` and into each person's own config** as `identity.calibration_target`, defined against their own JTBD | `_base.rubric.yml` sets `calibration_target: "Tomek could use/ship/share it as-is"` with a gate-severity check reading **"It reads as Tomek wrote it."** Six rubrics ship for 15 skills, so **every engineer draft fell back to `_base` and was graded on whether it sounded like the PO** | David (c13). Tomek's ruling 2026-09-08: each person defines ready-without-edit inside their own setup, against their own jobs |
| C2 | **Rubrics become an overlay.** Package rubrics plus a user rubrics dir; the user's version wins and the installer never overwrites it | David wrote 6 new rubrics. They have to survive every future upgrade or nobody writes the seventh |
| C3 | **Merge David's coverage:** per-skill rubrics go from 6 skills to 11 | Nothing graded `ticket-brief`, `ticket-quality-check`, `stall-escalation`, `attention-triage`, `backlog-analysis`. Those first three are the exact skills David's original complaint was about. **`team-standup` is the daily spine and the most-run drafter in the package and also had none** | David (c13) |
| C4 | **A rubric check may not fail a draft for an environment fault.** Unwritable path, unavailable MCP, absent VPN all grade `n/a` | Andres's `every-to-seen.md` dedup log was blocked at its git-tracked path for 6+ runs. David's new `team-standup` rubric required that log to be appended, so it would have failed a draft for a fault the drafter cannot control. *"Failing a draft for something the drafter cannot control is how a grader teaches people to ignore it"* | David (c17), off the back of Andres's infra note (c12) |
| C5 | **Harvest a golden from every artefact that ships.** Automatic, from the outbound ledger row | 8 rubrics exist and exactly **one check** was derived from evidence rather than belief. **Zero goldens have ever been kept.** This is nearly free and it is what makes every future rubric calibratable | `V4-OPTIONS.md` Option B |
| C6 | **Automate the draft-versus-posted pair analysis, propose-only.** Every edit made before shipping is a labelled error; every sentence left alone is a labelled success. Changes are proposed, a human applies, and the pairs are kept as a held-out regression set | It has run **twice, by hand, in eleven days** and produced the only evidence-derived checks in the repo. It is also the input group F needs: without a diff per ship there is no way to know whether a skill has earned more autonomy | `V4-OPTIONS.md` Option B |

### Group D. Trust and the reading burden

This group is the answer to the real problem: reading every output is draining, and the output has to
be trustworthy before it can be pushed, with awareness of what is going where and to whom.

| # | What changes | Why | Where it came from |
|---|---|---|---|
| D1 | **Verification tiers by blast radius.** Local-only drafts get a sampled audit (1 in N, plus anything the drafter self-flags). External actions keep two verifiers and the judge. Nothing loosens on the external path | Ready-without-edit is 5 of 23 stamped drafts on the PO loop. Total per-item verification does not scale, and it is the ceiling on how much work can be given away. **Xitong reached this independently from his own run data before v3 shipped:** *"gate matching blast radius"* | `V4-OPTIONS.md` Option B; Xitong Deng, quoted in c5 |
| D2 | **The outbound ledger becomes the read surface, not the drafts.** One line per send: what left, where it went, who sees it, and its verified state at the moment of sending | The stated need is awareness of what is being pushed, where, and to whom. That is a ledger question, not a draft-reading question. The ledger exists and has **10 rows, every one reading `verified: no`**, so today it answers "what left" and not "was it checked" | Tomek 2026-09-08; ledger audit in the KR rollup |
| D3 | **`unattended_run_rate` computed per person, per substrate, in the run log.** Measured as lag against the scheduled fire, not as delivery success. `unattended` means the artefact was produced and delivered within a grace window of the fire with no interactive session open. Report the lag histogram next to it | Delivery success said 20 of 27 weekdays, 74%, and it was measuring the wrong thing. Lag against the fire said 1 of 21. **The same artefacts, two numbers, and only the second one redirects the work.** David's version of this: *"it dispatched and it ran look identical in every artefact an adopter reads"* | This week's measurement; David (c13) |
| D4 | **`ready_without_edit_rate` computed per skill, per person**, graded against that person's own rubric and calibration target. Reported with its denominator, never as a bare percentage | The only quality signal with real data, currently unmeasurable for any non-PO role because of C1. Depends on C1 and C2 landing first | Tomek 2026-09-08; `V4-OPTIONS.md` Option B |
| D5 | **Shipping stays gated per item, and that is not a defect to be engineered away.** The loop stops counting an unshipped READY draft as a routing failure when the owner has declined it deliberately | Daniel Blam reached 5 of 5 scheduled fires with 2 verified predrafts every day and shipped **0** externally, on purpose: *"Local drafts are homework; a Jira or Mattermost post is a send. The gate stays."* His READY `poc_intake` sat local all week because he chose `n`. **That is a considered position, not a missed automation** | Daniel Blam (c9) |
| D6 | **Every claim in the brief carries a confidence marker, inline.** Four values, derived from the trust layer rather than self-assessed: `verified` (requeried live, with source and timestamp), `reported` (single source, not requeried), `inferred` (derived, no direct source), `carried` (from an earlier brief, not re-checked today) | The provenance header already answers "which parts do I need to read closely" **per draft**. The brief carries roughly 40 claims and gets one verdict, and on the first v3 run the gate was pointed at **3 of about 40**. Uniform presentation invites uniform trust, which is exactly what should not happen | Tomek 2026-09-09; the v3 gate-coverage lesson (KM-14354 c1) |
| D7 | **The brief opens with a one-line confidence census**, e.g. *"41 claims: 12 verified live, 22 reported, 3 inferred, 4 carried. 2 corrections registered, both applied."* | Turns "how much of this can I trust" from a reading task into a number at the top. It also makes the gate's coverage visible: a census showing 3 verified of 40 is self-indicting in a way that a passing verdict is not | Tomek 2026-09-09 |

### Group E. Contribution: the upgrade has to carry other people's fixes

| # | What changes | Why | Where it came from |
|---|---|---|---|
| E1 | **Grant push rights on branches, or enable forking, on `tomzduda/morning-loop`.** Do this before any code in this document | Daniel Zhu and David are both on push-to-create projects, so GitLab will not offer a cross-project MR until a fork relationship exists. David is holding 6 commits, 18 files, 911 insertions, 6 new rubrics. Daniel Zhu's client port made it in; David's cannot. **Maria's Windows `notify.py` port, Andres's 13 bugs and Xitong's 3 OpenCode failure classes are still not in the shared code.** This is an access problem costing more than any missing feature, and it is a precondition for section 3 | Daniel Zhu (c11), David (c13) |
| E2 | **User-owned rules move to their own file**, `rules.local.yml`, gitignored, which the installer never reads or writes. Package-owned rules stay in the template | This is the structural move that makes an upgrade additive instead of a blank slate. See section 3 | Xitong's *"it is easy to half-adopt"* (c5); Andres's three personal tools (c7, c12); Xitong's own dev drafter |
| E3 | **`doctor.py` root resolution fixed**, plus the dead else-branch in `notify.py`, plus receipts landing where the config's `paths` point | `repo_root()` walks to the first `.git`, which for a package cloned inside a workspace is the package clone. Upstream's doctor prints `8 things cannot run` against a correct install and tells you to write skills that already ship. **The tool whose thesis is "stop describing coverage you do not have" was the thing describing it wrongly.** `notify.py`'s else-branch is unreachable because the package ships a config at its own root, so artefacts land inside the clone where the health check cannot look | David (c13) |
| E4 | **Ceremony capture stays excluded until it has a rubric.** Squad ceremonies belong to the Scrum Master; the loop reads those pages and does not write a second record | Carried forward from the v3 ruling. A second unofficial record of a ceremony someone else owns creates two sources of truth and ours is the weaker one | Maria Sommer (c2, c3), Tomek's ruling (c4) |
| E5 | **Personal hook and skill wiring moves out of gitignored local state into a committed, shared location.** The package ships a `hooks/` directory and an install step for it | David's two AUTOMATED jobs are both personal hook wiring under `.claude/`, which is gitignored (`kaufmich2/.gitignore:100-101`), so **he argues his own strict floor down to 0 of 11** on test (b): *"every skill, hook and scheduler I have is local state no colleague can pick up."* He has **40 skills in `.claude/skills/` and every one waits for him to type something.** This is structural, not personal: **gitignored automation can never clear the L2 bar, whoever writes it** | David Predusel (c175153) |

### Group F. Earned autonomy: trust that graduates, per skill

The model is an employee's, and it is the one thing on this list that does not exist in any form today.
You approve the work, you check whether edits were needed, and when a skill stops needing them it earns
the right to ship without you looking first. Group F is the mechanism for that, and it is why C5 and C6
are prerequisites rather than nice-to-haves: **without a recorded diff per ship there is no evidence a
skill has earned anything.**

| # | What changes | Why | Where it came from |
|---|---|---|---|
| F1 | **Every ship records the diff between the stamped draft and what actually left.** Same mechanism as the golden harvest (C5), one artefact, two uses | The measurement the ladder runs on. Today the outbound ledger records *that* something shipped and nothing about whether it needed rewriting first | Tomek 2026-09-09; C5, C6 |
| F2 | **A per-skill trust ladder, driven by consecutive edit-free ships.** Rung 1 (0 to 2): every item reviewed before it leaves, which is today. Rung 2 (3 to 5): still reviewed, but pre-approved for local-only destinations. Rung 3 (6+): auto-ships to a named low-blast-radius destination and appears in the ledger for post-hoc review, reversible | **Trust should be evidence, not a setting.** It also gives `ready_without_edit_rate` (D4) something to do beyond being reported: the metric becomes the thing that moves the rung | Tomek 2026-09-09 |
| F3 | **Demotion is immediate and asymmetric.** Any edit on a ship drops that skill one rung at once. Earned over six ships, lost on one | A ladder that only climbs is a setting with extra steps. Asymmetry is what makes rung 3 safe enough to allow at all |  Tomek 2026-09-09 |
| F4 | **A permanent ceiling on the external and leadership-facing path.** Anything going to the Growth Circle, Christoph, André or a customer-facing surface stays at two verifiers plus the judge plus an explicit yes, for ever, regardless of rung | The v3 run where the voice verifier passed 17 of 17 and the structure verifier found three block-severity failures, including a ticket described as unowned that was assigned to Tomek and a wrong claim about an Apple rejection. **One verifier would have shipped it to Christoph and André.** No amount of good history should be allowed to buy past that gate | Tomek's own v3 run log (KM-14354 c1) |
| F5 | **The rung is per skill and per person, never global.** Maria's sprint-close report earning rung 3 says nothing about her refinement-candidates prompt | Three of Maria's routines fired on schedule and wrote a wrong verdict every week for a month while three others were fine. Skill-level history is the only granularity the evidence supports | Maria Sommer (KM-14493 c174382) |

---

## 2. What is deliberately not in v4

- **New drafter skills.** Coverage is not the constraint. 15 packaged skills, 26 installed, and the
  most-run one had no rubric.
- **The big multi-agent build.** Orchestration is the part that already works. Twenty agents on
  today's verification model produce twenty times the reading. This becomes obvious the moment
  group D is real and is expensive before then.
- **Removing anyone's ship gate.** See D5.
- **A self-rewriting loop.** The meta loop stays propose-only, with the draft-versus-posted pairs held
  out as a regression set.

---

## 3. How the upgrade lands on top of a customised loop

The question that matters, because eight people have already bent this thing to their own work and a
v4 that hands them a fresh template would throw that away and be ignored.

### The rule: the config is theirs, the package is ours

Every v4 change is designed against four constraints.

**1. Additive schema only. Every new key has a default that reproduces v3.1 behaviour exactly.**
An un-migrated config keeps working and keeps its current results. Nobody is forced to touch anything
to stay where they are. This is what makes it safe to ship, and it is the opposite of the `dispatch:`
mistake, where the absence of a key silently turned the headline feature off.

**2. Two files, two owners.**

```
agent-manager-config.<you>.yml   package-owned shape, migrated in place, comments preserved
rules.local.yml                  yours: your tools, your routing rules, your render choices
                                 gitignored, and the installer never reads or writes it
rubrics/                          package rubrics
rubrics.local/                    yours, overlaid on top, yours wins
```

Andres's timesheet, email digest and Mattermost rules, and Xitong's dev drafter, live in
`rules.local.yml` and survive every upgrade from here. Today they live in a file the installer backs
up and rewrites, which is why upgrading feels like starting over.

**3. Migrate, never re-template.** `scripts/migrate-to-v4.py` reads the config you already have,
works out which v4 keys are absent, and writes only those, with their comments, leaving every rule you
authored untouched. It runs `--dry-run` first and prints the diff it would apply. It never deletes a
key it does not recognise, because an unrecognised key is probably someone's good idea.

What it will print, for a v3.1 config:

```
migrate-to-v4 --dry-run
  + schedule.substrate         local_launchd  ->  keep (now also accepts cloud_routine, inapp_task)
  + schedule.grace_minutes     20             (new: the window that defines an unattended run)
  + identity.calibration_target  UNSET        (new, and you must set it: see C1)
  ~ permissions.gated_at_morning_approval
        run_drafting_subagents  ->  ship_any_draft_externally   (fixes B1; ask before applying)
  + metrics.unattended_run_rate      on
  + metrics.ready_without_edit_rate  on
  = 14 routing rules       untouched
  = rules.local.yml        not read
  nothing written. re-run without --dry-run to apply.
```

**4. One key is deliberately left blank and blocks nothing.** `identity.calibration_target` ships
`UNSET`, and until it is set that person's drafts grade against `_base` **minus** the voice checks,
rather than against the PO's voice. A missing calibration target must never silently mean "grade this
like Tomek's writing", which is what it has meant until now.

### Migration order, and it matters

1. **E1, push rights.** Before anything. Otherwise the upgrade ships without four people's fixes and
   they get to watch their own work be overwritten a second time.
2. **Merge the outstanding branches**, David's and the rest, and run the clean-clone gate on the
   result. The first thing v4 delivers to an adopter should be **their own fix, coming back to them
   in the package.** That is the entire difference between an upgrade and a re-adopt.
3. **B1, B2, E3.** The one-line drift, the visible `dispatch:` gap, the doctor root. Small, and they
   are the reason the last release did not reach anyone.
4. **A1 to A6, per person, one at a time.** Substrate is individual and there is no single fix: Chris
   needs nothing, Daniel Blam needs nothing, Daniel Zhu needs a real wake schedule or mains power,
   David needs `claude setup-token` **first** (A5) because his launchd path cannot authenticate at all,
   and then to leave the in-app scheduler behind (A6). Diagnose before prescribing: a machine up for
   six days with no sleep transitions is not a DarkWake case.
5. **C1 to C4.** Then, and only then, D3 and D4 produce numbers that mean anything.
6. **D1, D2, D5 to D7.** The reading burden, because it needs the metrics to tier against.
7. **C5, C6, then group F.** Last, and in that order: the ladder cannot run before there is a recorded
   diff per ship to run it on.

### The five-minute version, for anyone already running v3.1

```bash
git pull
python3 scripts/migrate-to-v4.py --dry-run     # read the diff
python3 scripts/migrate-to-v4.py               # apply
python3 scripts/doctor.py                      # must exit 0
# then set identity.calibration_target in your own config, in your own words
```

Your rules are not touched. Your rubrics are not touched. If the doctor flags something you cannot fix
today, comment the rule out, because a commented rule is a visible gap and an active rule pointing at
nothing is an invisible one.

---

## 4. How this moves the squad toward automations that actually work

**Where we are, honestly.** Ten people have posted an audited automation number and the squad sums to
**41 of 123, 33.3%**, against an 80% per-person target, with **1 of 10 people passing.** Against the KR's real L2
bar, one tool clears it and it is not the loop. And the loop's own closing criterion, five scheduled
runs producing a verified artefact, reads **0 of 5** for the author and for the two adopters who
measured it properly.

That is not the whole picture though, and the rest of it is the reason this release is worth shipping.

**What v4 actually changes, in order of how much it matters.**

**It moves the count off zero, and for a reason rather than by luck.** Every 0-of-5 in this thread
fails at the trigger and not in the loop's logic, and David's audit shows it is three separate causes
wearing one symptom: a sleeping machine, a scheduler that fires on app launch, and headless auth that
never worked. The two people with clean records, Chris at 29 of 30 and Daniel Blam at 5 of 5, are not
better at this. They are on a substrate that fires. Group A is the whole of that, it is mostly
configuration rather than code, and it is the difference between an automation and a thing that runs
when you open your laptop. **Nothing else on this list can be measured until it lands.**

**And the drafting it gates is already good enough to be worth gating.** David graded his own brief at
**8 of 10**: 8,104 words, 27 KM tickets, 15 comment ids, and five load-bearing claims independently
re-verified as exact. That is a dev-role output from a package whose rubrics were calibrated to the
PO's voice. His job 10 fails test (a) and nothing else. **The drafters are not the problem, which is
the most useful thing in his audit.**

**It makes trust something a skill earns rather than something you grant.** Today every output gets the
same read because nothing distinguishes them. Group D marks each claim's confidence and group F lets a
skill graduate out of pre-review on six consecutive edit-free ships, dropping a rung the moment one
needs an edit. That is how a reviewer's job shrinks without anyone lowering a standard.

**It makes the reading burden shrink instead of grow.** Today more automation means more output means
more reading, which is why more automation has stopped feeling like progress. Group D breaks that: a
sampled audit on local drafts, two verifiers on anything that leaves, and the ledger as the surface
that answers what went out, where, and to whom. **The point is not to read less carefully. It is to
read the one page that says what left your name, instead of six drafts that mostly will not.**

**It makes the quality bar belong to each person.** Until now a dev's draft was graded on whether it
read like the PO's writing. That is why "quality 7 or better" has been a vibe for six of nine people,
and it is why the one person with real measurement scores lowest. Ready-without-edit only becomes a
usable number once each person has defined it against their own jobs, which is C1, and it is the number
that tells you whether an automation can be trusted at all.

**It converts the squad's best behaviour into the release mechanism.** The most valuable thing in the
KM-14354 thread is not any fix. It is that Daniel Zhu corrected himself twice in ten minutes, David
corrected himself and the advice he had given, and dropped four findings because a merge had fixed
them rather than report them as live. Three people found the same invisible switch by three different
routes. **That is a squad that can be trusted with autonomy, and the KR has no way to score it.**
Section 3's migration contract and the clean-clone release gate are how that behaviour becomes the
process instead of a happy accident.

**And it stops throwing away the customisation.** Eight loops exist because eight people made this
theirs. The single biggest risk to v4 is that it reads as "start again", so `rules.local.yml`, the
rubric overlay and a migration that prints its diff before touching anything are not conveniences.
They are the adoption strategy.

**What it does not fix, stated plainly.** v4 does not get the KR to 80%, and the KR will not be met as
written. It also does not make anyone's automation clear the L2 bar, because that needs a second person
using someone else's tool unaided and every adopter so far has answered "needed the author: yes."
What v4 does is remove the reasons the number is stuck, so that the next measurement means something.

---

## 5. What changes for you

| You | What changes | What does not, and why |
|---|---|---|
| **Chris Gamrot** | Very little, and that is the finding. Your cloud routine at 29 of 30 working days is the **best-performing automation in the squad** and A1 makes your substrate the package default rather than the exception. I owe you an answer on your ruling #1 question about the CA link-click write-up, and it is coming with the audit rulings | You were right to stay off the package while it needed a local scheduler, and right to skip parallel sensing. Neither is on your list. **Your loop is the reference implementation for group A, not a candidate for group A** |
| **Daniel Blam** | B7 stops the loop calling your unshipped READY drafts a routing failure, and D5 writes your position into the design: local drafts are homework, a post is a send, and the gate stays | **Nothing removes your ship gate.** You reached 5 of 5 scheduled fires with 2 verified predrafts a day and shipped 0 on purpose. That is a considered position and D5 exists to protect it. Group F is opt-in per skill and you can leave every skill on rung 1 for ever |
| **Maria Sommer** | Your Windows `notify.py` port and `routine_health` go upstream (E1). C4 fixes the class of grader bug your Windows environment would have hit. F5 comes directly from your evidence: three of your routines fired and wrote a wrong verdict weekly while three others were fine, so trust has to be per skill | E4 stands: **the squad ceremonies are yours.** The loop reads your pages and writes no second record. B8 changes only how it *finds* them |
| **Xitong Deng** | D1 is your ask, landing at last: *"gate matching blast radius."* You reached v3's central change independently from your own run data before v3 shipped. E2 means your dev drafter lives in a file the installer never touches, so it stops being backed-up-and-overwritten on every upgrade | Your three OpenCode failure classes go upstream rather than being re-solved. Your drafter is not replaced by a package one |
| **Andres Cagua** | B4 (`render: section`) and B3 (exact-name invocation) are both yours, and B4 already works in your config. E2 protects your timesheet, email digest, Mattermost inbox and Confluence-checkbox rules permanently. B6 is the class of bug behind your `metric_event` observation | Your 13 fixes go upstream. Your ASK-bucket criticism is **unresolved and I have not pretended otherwise**, see question 3 in section 6 |
| **Daniel Zhu** | A3 and A4 are yours, and I am taking the accurate version rather than the flattering one: `-i` is insufficient, `-u` is an untested candidate, and mains plus a real wake schedule is the honest answer. Your client port is already merged. Your health-check pattern is on my own adopt list | Your plan-drafting chain is not touched by this release and does not need to be. It is the **only world-class-shaped automation in the squad** and section 6 question 4 asks whether it should travel |
| **David Predusel** | The most rows of anyone: A5, A6, B6, B7, E5, plus E3 and C3 which are your commits. A5 comes first on your machine because nothing else can be applied until headless auth works. Your six new rubrics take per-skill coverage from 6 skills to 11 | Nothing asks you to abandon the in-app scheduler until A5 gives you a working alternative. A6 documents it honestly rather than dropping support |
| **Jasmine Zhang** | A1 and D3 matter most to you: your 07:00 daily task still reads `LastRun=never` and every fire so far has been the logon catch-up. D3 is the metric that makes that visible instead of looking like a delivered brief | Your denominator is 4 jobs and nothing here inflates it. The audit rulings will settle whether daily sense and time-split are new jobs or replacements |
| **Sascha Bücher, BeXx Jacombs-Doll** | Nothing yet, deliberately. You are the two outstanding registers and a v4 change list is the wrong thing to hand you first | The useful step is the audit itself, or in BeXx's case a first capture. I will come to you separately rather than route it through this document |

---

## 6. The four calls I do not want to make alone

> **ANSWERED BY TOMEK, 2026-09-24.** Recorded verbatim in intent below each question. These are
> rulings, not opinions: they change what v4 contains.
>
> **1. Rung 3 is not allowed. Rung 2 is the ceiling.** *"I don't want auto shipping yet, I want to
> still be able to review the documents that you create... I am the final gate to decide what goes and
> what doesn't go forward, because I am ultimately responsible for what the team is working on and
> why."* Group F comes out of v4. Daniel Blam's counter, that a human pass belongs even on local-only
> work, is upheld.
>
> **The named re-open condition:** *"only once I will go through a lot of reviews and have nothing to
> improve, comment or correct will we start thinking about shipping from your output, at least for a
> while to test how it works."* That is a promotion rule built on positive evidence, a run of reviews
> with no corrections, rather than on the absence of complaint. It is the rule the autonomy assessment
> asked for, specified by the person who would be the one harmed by getting it wrong.
>
> **The consequence for what gets built.** With auto-ship off the table and 86 unshipped drafts on
> disk, **the review is the bottleneck and the scaling has to come from making each review cheaper,
> not from removing reviews.** The number to watch stops being "what did the loop ship" and becomes
> "how long did the review queue take". Tomek's stated fear is the design brief: *"my biggest fear is
> that my vision and scope becomes desynchronized with what you ship"*, and the slop-grenade framing,
> Tobi Lütke's, is the sharpest statement of the risk in this workspace: output that looks finished
> but is not, which explodes into work for whoever receives it. The provenance header is an
> anti-slop-grenade device and should be argued for on those grounds.
>
> **What he says the loop is for**, which belongs in any register that adopts it: keep him on top of
> current work and unblock the team; review past work through data, quantitative and qualitative, and
> propose the user research that would close the gaps; plan the future through research, goals,
> learnings and ideas that move the goals.
>
> **2. The permanent ceiling is wider than the PO list.** *"the company founders, the 3 brothers who
> have founded the company and are sole owners... Also there are our users."* So: **anything that
> reaches an owner, and anything a user can see.** That pulls in surfaces that could reach the
> brothers second-hand, not only the ones addressed to them. Note this is still a PO's list: it does
> not name a production deploy, a merge to `main`, or a Zendesk reply, and each adopting register must
> add its own. That was the point of asking.
>
> **3. Keep the ASK bucket, but make it optional per adopter.** Tomek: *"yes, although I often don't
> respond to it, it does give me some thinking points and I might have an idea or an answer later on."*
> Andres and Chris are right about their own registers and wrong about his, so the type stays for the
> PO register and is opt-out elsewhere. The follow-on defect is capture, not the bucket: *"they likely
> never reach you in the context of my comment or answer to the morning brief."*
>
> **4. Yes, the plan-drafting pattern becomes v4's one new capability.** It is not a token
> optimisation, which was the first reading. It changes the shape of what reaches the reviewer: **candidate options plus the agent's own open
> questions, posted before anyone looks**, instead of one finished artifact. **Updated 2026-09-25
> from Daniel's packaged version, whose rule is better than the "1 to 3" written here:** options
> appear ONLY where the candidate answers change the outcome in materially different ways. Where
> there is one defensible answer there is no options list, the agent states the answer it would take
> and the question becomes a confirmation. A clean run gets ZERO questions. The count is bounded by
> the blocker test, never by a quota. Three reasons it is the right single addition given ruling 1:
>
> - It is the structural opposite of a slop grenade. A grenade hides its unfinished thinking; a plan
>   set that carries its own open questions declares where the thinking stops, so the review is
>   bounded and visible.
> - It attacks the scope-desync fear at the cheap end. One plan hides the direction the agent chose.
>   Three plans surface it, so a correction costs a sentence at the plan stage instead of a rewrite at
>   the artifact stage.
> - It makes "review one by one" survivable at volume. Picking between A and B and answering two named
>   questions is seconds. Reviewing a finished document is unbounded.
>
> **Scope it.** Apply it where direction is genuinely contested: the GC framing, the sprint goal, the
> refinement agenda, anything strategy-shaped. Not to jobs with one obvious shape such as attention
> triage or stale escalation, where three candidate plans would be theatre. Cost honesty: it is more
> tokens up front and is only net cheaper if it prevents wrong artifacts, which is untested.
>
> Tomek was already on the receiving end of the pattern: on 2026-09-07 Daniel Zhu's agent posted the
> KM-14449 spike result as two options with the trade-off written, and asked him and David to pick.
> He picked a letter rather than reviewing a document.

### The questions as originally put


1. **Is rung 3 allowed at all?** Group F ends with a skill auto-shipping to a named destination after
   six consecutive edit-free ships, reviewable afterwards in the ledger and reversible. The
   alternative is that rung 2 is the ceiling and a human always looks first. **I lean toward allowing
   it for a short named list of low-blast-radius destinations and nothing else**, but Daniel Blam's
   argument that a human pass belongs even on local-only work is the strongest counter and I have not
   answered it.
2. **What sits on the permanent ceiling (F4)?** My list is the Growth Circle, Christoph, André and any
   customer-facing surface. That is a PO's list. Tell me what belongs on yours: a production deploy
   gate, a merge to `main`, a Zendesk reply to a real user, a forum post under the KM name.
3. **Is the ASK bucket worth keeping?** Andres: *"the ask bucket is the weakest part for me, it does
   not clearly save time over just working through the list at the interactive gate myself."* Chris ran
   21 runs with zero ASKs because the type is PO-shaped. **Two independent signals that a whole
   finding type may not earn its place.** I would rather cut it than defend it.
4. **Should Daniel Zhu's plan-drafting pattern travel?** It writes **1 to 3 candidate plans plus its
   own open questions** and posts them before a human looks. That is not the task done unattended, it
   is the task done better than a person under time pressure does it, because a person writes one plan
   and does not list what they are unsure about. It is not in this release. My read is that it
   generalises to nearly every register in this squad and should be v4's one new capability. Daniel,
   it is your call whether you want it packaged.

---

## 7. The season question

The KR asked how many jobs each person had automated. It got nine honest numbers and three separate
people rediscovering one missing config key, because a per-person count cannot see a shared structural
failure.

**A better test to carry into the next season:**

> **Which of our automations would survive their author being on holiday for two weeks?**

It is the L2 bar in a form people can act on. It is measurable without a self-report, because either
the artefacts kept appearing or they did not. It rewards the two things this release is actually about,
reliability and handover, and it cannot be passed by counting jobs or by shrinking a denominator.

Two of them would pass today. Chris's CM daily loop at 29 of 30 working days, and Daniel Blam's
scheduled prep at 5 of 5, both because they run on a substrate that does not need their laptop open.
Neither scores a single point against KR 3.2.

---

## What would change this document

- **If a cloud-default run does not raise the unattended rate**, group A is wrong and the constraint is
  somewhere we have not looked.
- **If ready-without-edit stays low after each person sets their own calibration target**, the problem
  is drafter quality rather than a mis-set bar, and group C bought nothing.
- **If nobody edits `rules.local.yml`**, the customisation this release protects was not real and the
  file is dead weight.
- **If a second person runs someone else's drafter unaided**, the squad loop moves up the list and
  group E was the whole game.

Each is readable from the run log. None needs a judgement call about how it feels.

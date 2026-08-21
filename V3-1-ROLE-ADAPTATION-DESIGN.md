# v3.1: role adaptation, contribution, and where the self-improvement actually lives

> **Status: the packaging fix described below SHIPPED in v3.1 on 2026-08-21.** The package now ships `skills/<name>/SKILL.md` directories plus `commands/` and `rubrics/`, and `scripts/doctor.py` validates all of it. Read this for the reasoning; read `V3-1-WHATS-NEW.md` for what actually shipped.


**Written 2026-08-21.** A design proposal, not a shipped release. Three questions: should the loop mould itself to each role, is that feasible, and where is the compounding loop.

---

## First, the finding that changes the question

Three developers independently reported that the dev drafters never ran. Daniel Zhu: *"the skills referenced in `agent-manager-config.engineer.yml` aren't installed in my environment."* Xitong: *"a local dev drafter I had to write myself. The package ships no engineer drafter at all."* David: *"I cannot review ticket-brief / ticket-quality-check / stall-escalation at all."*

**That is not a role-understanding gap. It is a packaging bug, and it is one line to describe.**

Skills load from exactly two places: `<repo>/.claude/skills/<name>/SKILL.md` or `~/.claude/skills/<name>/SKILL.md`, each needing a directory and frontmatter. The shared package ships them as **flat files in `morning-loop-share/skills/`**, which is not a load path:

```
morning-loop-share/skills/ticket-brief.md            <- can never load
.claude/skills/ticket-brief/SKILL.md                 <- what actually loads
```

On Tomek's machine the drafters are in `.claude/skills/`, so they work. An adopter who clones the package gets a config that names skills which cannot resolve, **and nothing anywhere checks.** Xitong described the symptom precisely: *"it's easy to half-adopt. I had a working config, drafts, and run-log, but `/morning` itself didn't work because the command files were never copied. Nothing in the flow catches this."*

**So the single highest-value change here is not adaptation, it is validation.** Fix the packaging and three developers get their drafters today, with no new intelligence involved.

---

## What role adaptation should and should not do

Worth separating, because one half is cheap and reliable and the other half is a trap.

| | Verdict |
|---|---|
| Detect the adopter's role and propose a config from it | **Do it.** Cheap, and the mechanism already exists |
| Validate that every skill the config names actually resolves | **Do it first.** This is the real bug |
| Detect which tools and MCPs are present and narrow the config to them | **Do it.** David lost twelve runs to an auth dependency the loop could have flagged on day one |
| Wire an adopter's existing personal tools into the loop | **Do it.** Andres is offering two right now and there is no way to accept them |
| **Have the loop write new drafter skills for a role it has never seen** | **Do not.** See the ceiling below |

### The ceiling, stated plainly

A drafter is only trustworthy because it has a **rubric**, and a rubric is only calibrated because it has **goldens** — real examples of good output. A golden cannot be synthesised. It has to be a thing a competent human actually shipped and was happy with.

So the loop can wire itself up, narrow itself to the tools present, and adapt its routing. **It cannot invent a role's quality bar.** If it generates a CM drafter with no golden and no rubric, the output is confident and ungraded, which is the seventy-personal-scripts problem at machine speed.

This is the same conclusion the KR assessment reached from the other direction: the L2 reusability bar and the world-class bar are the same problem. **A job is handoverable exactly when it carries an explicit, gradeable standard.**

---

## The onboarding flow

Five steps. Steps 1 to 3 are mechanical, step 4 uses an existing skill, step 5 is the honest handoff.

**1. Validate the environment before anything else.**
For every routing rule in the config, resolve its named skill against the two real load paths. For every MCP the rules depend on, run the cheapest read. Then print a table that distinguishes three states that currently look identical:

```
ticket-brief          skill: NOT LOADABLE (found at morning-loop-share/skills/ticket-brief.md,
                             needs .claude/skills/ticket-brief/SKILL.md)   -> rule disabled
stall-escalation      skill: ok        Atlassian: ok                        -> rule active
attention_triage      skill: ok        Microsoft 365: NOT AUTHENTICATED     -> rule disabled, reason recorded
```

**A rule whose skill cannot load is disabled with a reason, never left silently in the config.** That is the whole of Daniel Zhu's and David's reported failure.

**2. Install skills to a load path, and verify the install.**
The package should ship `skills/<name>/SKILL.md` directories and an installer that copies them into `~/.claude/skills/`, then re-runs step 1 and refuses to report success until the names resolve. Verify by resolution, not by the copy command exiting zero, which is the same rule the loop already applies to brief delivery.

**3. Detect what the environment says about the role.**
Read what is already there rather than asking first: the repo's `CLAUDE.md`, the adopter's memory directory, their recent files, their connected MCPs, and their assigned tickets. Infer a role and a shortlist of recurring jobs. **Propose, never assume** — print the inference and let them correct it.

**4. Interview for the gaps, using the skill that already does this.**
`jtbd-capture` already mines exactly these sources, interviews for what it cannot find, grades each job by honest automation level and reusability, and is explicitly role-agnostic. It is already written and already used. What it does **not** do today is emit a config. That is the missing wire:

```
jtbd-capture output  ->  routing rules  ->  validated against step 1  ->  agent-manager-config.<user>.yml
```

Each job becomes a candidate rule with its signal, its bucket, and its external action. Jobs with no skill available are written into the config **commented out with the reason**, so the gap is visible instead of silent.

**5. Report the coverage honestly, per job.**
End onboarding with the one thing no adopter has had: a straight answer about what the loop will and will not do for them.

```
Your 14 jobs: 4 have a drafter that loads. 2 need a skill nobody has written.
8 are keep-human.
Nothing in this config will run unattended until you have one clean scheduled run.
```

Chris wrote *"My JTBD has 14 automatable jobs; exactly 1 is automated"* by hand. The loop should say that itself, on day one, before anyone spends a week finding out.

---

## The missing half: a contribution path

This is the part the question did not ask about and it may matter more than the onboarding.

**Three role-specific drafters already exist and work. None of them can be adopted by anyone.**

| What exists | Who built it | Evidence it works | Can anyone else use it? |
|---|---|---|---|
| A dev `ticket-brief` drafter | Xitong Deng | *"Best job: ticket-brief caught context traps immediately"*, 3 of 4 first-pass READY | **No.** It lives in his config |
| A full CM daily loop | Chris Gamrot | **21 of 21 working days unattended, zero misses** — the best-performing automation in the squad | **No.** Sole operator, by design |
| `ac-timesheet`, `ac-email-digest` | Andres Cagua | In use; **he is actively offering them** in his claude-tools repo | **Not yet.** There is no path to accept them |

So the loop does not need to learn what a developer does. **A developer already solved it and the solution cannot travel.** The pattern across every adopter is the same: the person who needed a drafter wrote one, it works, and it stays on their machine.

What a contribution path needs, minimally:

1. **A place to submit**: `skills/<name>/SKILL.md` plus a rubric plus at least one golden. The golden is the price of entry, because it is what makes the thing gradeable by someone who did not write it.
2. **A validation run**: install it in a clean environment, run it, grade its output against its own rubric. If it cannot pass its own rubric in a fresh environment, it is not ready to hand over.
3. **An adoption record**: who ran it, when, and whether they needed help from the author. That is the L2 bar, and the workflow playbook currently **has no field that can hold it** — every one of its ~70 entries is "added by {self}".

Against the KR this is the difference between one passing automation and four.

---

## Where the self-improvement actually lives

There are three loops at three timescales. Two exist. The middle one is the leverage and it is running by hand.

### Loop 1, per run: verify → revise → label

**Exists and works.** Rubrics grade check by check, an independent verifier never sees the drafter, one revision round, then READY or NEEDS-EDIT. Xitong's data from someone else's machine: 3 of 4 first-pass READY, one revision to 9/10.

**What it does:** gates today's output.
**What it does not do:** make the skill better. A skill that fails the same check every day keeps failing it and keeps getting revised.

### Loop 2, per shipped artifact: the draft-versus-posted pair

**This is the self-improving loop, and it is the highest-leverage mechanism in the whole system.** When a draft ships, the difference between what the loop wrote and what you actually posted is a set of labelled errors. Every sentence you left alone is a labelled success.

It has run **twice** (2026-08-10, 2026-08-20) and produced two real changes: the `matches_target_structure` check, and the pipeline-deltas rule. **Both caught repeat failures that no a-priori rubric had noticed.** Of every check in the repo, exactly one was derived from measured evidence rather than belief, and it is the one that keeps earning its place.

**And it is entirely manual.** Two analyses in eleven days, both done by hand. That is the Karpathy point applied to this loop: if there is an objective signal, the human should not be the one running the experiments.

**How to automate it:**

- **Trigger:** when an item is shipped at the gate, record the draft. On the next run, fetch the posted version and diff by section.
- **Classify** each difference into the four types the eval README already defines: agent was wrong, agent was blind, taste, changed-your-mind. **The A-versus-B distinction is the whole method** and it is where a naive automation will go wrong: a missing number looks like "not available to the agent" and is often "the agent never went looking because its structure had no slot for it".
- **Propose one change**, not three, so you can tell which one worked.
- **Apply with a human yes.** A loop that rewrites its own rubrics unattended drifts, and the pairs are also the regression set that catches a prompt change fixing one thing and breaking another.
- **Harvest the golden.** Every artifact you ship is a golden for its skill, and none are being collected. This is nearly free and it is what makes every future rubric calibratable.

### Loop 3, per week: adopter feedback and failure harvest

**Exists as a skill, and is 28 days overdue** by Daniel Zhu's count against a 7-day cadence.

Two things it should collect and currently does not:

- **Failure classes as labelled data.** Xitong has found three distinct OpenCode failure modes with verified fixes. Andres found thirteen bugs across two sessions. Maria ported the notifier to Windows. Every one of those is a labelled defect about the shared package, and every one lives in a Jira comment rather than in the package.
- **Their metrics, not their prose.** Ready-without-edit rate, unattended-run count, drafted-but-never-shipped. Adopters are already computing these by hand in their report-backs. The loop should read them.

### And the outer loop: which of the three to invest in

That is what the four run-log numbers are for, and it is the part that stops this becoming self-improvement theatre:

| Number | Points at |
|---|---|
| Ready-without-edit rate | Loop 2. The drafters need work |
| Claims killed at the finding gate | Loop 1. The probes assert what they cannot ground |
| Pre-drafted but never shipped | The routing rules. The loop is aimed at work nobody wants |
| Unattended runs completed | The runner. Nothing else matters until this is non-zero |

---

## Sequence, cheapest and most load-bearing first

1. **Fix the packaging and add config validation** (step 1 and 2 above). Mechanical. Unblocks three developers who have been reporting the same thing for a month.
2. **Finish the run #30 fixes**: verify per item, update the brief per item, report watchdog kills. Without these, pre-drafting produces ungraded work and the acceptance criterion cannot be met.
3. **Wire `jtbd-capture` to emit a config.** The skill exists; the wire does not.
4. **Open the contribution path** and accept Andres's two tools as the first test of it. That is also the fastest route to a second and third passing automation against the L2 KR.
5. **Automate the pair analysis**, propose-only, human applies. Start by harvesting goldens from everything already shipped.
6. **Run the overdue feedback round**, and make it collect metrics and failure classes rather than impressions.

**One judgement worth stating.** Role adaptation is genuinely worth building, and it is item 3 rather than item 1 because the reported failures were not caused by the loop misunderstanding anyone's role. They were caused by skills in the wrong folder, a runner that assumed one platform, and drafts nobody had time to ship. Adaptation on top of those would have adapted beautifully and still produced nothing.

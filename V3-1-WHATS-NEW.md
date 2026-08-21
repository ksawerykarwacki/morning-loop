# Morning loop v3.1 — adopt it to your role, and contribute back

**2026-08-21.** v3.1 is a small release with one large finding behind it.

**The finding:** three developers reported that the loop's dev drafters never ran. They were all right, and the cause was neither their config nor their role. **Skills load from exactly two places, and the package shipped them somewhere else.** A config could name a skill that could not possibly resolve, and nothing anywhere checked.

Xitong described the symptom exactly a month ago:

> *"it's easy to half-adopt. I had a working config, drafts, and run-log, but `/morning` itself didn't work because the command files were never copied. **Nothing in the flow catches this.**"*

v3.1 is the catch.

---

## What changed

| # | Change | Why | What it fixes |
|---|---|---|---|
| 1 | **`scripts/doctor.py`** validates your setup and tells you what cannot run | A rule pointing at an unresolvable skill is **silent at runtime**: it fires, finds nothing, reports no error | Daniel Zhu's *"aren't installed in my environment"*, David's *"I cannot review them at all"*, Xitong's half-adopt |
| 2 | **The package ships loadable skills.** 15 skills as `skills/<name>/SKILL.md`, each with frontmatter, copied from the versions that actually run | It shipped flat `skills/*.md` files, which is not a load path | The root cause |
| 3 | **`scripts/install-skills.sh`** installs them and verifies itself | Refuses anything without frontmatter, backs up your version rather than overwriting it, then runs the doctor. A copy that exits zero is not proof | Half-adoption |
| 4 | **The loop runs the doctor in Phase 0** and disables unresolvable rules by name | Your config stops describing coverage you do not have | Silent no-ops |
| 5 | **Role-adaptive onboarding**, five steps in `ADOPT-MORNING.md`: install, validate, infer your role, wire your jobs, read the coverage report | v3 asked you to fill in a config by hand and find out over a week what did not work | A week of discovering nothing ran |
| 6 | **Your existing personal tools are first-class** in the config | Three people built role-specific drafters that work and cannot travel | The real coverage gap |
| 7 | **`CONTRIBUTING.md` and `adoption-log.md`** | The playbook records authorship: ~70 entries, all "added by {self}", **no field for who else used it** | The reusability KR has nowhere to record the only thing it measures |
| 8 | **Per-item verify in pre-drafting**, plus shortest-job-first ordering | Run #30 wrote 5 drafts then hit the watchdog. **None was graded and the brief still said `drafting…`**, because verification was batched behind the last draft | A kill costing one item instead of five |
| 9 | **Watchdog kills are reported**, with counts | A kill mid-drafting was completely silent: the brief had landed, so the runner said "already delivered, nothing to do" | The loop's own rule: a silent failure is worse than no automation |
| 10 | **Health check reports planned vs written vs verified** (`6 planned · 5 written · 0 verified`) | Run #30 lost a planned item and nobody knew until the files were counted by hand | Invisible gaps |

---

## What the doctor found on its first run

On the PO's own machine, before anyone else touched it:

```
✗ sprint_package   sprint-report   NOT LOADABLE
```

The config named `sprint-report`. The installed skill is `sprint-reporting`. **A name mismatch, which is worse than a missing file because it looks correct.** It is the first link of the end-of-sprint chain (`sprint-report → okr-tracker → ops-update → stakeholder-comms`), so that chain has had a silent no-op at the front of it, and it would next have fired at the sprint boundary on 2026-08-30. Fixed.

It also produced one false positive on its own first run and was corrected: routing rules may legitimately name a **command** (`daily_spine` reuses `/standup`), and those resolve from `.claude/commands/`. Worth stating because a validator that cries wolf gets ignored, which is how you end up back where we started.

---

## What v3.1 deliberately does not do

**It does not write drafter skills for a role it has never seen.**

A drafter is trustworthy because it has a rubric, and a rubric is calibrated because it has goldens — real output a competent human shipped and was happy with. That cannot be synthesised. So the loop can install itself, validate itself, narrow itself to the tools present and adapt its routing, but **it cannot invent your role's quality bar.**

Generate a CM drafter with no golden and no rubric and you get confident ungraded output, which is seventy personal scripts at machine speed.

This is the same conclusion from the other direction as the reusability KR: **a job is handoverable exactly when it carries an explicit, gradeable standard.** The L2 bar and the world-class bar are the same problem.

---

## The part that needs you, not the loop

**Three role-specific drafters already exist, work, and cannot be adopted by anyone.**

| What | Author | Evidence |
|---|---|---|
| A dev `ticket-brief` drafter | Xitong | *"caught context traps immediately"*, 3 of 4 first-pass READY |
| A full CM daily loop | Chris | **21 of 21 working days unattended, zero misses** |
| `ac-timesheet`, `ac-email-digest` | Andres | In use, offered to the squad on 2026-08-20 |

The loop does not need to learn what a developer does. **A developer already solved it and the solution cannot travel.** `CONTRIBUTING.md` is the path: a skill, a rubric, and one real golden you were happy to ship. The golden is the price of entry because it is what lets someone who did not write it judge the output.

Against the KR that is the difference between **one** passing automation and **four**.

Same for platform fixes, which have been landing in Jira comments and staying there: Maria's Windows port of `notify.py`, Andres's thirteen bugs, Xitong's three OpenCode failure classes with verified fixes, Daniel Zhu's headless `--model` pin. Every one is a labelled defect about shared code that is not in the shared code.

---

## Upgrading from v3

```bash
cd 05-automation/agent-manager/morning-loop-share
./scripts/install-skills.sh          # installs 15 loadable skills, then verifies
python3 scripts/doctor.py            # fix anything it flags before your next run
```

Then read `ADOPT-MORNING.md` steps 3 to 5 if you have never done a JTBD capture, and `CONTRIBUTING.md` if you have built something that works.

If the doctor flags a rule you cannot fix today, **comment the rule out.** A commented rule is a visible gap. An active rule pointing at nothing is an invisible one, and that is the whole reason this release exists.

---

## Honest status

v3.1 fixes packaging, validation and onboarding. It does not yet have a clean unattended run behind it:

- **08-19:** hand-invoked. Zero.
- **08-20:** fired on schedule, died after 45 seconds of DarkWake. Zero. Fixed with `caffeinate -i`.
- **08-21 (run #30):** fired **exactly on time**, delivered the brief unattended, wrote 5 real drafts, then the watchdog killed it at 50 minutes with none of them verified. Zero, because the criterion needs a drafted **and verified** artefact.

The scheduler problem is solved. The remaining gap is that pre-drafting does not finish inside the window and did not leave graded work when cut off, which is what changes 8, 9 and 10 address. **Day count against KM-14354: zero of five.**

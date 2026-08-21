# Morning loop: v2 → v3.1

**The one document to read.** `V3-WHATS-NEW.md` and `V3-1-WHATS-NEW.md` are the per-release detail; this is the whole arc in one place.

Updated 2026-08-21.

---

## TL;DR

**v2 was accurate and unused. v3.1 does the work and can be adopted.**

| | v2 | v3.1 |
|---|---|---|
| Drafts produced by a scheduled run | **0 across 7 runs** | Drafted and graded unattended, before you sit down |
| The morning question | "Shall I start on these?" | "Which of these do I ship?" |
| The brief's own claims | Unverified | Every status, number and absence checked by a separate agent that re-reads the source |
| Sensing | One long chain; the tail got dropped | Parallel probes, each quoting its evidence verbatim |
| A skill your config names but cannot load | Silent. Fired, found nothing, said nothing | Caught before the run, named, and the rule disabled |
| Installing it | Copy files and find out over a week | `install-skills.sh` then `doctor.py`, both of which verify themselves |
| Something you built | Stayed on your machine | `CONTRIBUTING.md` + `adoption-log.md` |

**Why it kept not working for you was one packaging bug.** Skills load from exactly two places and the package shipped them somewhere else, so a config could name a skill that could not possibly resolve and nothing checked. That is the whole of *"aren't installed in my environment"*, *"I cannot review them at all"* and *"nothing in the flow catches this"*.

**Adopt it:**

```bash
git clone gitlab@gitlab.thenetcircle.lab:tomzduda/morning-loop.git
cd morning-loop
cp agent-manager-config.template.yml agent-manager-config.<you>.yml
./scripts/install-skills.sh      # installs skills and commands, then verifies
python3 scripts/doctor.py        # do not proceed until this exits 0
```

**Honest status: the package is ready, the loop is not finished.** No clean unattended run behind it yet. Day count against the closing criterion is **0 of 5**. Details at the bottom.

---

## What actually changed, grouped by the problem it solves

### 1. It produces work now

| | v2 | v3.1 |
|---|---|---|
| Drafting | Gated behind a human at the morning gate | **Done in the unattended prep.** Drafting is a local file write, so it never needed a gate; shipping did |
| The gate | Permission to *start* | Permission to *release*, per item |
| Verification of drafts | Batched after all drafting | **Per item, stamped as each one finishes**, so a timeout leaves graded work |
| Draft ordering | Priority only | Priority, then **shortest job first** |

**The evidence.** Across seven consecutive scheduled runs, v2 planned 2 to 6 items every morning and dispatched **zero**. On the last of them, four of five items expired at ceremonies happening that same day. Every adopter reported the same: `0 of 21 working days delivered unattended` (Daniel Zhu), *"No drafter has ever executed once"* (David), *"exactly 1 is automated"* (Chris).

**Xitong arrived at this independently**, from his own run data, and phrased it better than the release did: *"gate matching blast radius — auto-run `external_action: none` drafts at prep time."* A draft that ships nowhere does not need a gate at all. That is the next candidate.

### 2. You can trust what the brief says

| | v2 | v3.1 |
|---|---|---|
| Sensing | One serial chain in one growing context | **Parallel probes**, one bounded context each |
| What a probe returns | Prose | **A claim plus the verbatim excerpt it rests on.** Cannot quote it? Returns `unavailable` |
| The brief's claims | Unverified. Only drafts were graded | **A grounding gate before delivery** for every status, number, absence, change or experiment state |
| How a verifier checks | Unspecified | **Re-reads the source itself.** Never grades a claim against the probe's own output, never batches by claim |
| Two verifiers disagreeing | No rule | **A third agent judges the disputed checks only.** A block-severity fail both agree on is never re-heard |

**The evidence.** Four separate runs matched on a *label* instead of the *row*, and one of them retracted a finding that had been correct. A false alarm about withdrawn Amplitude events ran for four runs. A `-12%` that was really `-2.5%`. And the serial chain kept dropping its own tail: *"no Every.to; no ExoClick; commitments ledger still unreconciled (4th run)"*.

On its first run the fan-out reconciled that ledger for the first time in **14 days**, closing 9 items and surfacing 2 triggers that had already fired and never been seen.

### 3. Findings get closed instead of re-listed

| | v2 | v3.1 |
|---|---|---|
| Carried items | A "discipline" paragraph | **A ladder with numbers.** Escalate at 2, auto-fix at 3 if it is a local file, lead with the count at 4 |
| A stale config value | Reported | **Repaired**, when the correct value is verifiable live. Never permissions, delivery, schedule or cadence |

**The evidence.** One config fix reached *"6th time of asking"*. The ledger went unreconciled four runs running. Both were detected correctly every single time and closed by nobody, so detection was never what was missing.

### 4. It can actually be adopted — this is the v3.1 half

| | v2 / v3 | v3.1 |
|---|---|---|
| How skills shipped | Flat `skills/*.md` files, **which is not a load path** | `skills/<name>/SKILL.md`, 15 of them, each with frontmatter, copied from the versions that run |
| Commands | Not shipped at all | `commands/` ships, and the installer puts them in `~/.claude/commands/` |
| Rubrics | Not shipped | `rubrics/` ships, so the verify stage has something to grade against |
| Validation | None | **`doctor.py`**: `ok` / `NOT LOADABLE` / `MISSING`, with the exact fix command |
| Installing | Manual copy | **`install-skills.sh`**: refuses skills without frontmatter, backs up your version rather than overwriting it, then runs the doctor |
| Onboarding | Fill in a config blind | Five steps: install, validate, **the loop reads your role**, wire your jobs, read a coverage report |
| Your own tools | Nowhere to put them | First-class routing rules, plus `CONTRIBUTING.md` to share them |
| Where it lives | A folder in the PO's workspace repo | **Its own internally-shared repo** |

**Why this mattered more than anything else in the release.** Skills load only from `<repo>/.claude/skills/<name>/SKILL.md` or `~/.claude/skills/<name>/SKILL.md`. The package shipped neither shape, so a rule could point at a skill that could never resolve: it fired, found nothing, reported no error, and your config kept describing coverage you did not have.

**On its first run the doctor found a real bug in the PO's own config**: it named `sprint-report` where the installed skill is `sprint-reporting`. That silent no-op sat at the front of the end-of-sprint chain and would next have fired at the sprint boundary.

### 5. It survives the morning

| | v2 | v3.1 |
|---|---|---|
| A launchd wake | Bare run; macOS slept 45 seconds later and killed it | **`caffeinate -i`** holds the machine awake for the run |
| Failure diagnosis | Grepped the **cumulative** log, so every failure since July read as "login expired" | **Scoped to the current run**, with a separate branch for machine sleep |
| A watchdog kill | Completely silent | **Reported with counts**, and it no longer overwrites a good delivery receipt |
| Health check | Did the brief land? | Also: **planned · written · verified**, and the drafted-but-never-shipped streak |
| The notification's top item | Whatever the first ASK happened to be | **The brief's own TOP OF YOUR LIST.** Numbered items are counted too |

---

## What the team asked for, and what happened to it

| Asked | By | Outcome |
|---|---|---|
| Does a watchdog timeout reset the 5-day counter? | Maria | Criterion changed: five working days, **not consecutive** |
| Does the verifier re-query or trust cached output? | Maria | **Re-queries**, now explicit, plus a rule against batching by claim |
| What breaks a tie between verifiers? | Maria | **A third agent judges** the disputed checks |
| Ceremony capture has no rubric | Maria | **Excluded from the trial**, and squad ceremonies are hers to record |
| The notifier picks the wrong top item | Maria | Fixed, and it was two bugs |
| Auto-run local-only drafts at prep time | Xitong | **Shipped as the core of v3**; his sharper version is the next candidate |
| A dev drafter that actually exists | Daniel Zhu, Xitong, David | **Packaging fixed**, so the ones that shipped now load. Xitong's own is a contribution candidate |
| Somewhere to put the tools I built | Andres | `CONTRIBUTING.md` and `adoption-log.md` |

---

## What v3.1 deliberately does not do

**It will not write drafter skills for a role it has never seen.**

A drafter is trustworthy because it has a rubric; a rubric is calibrated because it has goldens, meaning real output a competent person shipped and was happy with. That cannot be synthesised. So the loop installs itself, validates itself, narrows to the tools present and adapts its routing — but **it cannot invent your role's quality bar.**

Generate a CM drafter with no golden and no rubric and you get confident ungraded output, which is seventy personal scripts at machine speed.

**Which means the gap is not the loop's to close.** Three role-specific drafters already exist and work: Xitong's dev `ticket-brief` (3 of 4 first-pass READY), Chris's CM loop (**21 of 21 unattended, zero misses**), Andres's `ac-timesheet` and `ac-email-digest`. **None can be adopted by anyone.** A developer already solved the developer problem; the solution cannot travel. `CONTRIBUTING.md` is that path, and against the reusability KR it is the difference between one passing automation and four.

---

## Still not fixed, and the team raised all of it

| Gap | Raised by |
|---|---|
| **No CM drafter, no designer drafter** in the package | Chris; Mathieu never replied on the ticket |
| **Portability.** Windows, OpenCode and Cursor each need runner patches | Maria, Xitong, Daniel Zhu, Andres — all four fixed things locally that are **still not in the shared code** |
| **David is blocked by an org admin**, not by the loop: Rovo MCP needs API-token auth enabled | David |
| **Zero ASKs in 21 runs** for a community-manager profile, so the ASK type looks PO-shaped | Chris |
| **The feedback round is ~28 days overdue** against a 7-day cadence | Daniel Zhu |

Open an MR for the platform fixes. There is finally a repo to put them in.

---

## Honest status

| Run | What happened | Counts? |
|---|---|---|
| **08-19** | Hand-invoked. Three drafts on a day that had produced none, two claims downgraded by the new gate, one config self-repair, ledger reconciled after 14 days | **No** — hand-invoked |
| **08-20** | Fired on schedule, died after **45 seconds** of DarkWake. Misdiagnosed as a login failure | **No** |
| **08-21** | Fired **exactly on time**, delivered the brief unattended, wrote **5 real drafts** — then the watchdog killed it at 50 minutes with none verified | **No** — the criterion needs a *verified* artefact |

**Day count: 0 of 5.** The scheduler problem is solved. The remaining gap is that pre-drafting does not finish inside the window and did not leave graded work when cut off, which per-item verify now addresses and which nothing has yet proven.

**A note on how the package itself was tested.** After publishing, it was cloned as a new adopter and walked through `ADOPT-MORNING.md`. That found **six** bugs, including a setup instruction pointing at a directory that does not exist in a clone, and a stray folder that made the doctor report commands as installed when they were only sitting in the checkout. Writing the validator was not enough; the validator had to be validated by using it the way you will. **That clean-clone run now gates every publish.**

# Contributing to the morning loop

**The loop cannot learn what your job looks like. You already know.** This is how what you built stops being yours only.

Read this if you have written a drafter, a script or a whole loop of your own and it works. Three of you have, and none of it can be adopted by anyone else today:

| What exists | Built by | Evidence it works | Can anyone else use it? |
|---|---|---|---|
| A dev `ticket-brief` drafter | Xitong | *"Best job: ticket-brief caught context traps immediately"*, 3 of 4 first-pass READY | No, it lives in his config |
| A full CM daily loop | Chris | **21 of 21 working days unattended, zero misses** | No, sole operator by design |
| `ac-timesheet`, `ac-email-digest` | Andres | In use, and offered to the squad | Not yet, there was no path to accept them |

That is the gap this document closes. It is also, not coincidentally, the exact bar the Q3 reusability KR asks for: **used successfully by at least one other squad member without help from the author.**

---

## What to contribute

Anything that does a recurring job for your role: a drafter skill, a probe, a delivery channel, a fix to the runner. Role-specific is the point. The package has no CM drafter and no designer drafter, and the loop is not going to invent them.

**Do not contribute a skill the loop generated for you.** A generated drafter has no golden and no rubric, so nobody can tell whether its output is good. That is seventy personal scripts at machine speed, which is the thing we are trying to get out of.

---

## The submission format

Three files. The third is the price of entry and it is the one people will want to skip.

```
skills/<your-skill-name>/
  SKILL.md                        the skill itself
rubrics/<your-skill-name>.rubric.yml    how to tell if its output is good
evals/<your-skill-name>-<date>.golden.md    one real output you were happy to ship
```

### 1. `SKILL.md`

Needs **frontmatter with a `name` and a `description`**, or it does not register as a skill at all. This is the single most common reason a skill silently never runs:

```markdown
---
name: ticket-brief
description: Write an implementation kickoff brief for the engineer picking up a ticket. Use on "brief me on this ticket", "kickoff brief", "what do I need to know before starting KM-xxxxx".
---
```

The `description` is what decides whether the skill gets selected, so write it as the trigger, not as a title.

### 2. The rubric

Checks that let someone who did not write the skill judge its output. Schema and the grading contract are in `06-skills/rubrics/README.md`. The short version:

```yaml
schema_version: 1
extends: _base
task: "one line: what this drafter produces"
calibration_target: "who the output must satisfy, e.g. 'the engineer picking up the ticket, no follow-up questions'"
checks:
  - id: acceptance_criteria_testable
    type: binary_llm
    severity: block          # block | gate | normal
    statement: "Every acceptance criterion is testable: a reader can say pass or fail without asking you anything."
    rationale: "why this check exists, ideally tied to a time it went wrong"
```

**Write checks from things that actually went wrong**, not from things that sound good. Of every check in this repo, exactly one was derived from measured evidence rather than belief, and it is the only one that has caught a repeat failure. Two or three real checks beat fifteen aspirational ones.

### 3. The golden

**One real output you were happy to ship.** Not a synthetic example. It is what makes your rubric calibratable and what lets the next person tell whether their run went well.

The test your rubric must pass: it **accepts the golden** and **rejects a bad example**. If it fails the golden, fix the check, not the golden.

---

## The validation run

Before it goes in the package, prove it works somewhere that is not your machine. This is the bar every adopter's report-back has quietly been asking for.

```bash
# 1. Does it even load?
python3 scripts/doctor.py

# 2. Install it and re-verify. The installer refuses skills without frontmatter.
./scripts/install-skills.sh --dry-run
./scripts/install-skills.sh

# 3. Run it once and grade the output against your own rubric.
#    If it cannot pass its own rubric in a fresh environment, it is not ready.
```

Then record it, which is the part with no home today.

---

## The adoption record

**The workflow playbook has no field that can hold the only thing the KR measures.** Its entry standard is *Task → Tool(s) → Setup steps → Before time → After time → Improvement % → Skill/script link*. Every one of roughly 70 entries reads "added by {self}". Four months of cataloguing authorship and zero records of adoption.

So `adoption-log.md` in this package exists to hold exactly that:

```markdown
| skill | author | who ran it | date | worked? | needed the author? | notes |
|---|---|---|---|---|---|---|
| ticket-brief | Xitong | Daniel Zhu | 2026-08-21 | yes | no | ran from the installed package, no edits |
```

Four rules, because the value is entirely in the honesty:

1. **The runner writes the row, never the author.** An author recording their own adoption is the thing that produced 70 useless entries.
2. **"Needed the author" is the whole point.** If you asked them a question, patched their code, or pinged them on Mattermost, that is a `yes`. It is still useful; it just is not L2 yet.
3. **Record failures.** *"Tried it, would not run on Windows"* is more valuable than silence, and it is the class of finding that has been sitting in Jira comments instead of the package.
4. **One row per person per skill.** Not per run.

---

## Where the package will and will not adapt

**It adapts:** routing rules, which probes run, which skills are wired, delivery channel, schedule, the model tier per probe. All config, no code.

**You should not need to edit `/morning` itself.** Xitong's adoption is the proof it is possible: *"I never modified `/morning` itself, config only."* If you find yourself editing the command, that is a gap in the config schema and it is worth a contribution.

**It will not write your role's drafter for you**, for the reason at the top: a drafter with no golden and no rubric is not something anyone else can trust.

---

## Fixes to the shared package

Different path, lower bar. If you fixed something in the runner, the notifier or the command, say so with the evidence. These have been landing in Jira comments and staying there:

- Maria: a Windows port of `notify.py`, and a UTF-8 crash on the emoji in the brief header
- Andres: thirteen bugs across two sessions, including a repo-root resolution that assumed one folder level deeper, and meeting-notes sensing that silently missed ~50 pages until he recursed deeper
- Xitong: three distinct OpenCode failure classes with verified fixes, including a `$ARGUMENTS` trailing newline and a delegation that hung until the watchdog killed it
- Daniel Zhu: a headless `--model` pin, because the default resolved to a model the account does not have

**Every one of those is a labelled defect about shared code and none of them is in the shared code.** That is the highest-value backlog this package has. Open a PR, or paste the diff on KM-14119 and say which platform it fixes.

---

## What happens to your contribution

1. **It gets installed and doctored** in a clean environment.
2. **It gets run and graded** against its own rubric.
3. **It goes in the package**, and its golden goes in `evals/` as a regression example for the next change.
4. **Its first adoption row gets written by someone else**, which is the moment it counts.

If step 4 never happens, that is worth knowing too. A skill nobody else adopts is a personal script, and the honest thing is to label it one.

---

## How to contribute, as of 2026-09-25

**Where the repo lives.** `https://ideawise.ghe.com/tomzduda/morning-loop`. It moved from the lab GitLab on 2026-09-25 when GitHub Enterprise became the Kaufmich standard. If you cloned before that date, the old remote will not fail loudly, it will simply never show you another commit:

```bash
git remote set-url origin https://ideawise.ghe.com/tomzduda/morning-loop.git
```

**You have write access.** Andres, David, Daniel Zhu, Xitong and Mathieu were added directly, no invitation to accept.

**`main` is protected and takes pull requests only.** Push your branch, open a PR, and it needs one approval before it merges. Force pushes and branch deletion are off, and an open review conversation blocks the merge. This is not ceremony: Tomek's ruling of 2026-09-24 is that nothing ships without a human looking first, and that applies to the package as much as to the drafts it produces.

**Branch naming.** Anything is fine. `xitong/opencode-failure-classes` and `david-clean-clone-fixes` both worked. What matters is the commit message: say what was broken, how you know, and what you verified. The four branches merged so far all did, and it is why they could be reviewed quickly.

**Rebase before you open the PR.** All merges so far have been fast-forwards and the history is linear. Keeping it that way makes `git log` readable as a sequence of fixes rather than a braid.

**Say what you verified, not that it works.** Xitong's merged commit is the model: *"Verified: `zsh -n` on both runners, classifier regex matches a real SSE disconnect line and not a clean log, `doctor.py` exit 0."* That sentence is what let it merge the same morning it arrived.

**One person still cannot reach this repo.** Maria has no GitHub Enterprise account in either org, and she authored the Windows runner that is now in `main`. That is an IT request, not something the repo can fix.

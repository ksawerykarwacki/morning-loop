> **This repo moved to GitHub Enterprise on 2026-09-25.**
> Home: `https://ideawise.ghe.com/tomzduda/morning-loop` . The lab GitLab copy
> (`gitlab.thenetcircle.lab/tomzduda/morning-loop`) is a frozen archive and must not be pushed to.
> If you cloned before that date:
>
> ```bash
> git remote set-url origin https://ideawise.ghe.com/tomzduda/morning-loop.git
> ```

# The Morning Loop — a shareable agent-manager for your day

> **v4 (beta) is here.** Start with [`V4-WHATS-NEW.md`](V4-WHATS-NEW.md): what changed, how to set it up,
> what to expect in week 1, and the known issues. **Already running the loop?** Upgrade with
> `python3 scripts/upgrade.py --workspace <your workspace>` (dry run first). It keeps every skill, script,
> rubric, config and runner you changed, and `--restore` undoes it.
>
> **The brief is made on your computer, so it arrives when your computer is on.** It runs at 07:52 on
> weekdays, and if the machine is closed or asleep then, the first time you open it that morning.

> **You are reading this in the standalone package repo.** Paths in these docs that begin
> `05-automation/agent-manager/morning-loop-share/` refer to **this repo's root**. So
> `05-automation/agent-manager/morning-loop-share/scripts/doctor.py` is just `scripts/doctor.py` here.
>
> Two differences from the workspace layout:
> - **Your config lives at the repo root**: `agent-manager-config.<you>.yml`. `doctor.py` looks there.
>   It is gitignored, so your config never lands in the shared package.
> - **`commands/`, `rubrics/` and the skills ship with the package.** `install-skills.sh` copies them
>   into whichever directories *your* client loads from, which is the step whose absence broke adoption
>   before v3.1. On Claude Code that is `~/.claude/skills/` and `~/.claude/commands/`; on OpenCode a skill
>   *is* the slash command, so both go to `~/.config/opencode/skills/`. `doctor.py` and
>   `install-skills.sh` detect the client, and `--client claude|opencode` overrides the guess.


## Start here (v3.1)

| If you want to… | Read |
|---|---|
| **Adopt the loop for your role** | `ADOPT-MORNING.md` — five steps, ~20 min |
| **Check your setup actually works** | `python3 scripts/doctor.py` |
| **Install the skills so they load** | `./scripts/install-skills.sh` |
| **Contribute something you built** | `CONTRIBUTING.md` |
| **Record that you used someone else's automation** | `adoption-log.md` |
| **See what changed** | `V3-1-WHATS-NEW.md`, then `V3-WHATS-NEW.md`, then `V2-WHATS-NEW.md` |

**If you take one thing from v3.1: run the doctor.** A routing rule pointing at a skill that cannot
load is silent at runtime. It fires, finds nothing, reports no error, and your config keeps describing
coverage you do not have. That is why three developers spent a month reporting drafters that had
never run once.


This is the daily loop Tomek runs every morning, packaged so **you can hand it to your own Claude Code and adopt it in ~20 minutes.** It senses your day (your Jira, the product pulse, your meetings, Every.to), decides which of *your* recurring jobs are due, shows you the work, asks permission, then drafts the automatable jobs and hands you a review + decision queue. You keep deciding; it stops doing the gathering and the manual triggering.

Built as Quick Win #1 + #2 of the squad's JTBD-automation work (O3 KR3.3, reusable workflows). The whole point is that it's the **same loop for everyone**: you only supply your own config.

**v3.1 is the current release.** The loop no longer waits for you to run it: it runs on a schedule, drafts the local-only work in the unattended prep, delivers the whole brief to you, notifies you, then checks that the brief actually landed. Delivery needs no account and no signup. Read `V2-TO-V3.1.md` for the whole arc in one place, or `V3-1-WHATS-NEW.md` for this release's detail. `V2-WHATS-NEW.md` and `V3-WHATS-NEW.md` are still here as the per-release history.

---

## What's in this folder
```
README.md                         ← you are here
V2-TO-V3.1.md                     ← the whole arc in one document; start here if you adopted v1 or v2
V3-1-WHATS-NEW.md                 ← this release's detail (then V3-WHATS-NEW.md, V2-WHATS-NEW.md)
V3-1-ROLE-ADAPTATION-DESIGN.md    ← why the loop adapts to your role instead of shipping role drafters
ADOPT-MORNING.md                  ← the full onboarding guide (read this next)
CONTRIBUTING.md                   ← how to get something you built into the package
adoption-log.md                   ← record that you ran someone else's automation
MODIFICATIONS.md                  ← the menu of adopter-built mods, pick and choose what to adopt
RUN-AND-NOTIFY.md                 ← how to run the loop unattended + get it delivered to you
ATTENTION-TRIAGE.md               ← the spec behind the attention-triage skill
agent-manager-config.template.yml ← COPY + FILL this. It is the only file that is "yours"
commands/
  morning.md                      ← the /morning command (the orchestrator)
  brief.md                        ← /brief <#id>, reopen a past brief with its full context
  standup.md                      ← /standup (the SENSE phase morning is built on)
  team-standup.md                 ← /team-standup (personal brief for devs/designers)
skills/<name>/SKILL.md            ← 15 loadable skills, the shape a client can actually load
  jtbd-capture/                   ← run this FIRST to list your jobs before configuring routing
  product-pulse/                  ← pulse (used by standup)
  morning-feedback/               ← the after-a-week feedback skill (auto-fires ~day 7)
  attention-triage/, backlog-analysis/, growth-circle-update/, meeting-debrief/,
  okr-tracker/, ops-update/, sprint-plan/, sprint-reporting/, stakeholder-comms/,
  stall-escalation/, ticket-brief/, ticket-quality-check/   ← the drafters routing can call
  agent-manager-config.template.yml    ← byte-identical copy of the root template, kept for the
  agent-manager-config.engineer.yml    ←   workspace layout; the engineer variant is prefilled
rubrics/
  _base.rubric.yml                ← every draft is graded against this, plus its own rubric if it has one
  README.md                       ← the grading contract the verifier applies check by check
  <skill>.rubric.yml              ← one per drafter that has a calibrated standard
scripts/
  doctor.py                       ← validates your setup: ok / NOT INSTALLED / NOT LOADABLE / MISSING
  install-skills.sh               ← installs skills + commands into your client's load paths, then verifies
  run-prep.template.sh            ← schedule the read-only pre-run (launchd) + delivery safety net
  run-prep.opencode.template.sh   ← the same runner for OpenCode
  com.morning-loop.prep.plist.template  ← the launchd job the runner is scheduled by
  run-prep.template.ps1, register-prep-task.template.ps1  ← the same for Windows (Task Scheduler)
  notify.py                       ← delivers the brief (macOS notification / Mattermost / file)
  SETUP-DELIVERY.md               ← pick a channel. The default costs ZERO setup: read this
```

---

## Install
**Do not hand-copy the files.** That is how v2 and v3 were adopted and it is how three developers
ended up with drafters that had never run: a skill in the wrong directory is invisible in exactly the
way a missing one is not. Run the installer, then the doctor:

```bash
./scripts/install-skills.sh --dry-run     # see what it would do
./scripts/install-skills.sh               # do it, then verify itself
python3 scripts/doctor.py                 # do not proceed until this exits 0
```

On Windows the runner is Task Scheduler rather than launchd: see `scripts/SETUP-DELIVERY.md` for `run-prep.template.ps1` and `register-prep-task.template.ps1`.

It resolves your client's real load paths and puts each piece where that client reads it:

| From this package | Goes to (Claude Code) | Goes to (OpenCode) |
|---|---|---|
| `skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` | `~/.config/opencode/skills/<name>/SKILL.md` |
| `commands/*.md` | `~/.claude/commands/*.md` | `~/.config/opencode/skills/<name>/SKILL.md` (a skill *is* the command) |
| `agent-manager-config.template.yml` | copy to `agent-manager-config.<you>.yml` and **fill it in** | same |
| `scripts/run-prep.template.sh` | copy to `run-prep.sh` and edit | use `run-prep.opencode.template.sh` |

`--repo` installs into a checkout instead of your home directory. It probes the layout rather than
counting parents, so a package cloned inside a workspace installs into the *workspace*; with no workspace
above the clone it says so and installs into the clone, which loads only for a session rooted there.
`$HOME` always loads, which is why it is the default. `doctor.py` makes the same two probes and prints the
root it chose, because the installer writing where the doctor does not look is how this went wrong before.

Paths inside the command and config are repo-relative (`01-sprint-operations/current/...`,
`05-automation/agent-manager/...`). If your workspace uses a different layout, adjust the `paths:` block
in your config; that is the only place paths are hard-set. `paths.rubrics_dir` is one of them, and the
verifier resolves every rubric through it.

---

## The fastest way to adopt: hand it to your Claude
Once the files are in place, literally tell your Claude Code:

> "Read `ADOPT-MORNING.md` and `agent-manager-config.template.yml`, then walk me through setting up my own morning loop: help me do a JTBD capture, fill my config, and do a first dry run."

It will run `/jtbd-capture` with you, help you fill the config to your role and meetings, and do a first `/morning` (say **`n`** at the gate the first day just to see the plan). That's it.

---

## Prerequisites
- **Claude Code** installed.
- **MCPs connected** (it degrades gracefully if one is missing, never fabricates):
  - **Atlassian** (Jira/Confluence) — needed for your sprint board **and for meeting notes** (see below).
  - **Amplitude** — for the product pulse (optional).
- **Meeting notes source.** The loop's default is the shared Confluence folder Maria's pipeline posts the squad's meeting notes to (`E CRM Events & Meetings`, space `SPEC`). This works for every client and OS with no extra tool — it's read through the Atlassian MCP you already have. Set it in `meeting_source:` in your config. (If you personally run Granola, you can point `meeting_source.type: granola` instead — but nothing in the shared loop *requires* it.)
- A **JTBD capture** done first — you automate jobs you already have; the loop doesn't invent them.

---

## The safety contract (why it's safe to run, even scheduled)
1. **Sense, plan and verify are read-only.** They query and write local files only. Safe to schedule unattended.
2. **Shipping is gated, and shipping is the only thing that ever was.** Writing a draft into your review
   directory is a local file write, so the unattended prep may do it when `dispatch.predraft_in_prep` is on. It ships off.
   Sending that draft anywhere needs your explicit, per-item yes. The v2 gate asked permission to *start
   work*; this one asks permission to *release it*, which is where the risk always lived.
3. **Nothing leaves your workspace automatically** — creating a Jira ticket, publishing Confluence, posting to chat is `never_auto`; each ship is confirmed individually, even after you approve the gate.
4. **A draft is not automation; a shipped-on-trigger job is.** The run log stays honest about which is which, and that is the evidence trail.

**Do not loosen the `permissions:` block in your config.** The model depends on it.

**One inconsistency to be aware of, for the author to reconcile.** `commands/morning.md` implements the
model in point 2, but every shipped config still lists `gated_at_morning_approval: [run_drafting_subagents]`,
which is the v2 model where drafting itself is what the gate releases. Tomek's 2026-08-19 work log describes
the intended v3 lists as `run_local_drafting_subagents` under `unattended_allowed` with the gate renamed to
`ship_any_draft_externally`, and neither of those strings appears anywhere in the package. So the command and
the configs disagree about what the gate is for. Nothing here is a hole: `never_auto` still covers every
external action in both readings, and it is the same in both. But which list drafting belongs in is the
author's call, not a doc fix, so it is recorded rather than changed.

---

## After a week: the feedback loop (please don't skip)
Around day 7, `/morning` surfaces a one-time feedback prompt (`morning-feedback`). It reads your run-log for the objective **ready-without-edit rate**, asks ~5 questions (5 min), writes a feedback file, and drafts a summary back to Tomek (you confirm the send). This is how everyone's real use improves the *one shared loop* — routing defaults get better, weak drafters get fixed. Your feedback is the mechanism, not an afterthought.

---

## Questions
Ask Tomek. If you improve something in the loop that everyone would benefit from, say so in your feedback — good changes get folded back into this shared package so the next person inherits them.

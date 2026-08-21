# The Morning Loop — a shareable agent-manager for your day

> **You are reading this in the standalone package repo.** Paths in these docs that begin
> `05-automation/agent-manager/morning-loop-share/` refer to **this repo's root**. So
> `05-automation/agent-manager/morning-loop-share/scripts/doctor.py` is just `scripts/doctor.py` here.
>
> Two differences from the workspace layout:
> - **Your config lives at the repo root**: `agent-manager-config.<you>.yml`. `doctor.py` looks there.
>   It is gitignored, so your config never lands in the shared package.
> - **`commands/` and `rubrics/` ship with the package.** `install-skills.sh` copies the commands into
>   `~/.claude/commands/`, which is the step whose absence broke adoption before v3.1.


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

**v2 is out.** The loop no longer waits for you to run it. It runs on a schedule, delivers the whole brief to you, notifies you, then checks that the brief actually landed. Delivery needs no account and no signup. If you adopted v1, read `V2-WHATS-NEW.md` first: it lists what changed, what got folded back in from everyone's adoption feedback, and what still isn't fixed.

---

## What's in this folder
```
README.md                         ← you are here
V2-WHATS-NEW.md                   ← what changed in v2 and why (read this if you adopted v1)
ADOPT-MORNING.md                  ← the full onboarding guide (read this next)
MODIFICATIONS.md                  ← the menu of adopter-built mods — pick and choose what to adopt
RUN-AND-NOTIFY.md                 ← how to run the loop unattended + get it delivered to you
ATTENTION-TRIAGE.md               ← spec for the next stage (notification triage, ranked by your OKRs)
.claude/commands/
  morning.md                      ← the /morning command (the orchestrator)
  brief.md                        ← /brief <#id> — reopen a past brief with its full context
  standup.md                      ← /standup (the SENSE phase morning is built on)
  team-standup.md                 ← /team-standup (personal brief for devs/designers)
skills/
  agent-manager-config.template.yml ← COPY + FILL this — it's the only file that's "yours"
  morning-feedback.md             ← the after-a-week feedback skill (auto-fires ~day 7)
  product-pulse.md                ← pulse (used by standup)
  jtbd-capture.md                 ← run this FIRST to list your jobs before configuring routing
  growth-circle-update.md, meeting-debrief.md, sprint-plan.md, backlog-analysis.md,
  sprint-report.md                ← the drafter skills the routing table can call
  okr-tracker/, ops-update/, stakeholder-comms/  ← drafters in SKILL.md folder format
scripts/
  run-prep.template.sh            ← schedule the read-only pre-run (launchd) + delivery safety net
  notify.py                       ← delivers the brief (macOS notification / Mattermost / file)
  SETUP-DELIVERY.md               ← pick a channel. The default costs ZERO setup: read this
```

---

## Install (where each file goes)
Drop the files into your Claude Code setup, mirroring these locations:

| From this package | Goes to |
|---|---|
| `.claude/commands/*.md` | your repo's `.claude/commands/` (or `~/.claude/commands/` to make it global) |
| `skills/*.md` (flat files) | your `06-skills/skills/` (or wherever your project keeps skill markdown) |
| `skills/okr-tracker/`, `ops-update/`, `stakeholder-comms/` (folders) | `~/.claude/skills/` (these are SKILL.md-format global skills) |
| `scripts/run-prep.template.sh` | your repo's automation folder; copy to `run-prep.sh` and edit |
| `agent-manager-config.template.yml` | copy to `agent-manager-config.yml` next to your skills, then **fill it in** |

Paths inside the command/config are repo-relative (`01-sprint-operations/current/...`, `05-automation/agent-manager/...`). If your workspace uses a different layout, adjust the `paths:` block in your config — that's the only place paths are hard-set.

---

## The fastest way to adopt: hand it to your Claude
Once the files are in place, literally tell your Claude Code:

> "Read `ADOPT-MORNING.md` and `skills/agent-manager-config.template.yml`, then walk me through setting up my own morning loop: help me do a JTBD capture, fill my config, and do a first dry run."

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
1. **Sense + plan are read-only** — query + write local files only. Safe to schedule unattended.
2. **Drafting is gated** — no drafter runs without your explicit yes at the morning gate.
3. **Nothing leaves your workspace automatically** — creating a Jira ticket, publishing Confluence, posting to chat is `never_auto`; each ship is confirmed individually, even after you approve the gate.
4. **A draft is not automation; a shipped-on-trigger job is.** The run log stays honest about which is which — that's the evidence trail.

**Do not loosen the `permissions:` block in your config.** The model depends on it.

---

## After a week: the feedback loop (please don't skip)
Around day 7, `/morning` surfaces a one-time feedback prompt (`morning-feedback`). It reads your run-log for the objective **ready-without-edit rate**, asks ~5 questions (5 min), writes a feedback file, and drafts a summary back to Tomek (you confirm the send). This is how everyone's real use improves the *one shared loop* — routing defaults get better, weak drafters get fixed. Your feedback is the mechanism, not an afterthought.

---

## Questions
Ask Tomek. If you improve something in the loop that everyone would benefit from, say so in your feedback — good changes get folded back into this shared package so the next person inherits them.

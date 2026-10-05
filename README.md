> **This repo moved to GitHub Enterprise on 2026-09-25.**
> Home: `https://ideawise.ghe.com/tomzduda/morning-loop` . The lab GitLab copy
> (`gitlab.thenetcircle.lab/tomzduda/morning-loop`) is a frozen archive and must not be pushed to.
> If you cloned before that date:
>
> ```bash
> git remote set-url origin https://ideawise.ghe.com/tomzduda/morning-loop.git
> ```

# The Morning Loop

A daily loop for your workday. Every weekday morning it reads your Jira, your meetings, your inbox and chat, decides which of **your** recurring jobs are due, drafts the ones it can, and hands you one brief: what changed, what needs you, and what's ready for your yes. You keep deciding; it stops doing the gathering. Nothing leaves your machine without your per-item approval.

**v4 (beta) is the current release.** Start with [`V4-WHATS-NEW.md`](V4-WHATS-NEW.md).

**The brief is made on your computer, so it arrives when your computer is on.** It runs at 07:52 on weekdays, and if the machine is closed or asleep then, the first time you open it that morning (before 12:00).

## Start here

| You are | Do this |
|---|---|
| **Already running the loop (v3.x)** | `python3 scripts/upgrade.py --workspace <your workspace>`: a dry run that shows the plan. Then add `--apply`. It keeps every skill, script, rubric, config and runner you changed, and `--restore` undoes it |
| **New to the loop** | [`ADOPT-MORNING.md`](ADOPT-MORNING.md), about 20 minutes. Short version below |
| **Using Claude or OpenCode to do it for you** | open this repo in it and ask. It reads [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md), which tell it how to upgrade without damaging your setup |
| **Wondering if it fits your role** | [`roles/README.md`](roles/README.md): seven presets that shape the brief to a PO, engineer, scrum master, designer, community manager, data analyst or supporter |
| **Wanting to contribute something you built** | [`CONTRIBUTING.md`](CONTRIBUTING.md) |

## New to the loop: the short version

```bash
git clone https://ideawise.ghe.com/tomzduda/morning-loop.git ~/Projects/morning-loop
cd ~/Projects/morning-loop
./scripts/install-skills.sh                                          # skills, commands, agents (Windows: python scripts/upgrade.py --workspace <ws> --apply)
python3 scripts/setup_workspace.py ~/work/my-workspace <you> --role <preset>   # folders, links, a starter config for your role
cd ~/work/my-workspace
export MORNING_CONFIG="$PWD/06-skills/skills/agent-manager-config.<you>.yml"
python3 05-automation/agent-manager/scripts/doctor.py                # fix until it says ✓
```

Restart Claude Code (the verifier agents load at session start), run `/morning` once by hand from your workspace, then schedule it with [`scripts/SETUP-DELIVERY.md`](scripts/SETUP-DELIVERY.md). After a week, run `/jtbd-capture` so the loop learns the jobs you actually do.

## What's in this repo

```
README.md, V4-WHATS-NEW.md       ← start here; what v4 brings and how to get it
ADOPT-MORNING.md                 ← the full onboarding guide
CLAUDE.md, AGENTS.md             ← instructions for an AI assistant installing or upgrading the loop
CONTRIBUTING.md                  ← how something you built becomes part of the shared loop
agent-manager-config.template.yml← the config you copy (setup_workspace.py does it for you)
roles/                           ← the seven role presets
commands/                        ← /morning, /brief, /standup, /team-standup, /tickets, /shipped, /coach
skills/<name>/SKILL.md           ← 15 drafter and sense skills
agents/                          ← the four read-only verifier agents
rubrics/                         ← the quality bar each drafter is graded against
scripts/                         ← doctor, installers, upgrade, workspace setup, runners for Mac, Windows, OpenCode
coach/, templates/               ← starter coaching plan and commitments ledger
docs/                            ← reference (RUN-AND-NOTIFY, ATTENTION-TRIAGE) and docs/history/ for earlier versions
```

Your own files never live here. Your config, brief, drafts and run log live in **your workspace**, which `setup_workspace.py` creates and links this package into.

## Prerequisites

- **Claude Code** (or OpenCode) installed and logged in.
- **MCPs connected.** The loop degrades gracefully if one is missing and never makes numbers up:
  - **Atlassian** (Jira and Confluence): your board, and the meeting notes the squad posts to Confluence.
  - **Amplitude, Microsoft 365, Mattermost**: optional, depending on your role preset.
- **Python 3** for the scripts.

## The safety contract

1. **Sense, plan and verify are read-only.** They query and write local files only, so they're safe to schedule.
2. **Shipping is gated.** A draft in your review folder is a local file. Sending it anywhere needs your explicit, per-item yes.
3. **Nothing leaves your workspace automatically.** Creating a Jira ticket, publishing a Confluence page or posting to chat is `never_auto`, confirmed item by item even after you approve the morning gate.
4. **A draft isn't automation; a job shipped on its trigger is.** The run log stays honest about which is which.

Don't loosen the `permissions:` block in your config. One open item for the author: the configs still list `gated_at_morning_approval: [run_drafting_subagents]` (the v2 wording) while `/morning` implements "drafting is local, shipping is gated". `never_auto` covers every external action either way.

## After a week: tell us how it's going

Around day 7, `/morning` asks for five minutes of feedback (`morning-feedback`): what saved you time, which drafts were usable without a rewrite, what to change. Your answers are how the shared loop gets better.

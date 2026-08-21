# Adopt `/morning` — the agent-manager daily loop

This is how you (Arame, Xitong, Cynthia, Bex, anyone) get your own version of the loop Tomek runs every morning: it senses your day (standup, pulse, Every.to, Jira, your meetings), decides which of *your* recurring jobs are due, shows you the work, asks permission, then drafts the automatable ones and hands you a review + decision queue.

You **do not edit the `/morning` command**. You copy one config file, fill in your jobs, and run. That copy-and-fill is the whole point — the loop is the same for everyone; only your config differs.

---

## What you get
- A **morning brief** built from your Jira, the product pulse, and your meetings — no manual gathering.
- Your **recurring jobs drafted for you** (reports, debriefs, agendas — whatever you have a skill for), each self-checked by an independent verifier before it reaches you.
- A **decision queue** (things only you can call) and a **your-turn list** (the meetings and judgment calls that stay human).
- Nothing ever ships without you approving it item by item.

---

## Prerequisites (one-time)
1. **Claude Code** installed, this repo cloned/pulled.
2. **MCPs connected** (the loop degrades gracefully if one is missing, but works best with all):
   - **Atlassian** (Jira/Confluence) — required for the sprint board **and for meeting notes**.
   - **Amplitude** — for the product pulse (optional; PO usually runs it).
   - **Meeting notes** come from the shared **Confluence folder** the squad's notes are posted to (`E CRM Events & Meetings`, space `SPEC`) — no Granola needed, it reads through the Atlassian MCP. Configure it in `meeting_source:`. This is the universal default; Granola is an optional personal alternative, never a requirement.
3. You've done a **JTBD capture** — run `/jtbd-capture` (or read `06-skills/skills/jtbd-capture.md`). You need to know your recurring jobs and which have a skill *before* you fill the routing table. This is the honest first step: the loop automates jobs you already have, it doesn't invent them.

---

## Setup, v3.1: five steps, and the loop moulds itself to your role

**v3.0 and earlier asked you to fill in a config by hand and then find out over a week what did not work.** Three developers spent that week discovering their drafters had never run once. That was not their config and not their role: the package shipped skills in a folder skills cannot load from, and nothing checked. v3.1 checks.

### Step 1 — install the skills where skills actually load from (2 min)

```bash
cd 05-automation/agent-manager/morning-loop-share
./scripts/install-skills.sh --dry-run     # see what it would do
./scripts/install-skills.sh               # do it, then verify itself
```

It copies each `skills/<name>/SKILL.md` into `~/.claude/skills/`, **refuses to install anything without frontmatter and a description** (which is the number-one reason a skill silently never runs), backs up any skill of yours that differs rather than overwriting it, and then runs the doctor because a copy that exits zero is not proof.

Use `--repo` instead if you would rather install into the repo's `.claude/skills/`.

### Step 2 — copy the config template and run the doctor (3 min)

```bash
cp skills/agent-manager-config.template.yml \
   ../../../06-skills/skills/agent-manager-config.<you>.yml
python3 scripts/doctor.py
```

The doctor is the whole difference in this release. It distinguishes three states that used to look identical:

```
✓ gc_update            growth-circle-update     ok
✗ sprint_package       sprint-report            NOT LOADABLE
    fix: mkdir -p ~/.claude/skills/sprint-report && cp '...' ~/.claude/skills/sprint-report/SKILL.md
✗ ideation_synthesis   idea-forge               MISSING
    fix: no file named idea-forge anywhere. Either write the skill, or comment the rule out
         so it stops looking like coverage.
```

**A rule whose skill cannot resolve is silent at runtime.** It fires, finds nothing, reports no error, and your config keeps describing coverage you do not have. Run the doctor after setup and again every time you edit the config.

It found a real bug in Tomek's own config on its first run, on a chain that would next have fired at a sprint boundary.

### Step 3 — let the loop read your role, then correct it (5 min)

Run `/jtbd-capture`. It reads what is already there rather than interviewing you cold: your `CLAUDE.md`, your memory directory, your recent files, your connected MCPs, and the tickets assigned to you. It infers your role and your recurring jobs, grades each by honest automation level and reusability, and asks only about what it could not find.

**It proposes; you correct.** An inferred role you did not confirm is a guess, and a guess in a config is worse than a blank.

### Step 4 — turn your jobs into routing rules

Each job from step 3 becomes a candidate rule: its trigger signal, its bucket (`draft` / `decision` / `human` / `auto`), and what shipping it would touch.

Two rules that keep this honest:

- **A job with no skill available is written in commented out, with the reason.** A commented rule is a visible gap. An active rule pointing at a skill that does not exist is an invisible one, and that is the failure this release exists to end.
- **Wire in the tools you already have.** If you have written your own drafter, a script, or a personal digest, it belongs in the config as a rule. Xitong's dev drafter and Andres's `ac-timesheet` and `ac-email-digest` are exactly this. Then read `CONTRIBUTING.md`, because the squad needs them too.

Re-run the doctor. Do not proceed while it exits non-zero.

### Step 5 — read the coverage report before you trust anything

The loop should tell you on day one what it will and will not do for you:

```
Your 14 jobs: 4 have a drafter that loads. 2 need a skill nobody has written.
8 are keep-human.
Nothing here will run unattended until you have one clean scheduled run.
```

Chris worked that out by hand and wrote *"My JTBD has 14 automatable jobs; exactly 1 is automated."* You should not have to.

### Then set up delivery and the schedule

See `scripts/SETUP-DELIVERY.md`. Two notes from the first weeks of real running:

- **On macOS, keep `caffeinate -i` in `run-prep.sh`.** A launchd DarkWake gives roughly 45 seconds before the machine goes back to sleep and kills the run. That cost a whole day on 2026-08-20 and reported itself as a login failure.
- **On Windows, OpenCode or Cursor, expect to patch the runner**, and please contribute the patch back. Maria, Xitong, Andres and Daniel Zhu each fixed platform issues that are still not in the shared code.

## The contract (why this is safe to run unattended)
1. **Sense + plan are read-only** — they only query and write local files. Safe to schedule.
2. **Drafting is gated** — the loop never runs a drafter without your explicit yes at the morning gate.
3. **Nothing leaves the workspace automatically** — creating a Jira ticket, publishing Confluence, posting to Mattermost is `never_auto`; each ship is a separate, individually-confirmed action. This holds even after you approve the morning gate.
4. **A draft is not automation; a shipped-on-trigger job is.** The run log is honest about which is which — that's the evidence trail for the O3 automation KR.

Do **not** loosen `permissions` in your config. The whole model depends on it.

---

## Daily rhythm
- **Morning:** run `/morning`. Skim the ✅ already-sensed block, approve the 🤖 drafts you want, work the 🟡 decisions and 🧠 your-turn list.
- **Review queue:** each draft comes with a verifier score. `READY` items need little from you; `NEEDS EDIT` items name the specific fix. Approve to ship one at a time.
- **That's it.** The loop removes the *gathering and triggering*, not the deciding.

---

## After a week: give feedback (this is how the shared loop improves)
Around day 7, `/morning` will surface a one-time **feedback prompt** (the `morning-feedback` skill). It takes ~5 min and asks what actually saved you time, which drafts were usable without a rewrite, and what to change. Your answers go to `05-automation/agent-manager/feedback/` and a summary is routed to Tomek (drafted for you — you confirm the send). This is the mechanism that turns everyone's real use into improvements to the one shared loop. Please don't skip it.

If it's noisy or not useful yet, set `feedback.enabled: false` — but tell Tomek why, because that *is* feedback.

---

## Troubleshooting
- **"An MCP isn't connected"** — the loop notes it and continues with what it has; it never fabricates. Connect the MCP and re-run.
- **Sprint phase looks wrong** — check `sprint.anchor_start`; the loop prefers Jira's `openSprints()` endDate when `prefer_jira: true`.
- **Too many drafts firing** — you added too many routing rules too fast. Trim back to the jobs you actually review.
- **Scheduled pre-run didn't write a plan** — check `launchd.log` in this folder; usually a PATH or repo-path issue in `run-prep.sh`.

Questions → Tomek. This loop is Quick Win #1 + #2 from the JTBD automation work; getting the whole squad on it is the O3 KR3.3 (reusable workflows) bar.

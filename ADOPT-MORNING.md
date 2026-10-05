# Adopt `/morning` — the agent-manager daily loop

This is how you get your own version of the loop Tomek runs every morning: it senses your day (standup, pulse, Every.to, Jira, your meetings), decides which of *your* recurring jobs are due, shows you the work, asks permission, then drafts the automatable ones and hands you a review + decision queue.

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

> **Already running the loop?** Don't follow the steps below from scratch. Run
> `python3 scripts/upgrade.py --workspace <your workspace>` (a dry run that shows the plan), then add
> `--apply`. It keeps everything you've changed. See `V4-WHATS-NEW.md`.

## Setup, v3.1: five steps, and the loop moulds itself to your role

**v3.0 and earlier asked you to fill in a config by hand and then find out over a week what did not work.** Three developers spent that week discovering their drafters had never run once. That was not their config and not their role: the package shipped skills in a folder skills cannot load from, and nothing checked. v3.1 checks.

### Step 1 — install the skills where skills actually load from (2 min)

```bash
# in a standalone clone of the package:
cd morning-loop
# or, if you are inside the PO workspace:
cd 05-automation/agent-manager/morning-loop-share
```

Then:

```bash
./scripts/install-skills.sh --dry-run     # see what it would do
./scripts/install-skills.sh               # do it, then verify itself
```

It detects your client and copies each `skills/<name>/SKILL.md` into the directory that client actually
loads from: `~/.claude/skills/` on Claude Code, `~/.config/opencode/skills/` on OpenCode. It **refuses to
install anything without frontmatter and a description** (which is the number-one reason a skill silently
never runs), backs up any skill of yours that differs rather than overwriting it, and then runs the doctor,
because a copy that exits zero is not proof. Commands go to `~/.claude/commands/` on Claude Code; on
OpenCode a skill *is* the slash command, so `/morning` is installed as a skill next to the drafters.

Pass `--client=claude` or `--client=opencode` if the detection guesses wrong (the value takes an `=`).
Use `--repo` if you would rather install into a checkout than into `$HOME`. `--repo` probes the layout
rather than counting parents: if there is a workspace above this clone it installs there, and if there is
not it says so and installs into the clone, which loads only for a session rooted inside it. `$HOME`
always loads, so that stays the default.

### Step 2: set up your workspace and run the doctor (3 min)

**New in v4.** `/morning` and the scheduled runner read and write fixed folders
(`01-sprint-operations/current/`, `05-automation/agent-manager/`, `06-skills/skills/`).
A bare clone has none of them, so v4 ships a script that creates them in the folder
you work from and links this package in:

```bash
./scripts/setup-workspace.sh ~/work/my-workspace <your-name>    # an existing folder or a new one
cd ~/work/my-workspace
export MORNING_CONFIG="$PWD/06-skills/skills/agent-manager-config.<your-name>.yml"
python3 05-automation/agent-manager/scripts/doctor.py
```

It never overwrites anything of yours, and it links the package rather than copying
it, so a `git pull` in the clone updates your workspace. It also drops a starter
config, a starter coaching plan and an empty commitments ledger where none exist.
Engineers can start from `skills/agent-manager-config.engineer.yml` instead: copy it
over the starter config, keeping the file name.

Put `export MORNING_CONFIG=...` in your shell profile, so `/morning`, the doctor and
the scheduled runner all read the same file. Always run `/morning` from the workspace.

The doctor is the whole difference in this release. It distinguishes three states that used to look identical:

```
✓ gc_update            growth-circle-update     ok
✗ dev_kickoff          ticket-brief             NOT INSTALLED
    fix: ships in the package, just not copied yet. Run ./scripts/install-skills.sh
✗ sprint_package       sprint-report            NOT LOADABLE
    fix: on disk, but in a directory this client can never load from. Reinstall it.
✗ ideation_synthesis   idea-forge               MISSING
    fix: no file named idea-forge anywhere. Either write the skill, or comment the rule out
         so it stops looking like coverage.
```

Four states, not three, because "not in the package" and "in the package and not installed yet" need
completely different fixes, and reporting the second as the first is how a fresh clone got told to write
skills that already ship. The fix commands name your client's real directories, so they differ between
Claude Code and OpenCode.

**A rule whose skill cannot resolve is silent at runtime.** It fires, finds nothing, reports no error, and your config keeps describing coverage you do not have. Run the doctor after setup and again every time you edit the config.

It found a real bug in Tomek's own config on its first run, on a chain that would next have fired at a sprint boundary.

**It checks your rubrics too, and that is the newest check.** The verify stage resolves every rubric
through `paths.rubrics_dir`, so a config with no such key cannot grade anything, not even the `_base`
fallback. The doctor treats a missing `paths.rubrics_dir` or a missing `_base.rubric.yml` as blocking, and
reports a drafter with no rubric of its own as `_base fallback (no skill rubric)`: a real gap, worth
knowing about, not a failure. That is the same silent-coverage shape as an unresolvable skill, one level
down.

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

- **`caffeinate -i` now ships in `run-prep.template.sh`, and you should leave it there.** A launchd
  DarkWake gives roughly 45 seconds before the machine goes back to sleep and kills the run. That cost a
  whole day on 2026-08-20 and reported itself as a login failure.
- **The launchd job ships too**, as `scripts/com.morning-loop.prep.plist.template`. Fill its placeholders
  per `scripts/SETUP-DELIVERY.md` rather than writing a plist from scratch.
- **A scheduler that fires is not the same as an unattended run.** `caffeinate` holds the machine awake
  once the run has started; it cannot wake a sleeping machine to start one. On a laptop with `sleep 1` and
  Power Nap on and no scheduled wake for the job, an in-app scheduled task can dispatch inside a DarkWake
  and then take hours of wall clock to finish, completing when you open the lid. Measured on one adopter's
  machine: two in-slot runs took 8h53m and 7h04m end to end, while two runs that fired during working hours
  took about 4 minutes each. Check `pmset -g sched` and `pmset -g custom` before you record a run as
  unattended.
- **OpenCode and Windows have v4 runners**: `scripts/run-prep.opencode.template.sh` and
  `scripts/run-prep.template.ps1` with `register-prep-task.template.ps1`, each with the same catch-up, lock,
  network wait and watchdog as the Mac runner. On Windows, use `setup_workspace.py` and `upgrade.py` (Python)
  in place of the zsh scripts; `SETUP-DELIVERY.md` has the steps. Cursor is still untested: expect to patch,
  and please contribute the patch back.

## The contract (why this is safe to run unattended)
1. **Sense, plan and verify are read-only.** They only query and write local files. Safe to schedule.
2. **Shipping is gated, and shipping is the only thing that ever was.** A draft written into your review
   directory is a local file write, so the unattended prep may produce one when
   `dispatch.predraft_in_prep` is on; it ships off. Sending a draft anywhere needs your explicit,
   per-item yes at the gate.
3. **Nothing leaves the workspace automatically** — creating a Jira ticket, publishing Confluence, posting to Mattermost is `never_auto`; each ship is a separate, individually-confirmed action. This holds even after you approve the morning gate.
4. **A draft is not automation; a shipped-on-trigger job is.** The run log is honest about which is which — that's the evidence trail for the O3 automation KR.

Do **not** loosen `permissions` in your config. The whole model depends on it.

**An inconsistency the author needs to settle, recorded here rather than fixed.** Point 2 is what
`commands/morning.md` implements, but the shipped configs still say
`gated_at_morning_approval: [run_drafting_subagents]`, which is v2's model where the gate releases the
drafting itself. The intended v3 lists per Tomek's 2026-08-19 work log are
`run_local_drafting_subagents` under `unattended_allowed` and a gate named `ship_any_draft_externally`;
neither string exists anywhere in the package. `never_auto` is unaffected and identical under either
reading, so no external action is easier to trigger. Which list drafting belongs in is a permission
decision, so it stays the author's to make.

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
- **Scheduled pre-run didn't write a plan.** Check the log the runner writes: `run-prep.template.sh`
  logs to `05-automation/agent-manager/launchd.log` under your workspace root, and the OpenCode runner and
  the `SETUP-DELIVERY.md` recipe log to `briefs/launchd.log`. Usually a PATH or repo-path issue in
  `run-prep.sh`.
- **The doctor reports things you know work as MISSING.** Check which root it picked; it prints the root
  and how it chose it next to the config line. A package cloned inside a workspace has to resolve to the
  *workspace*, not to the package clone, or every skill installed in the workspace reads as absent.
  `python3 scripts/doctor.py --repo /path/to/your/workspace` forces it.

Questions → Tomek. This loop is Quick Win #1 + #2 from the JTBD automation work; getting the whole squad on it is the O3 KR3.3 (reusable workflows) bar.

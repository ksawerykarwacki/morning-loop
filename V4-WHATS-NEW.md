# Morning loop v4 (beta): what's new, and what to expect

**Status: beta.** v4 has passed a fresh-install test: a clean copy of this repo, installed into an empty home folder, set up into a new workspace, the doctor run against a filled config, every script called, and the scheduled runner run end to end with a stand-in for Claude. Every bug that test found is fixed in this release (list at the bottom). What it hasn't got yet is a track record: on my own laptop the scheduled brief arrived unattended on 1 of the last 10 weekdays. Most of the misses were the laptop asleep on battery, which the catch-up job in this release is built for. So expect the brief to arrive reliably once your laptop is awake, not reliably at 07:50.

`V3-TO-V4.md` is the full proposal list with the evidence behind each row. This page only claims what is actually in this release.

## What you get

- **The brief makes itself.** Two launchd jobs instead of one: the 07:52 run, plus a catch-up that checks every 15 minutes and at login. If no brief has landed yet on a weekday morning (07:45 to 12:00), it runs. So the first time you open your laptop, the brief gets made, without you typing anything. A lock stops two runs, or a run and your own `/morning`, from ever overlapping.
- **Runs that survive a sleeping laptop.** The runner waits for the network before starting, holds the machine awake while it works, and its watchdog counts awake time only. A run that freezes with the lid closed reports "slept", not "timeout", and a run that never got online reports "no network", each with the fix.
- **A safety net on delivery.** If the run writes a brief but never delivers it, the runner delivers it. If drafts land after the brief was sent, the runner appends a list of them and re-delivers.
- **Confidence markers in the brief.** Every claim carries [V] verified live, [R] reported, [I] inferred or [C] carried, and the brief opens with a count. These are computed from the trust layer, not self-assessed.
- **Four verifier agents** (claim-verifier, disagreement-judge, sense-probe, job-drafter), now installed by the installer. They're read-only by toolset, so a check can't quietly edit what it's checking.
- **Meeting actions in one file.** Tickets, decisions, updates, questions and ideas from your meetings land in `meeting-actions.md`. Tick a box to approve; nothing is created until you tick and confirm. Re-running a draft no longer duplicates the queue.
- **Questions answered in a file.** When the loop needs you, it writes the question to `questions-{date}.md`. Type under **Answer:** and the next run reads it.
- **`/shipped`, `/tickets`, `/coach`.** Record what you sent by hand, work the meeting-action queue, and get one coaching nudge a morning from a plan you can edit.
- **On-time tracking.** Every morning is classed unattended, late or missed against your scheduled time, so "is it working" has a number.
- **Mattermost triage (opt-in).** Mentions, your watchlist channels and threads where you owe a reply, read-only. Switch it on with `mattermost_triage.enabled: true`.
- **Pinned metrics (opt-in).** List metrics under `okr_kpis` and the brief prints them every day, instead of the skill choosing.

## Setting it up

**New to the loop:** follow `ADOPT-MORNING.md`. The short version:

```bash
git clone <this repo> ~/Projects/morning-loop && cd ~/Projects/morning-loop
./scripts/install-skills.sh                              # skills, commands, agents
./scripts/setup-workspace.sh ~/work/my-workspace <you>   # folders, links, starter config
cd ~/work/my-workspace
export MORNING_CONFIG="$PWD/06-skills/skills/agent-manager-config.<you>.yml"
python3 05-automation/agent-manager/scripts/doctor.py    # fix until it says ✓
```

Then run `/morning` once by hand from the workspace, and schedule both jobs per `scripts/SETUP-DELIVERY.md`. **Restart Claude Code after installing**: the verifier agents only load at session start.

**Already on v3.1:** pull, re-run `./scripts/install-skills.sh` (it backs up anything of yours that differs), then run the doctor. Its **V4 BLOCKS** section lists what your config doesn't have yet. Copy the blocks you want from `agent-manager-config.template.yml`. Your routing, owner, meetings and permissions are never rewritten. If your scripts were copies rather than links, run `setup-workspace.sh` on your workspace: it leaves existing files alone and tells you what to link.

## What to expect

- **Day 1:** the doctor passes, one supervised run produces a brief, both jobs are loaded (`launchctl list | grep -i morning` shows two).
- **Week 1:** most mornings the brief arrives the first time your laptop is awake after 07:45. Drafts arrive as **NEEDS EDIT** more often than **READY**; that's the trust layer being strict, not the drafter being bad. Around day 7 the loop asks you for feedback. Please answer it, because that's how the shared loop gets better.
- **Your effort:** reading the brief and ticking boxes. Anything that leaves your machine (a Jira ticket, a post, a page) still waits for your per-item yes. That isn't changing.

## Known issues in this beta

- **A laptop asleep on battery can't run anything.** The catch-up job covers it once you open the lid. For a brief that's waiting when you sit down, keep the laptop on mains power overnight and schedule a wake: `sudo pmset repeat wakeorpoweron MTWRF 07:45:00`.
- **Headless login can expire.** If the runner's alert says "Claude login expired", run `claude` once interactively and log in. A permanent fix (`claude setup-token` as a required step) is planned, not shipped.
- **The `file` delivery channel never counts as delivered,** so the catch-up keeps retrying until noon. Use `macos` or `mattermost`.
- **macOS only for the scheduled path.** The Windows and OpenCode runner templates exist but haven't been through this release's test.
- **Deferred from `V3-TO-V4.md`:** cloud routine as the default deliverer (A1), the required setup-token step (A5), personal rubric overlays and calibration targets (C1, C2), `rules.local.yml` (E2), and the per-skill trust ladder (F).

## Bugs the fresh-install test found, all fixed here

1. `/morning` and the doctor called `coach.py`, `sharpen.py`, `shipped.py`, `/coach`, `/shipped` and `/tickets`, none of which were in the repo.
2. The doctor on `main` had lost OpenCode support and the layout probing (an earlier sync overwrote it), so the installer's own verify step crashed. The previous doctor is restored, with the v4 block checks kept.
3. A clean clone had no workspace folders, so the runner and `/morning` couldn't find their own scripts. Fixed by `setup-workspace.sh`.
4. Once the scripts were linked into a workspace, they resolved their root to the package and would have written briefs and trust files into the clone. Every script now uses the folder you run from first.
5. A fresh config was missing seven of the eight v4 blocks, and the engineer template was still v3. Both templates now ship them, along with the paths they need.
6. The installer exited with an error on a first install, before any config existed. That's now reported as the next step.
7. Four shipped skills hardcoded the author's own workspace path.
8. The ledger reconciler refused a brand-new ledger; the starter ledger now gets today's date.
9. The team runner template lacked the catch-up guard, the lock and the network gate. It now matches the runner the PO loop actually uses, plus a catch-up launchd template.

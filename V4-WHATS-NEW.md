# Morning loop v4 (beta): what's new, and what to expect

**Status: beta.** v4 passed two tests before release. The fresh-install test: a clean copy of this repo, installed into an empty home folder, set up into a new workspace, the doctor run, every script called, and the scheduled runner run end to end with a stand-in for Claude. The upgrade test: a v3.1 setup with someone's own work in it (a tuned skill, a personal skill and command, a patched script, a personal script and rubric, custom routing, a filled-in runner) upgraded to v4, checked byte for byte, then undone. Every bug those tests found is fixed in this release (list at the bottom).

**Your brief is made on your computer, so it arrives when your computer is on.** There is no server. The loop runs on your laptop at 07:52 on weekdays, and if the laptop is closed or asleep then, it runs the first time you open it that morning (any time before 12:00). On the PO loop that means the brief is usually there shortly after the laptop is opened, around 8. A laptop that stays shut all morning gets no brief that day, and the loop says so the next time it runs.

`V3-TO-V4.md` is the full proposal list with the evidence behind each row. This page only claims what is actually in this release.

## What you get

- **The brief makes itself, whenever your computer is on.** Two scheduled jobs instead of one: the 07:52 run, plus a catch-up that checks every 15 minutes and at login. If no brief has landed yet on a weekday morning (07:45 to 12:00), it runs. So the first time you open your laptop, the brief gets made, without you typing anything. A lock stops two runs, or a run and your own `/morning`, from ever overlapping.
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

**Already running the loop (v3.x): upgrade, don't reinstall.** Your skills, commands, scripts, rubrics, config and runner are your work, and the upgrade is built to keep them:

```bash
cd ~/Projects/morning-loop && git pull
python3 scripts/upgrade.py --workspace ~/work/my-workspace            # dry run: shows the plan, changes nothing
python3 scripts/upgrade.py --workspace ~/work/my-workspace --apply    # do it
```

| what you have | what the upgrade does |
|---|---|
| a file that is a stock copy of an older version | upgrades it, after copying the old one to a backup folder |
| a file you changed (a tuned skill, a patched script) | **keeps yours**, and puts v4's version beside it as `<name>.v4-new` so you can take what you want |
| your own skills, commands, scripts, rubrics | never touched |
| your config | never edited. The v4 blocks it lacks go into `*.v4-additions.yml` next to it; paste the ones you want. Without them the loop keeps doing what it does for you today |
| your scheduled runner | never edited. A `run-prep.v4.sh` with your WORKDIR filled in goes next to it; swap it in when you're ready and load the catch-up job |

"Stock copy" isn't a guess: the upgrade asks git whether this package ever shipped exactly that file content. Anything it can't prove is stock is treated as yours. Everything it replaces goes into one backup folder, and `python3 scripts/upgrade.py --restore <that folder>` puts it all back. `install-skills.sh` follows the same rule if you run it instead.

## What to expect

- **Day 1:** the doctor passes, one supervised run produces a brief, both jobs are loaded (`launchctl list | grep -i morning` shows two). If you upgraded, look through any `.v4-new` files and your `*.v4-additions.yml`.
- **Week 1:** most mornings the brief arrives the first time your computer is on and awake after 07:45. Drafts arrive as **NEEDS EDIT** more often than **READY**; that's the trust layer being strict, not the drafter being bad. Around day 7 the loop asks you for feedback. Please answer it, because that's how the shared loop gets better.
- **Your effort:** reading the brief and ticking boxes. Anything that leaves your machine (a Jira ticket, a post, a page) still waits for your per-item yes. That isn't changing.

## Known issues in this beta

- **No computer, no brief.** The loop runs on your machine. If it's off or asleep all morning, nothing runs; the catch-up covers you as soon as you open it before 12:00. If you want the brief waiting when you sit down, keep the laptop on mains power overnight and schedule a wake: `sudo pmset repeat wakeorpoweron MTWRF 07:45:00`.
- **Headless login can expire.** If the runner's alert says "Claude login expired", run `claude` once interactively and log in. A permanent fix (`claude setup-token` as a required step) is planned, not shipped.
- **The `file` delivery channel never counts as delivered,** so the catch-up keeps retrying until noon. Use `macos` or `mattermost`.
- **Mac, Windows and OpenCode all have v4 runners, tested to different depths.** Mac: the full runner end to end. OpenCode: the full runner end to end on a Mac with a stand-in for the `opencode` binary, including lock, catch-up, network failure, watchdog and a simulated sleep; real OpenCode login-error wording is still unverified. Windows: both PowerShell scripts parse cleanly and the runner ran end to end under PowerShell 7 on a Mac with 30 logic checks, but nothing has run on a real Windows machine yet: not Task Scheduler registration, not PowerShell 5.1, not sleep and wake. **Before Windows teammates rely on it, one of them should do a supervised run and register the tasks.** On Windows use `setup_workspace.py` and `upgrade.py`, because the `.sh` scripts need zsh.
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
9. The installer overwrote a skill or command you had changed (after backing it up), so your version silently stopped loading. It now keeps yours and puts the new one beside it. `upgrade.py` does the same for scripts and rubrics, and never edits your config or runner.
10. A workspace whose scripts were copies, not links, got none of a new version. `upgrade.py` upgrades the stock copies and adds what's missing.
11. The notification led with the first question instead of the brief's own top item, and counted skipped drafts as drafts (2 became 5). Both fixed, checked against five real briefs.
12. The Windows and OpenCode runners had none of the v4 catch-up, lock, network wait or on-time record. Both are now at parity with the Mac runner, and Windows registers two tasks.
13. Workspace setup was zsh-only, so Windows users could not run it. It is Python now, linking where the system allows and copying where it does not.
14. A `file`-channel day was always scored "missed" (the receipt had no time), and the Mac catch-up re-ran the whole brief every 15 minutes for file-channel users. Both fixed.
15. The team runner template lacked the catch-up guard, the lock and the network gate. It now matches the runner the PO loop actually uses, plus a catch-up launchd template.

# Adoption log

**The one thing the reusability KR measures, and the only place it is recorded.**

The workflow playbook records authorship: roughly 70 entries, every one "added by {self}". Its entry
standard has no field for who else used it, so four months of cataloguing produced zero evidence of
adoption. This file is that field.

**The bar:** used successfully by at least one other squad member **without help from the author.**

## Rules

1. **The runner writes the row, never the author.** An author logging their own adoption is what made
   the playbook useless.
2. **"Needed author?" is the whole point.** Asked them a question, patched their code, pinged them on
   Mattermost: that is a `yes`. Still useful, just not L2 yet.
3. **Record failures.** "Tried it, would not run on Windows" is worth more than an empty row.
4. **One row per person per skill**, not per run. Update the row rather than adding another.

## Log

| skill / tool | author | who ran it | date | worked? | needed author? | notes |
|---|---|---|---|---|---|---|
| `/km-workflow-push` | Maria Sommer | Andres, Xitong, Daniel Zhu, David, Mathieu, Jasmine, Chris, Tomek | 2026-05-28 → 06-12 | yes | no | Backfilled 2026-08-20 from KM-12215: 8 non-authors posted skill-generated output and created real Confluence pages, no help request in 37 comments. **Inferred from artifacts, not testimony** |
| `/morning` core (v1) | Tomek Duda | Xitong Deng | 2026-07-22 | yes | no | *"I never modified /morning itself, config only"*, 7/7 drafts verifier-READY. Had to symlink command files himself |
| `/morning` core (v2) | Tomek Duda | Daniel Zhu | 2026-08-17 | yes | no | 2 confirmed unattended fires. Self-fixed a headless `--model` pin |
| `/morning` core (v2) | Tomek Duda | Andres Cagua | 2026-08-17 | yes | no | First unattended run after 13 self-made fixes across two sessions |
| `/morning` core (v2) | Tomek Duda | Maria Sommer | 2026-08-12 | partial | no | Windows: ported `notify.py`, fixed a UTF-8 crash. Never delivered unattended by the scheduler alone |
| `/morning` core (v2) | Tomek Duda | David Predusel | 2026-08-21 → 09-02 | partial | no | **Row rewritten by the runner on 2026-09-02, per Rule 1: the author wrote the original.** Not 12 runs, and not auth. `~/Library/Logs/Claude/main*.log` records **8** cron dispatches across 9 working days (08-21, 24, 25, 26, 27, 28, 09-01, 09-02) plus one manual `morning-prep-testfire` on 08-20. Nothing was blocked on Rovo: the briefs reach Jira, git, GitHub and Confluence, cite live keys and commits, and name the sources they never attempted under a `Degraded` heading. Zero drafts was mechanical, because the scheduled routine was instructed to run Phase 1 and 2 only. **0 of the 8 runs was unattended.** The 2 that fired inside the cron slot took **8h53m41s** and **7h04m08s** to write their plan file; the 2 that fired during working hours took **4m15s** and **4m13s**; birthtime equals mtime on all 8 plan files, so nothing was resumed or appended to. The cause is local and not the loop: `pmset -g sched` lists no wake for this task and `sleep` is 1 minute on both AC and battery with Power Nap on, so the in-app task dispatches during a DarkWake and completes on lid-open |
| `/morning` core (v3.1) | Tomek Duda | Daniel Zhu | 2026-09-01 | partial | **yes** | OpenCode / macOS. **The package could not install itself on OpenCode at all** — `install-skills.sh` and `doctor.py` both hardcode `~/.claude/…`, so an unmodified run copies 19 files where nothing reads them and reports success. Clean-clone adopt surfaced 8 package bugs (6 fixed on `opencode-client-port`, 4 of them hitting every adopter regardless of client). Supervised run delivered brief #1 (exit 0, receipt `sent`, 4 SOLVE / 4 ASK / 3 HUMAN) and the loop self-repaired 3 things unattended. Scheduler installed; **0 unattended fires so far**, first is 2026-09-02 |
| `/morning` core (v3.1) | Tomek Duda | David Predusel | 2026-09-02 | pending | **yes** | Clean-clone gate run before adopting, per the ticket. Needed the author, because blockers had to be fixed before a clean clone passed its own doctor. `doctor.py`'s `repo_root()` returns the first ancestor holding `.git`, which is the package clone when the package is cloned inside a workspace, so it reported a correct and fully installed setup as "4 thing(s) cannot run" and its fix text told me to write skills that already ship. `install-skills.sh --repo` resolves the same wrong root. No shipped config defined `paths.rubrics_dir`, which `commands/morning.md` resolves every rubric through. The engineer drafters shipped with no rubric of their own, so `_base` graded them alone. Fixes are on branch `david-clean-clone-fixes`. Unattended count still 0 |
| `ticket-brief` dev drafter | Xitong Deng | David Predusel | 2026-09-02 | pending | **yes** | Second user, and the placeholder row is retired per Rule 4. Ships since v3.1 as `skills/ticket-brief/SKILL.md`, but with no rubric of its own, so the verifier graded it against `_base` alone; the rubric was written on 2026-09-02 as part of adopting it. Installed and resolving. No draft shipped yet |
| CM daily loop | Chris Gamrot | — | — | — | — | **Awaiting a second user.** 21/21 unattended for the author. Sole-operator by design |
| `ac-timesheet` | Andres Cagua | — | — | — | — | **Offered 2026-08-20**, no adopter yet |
| `ac-email-digest` | Andres Cagua | — | — | — | — | **Offered 2026-08-20**, no adopter yet |

## Honest count, 2026-08-21

**Meeting the L2 bar: 1** (`/km-workflow-push`, and on inferred rather than testimonial evidence).
**Meeting it with an asterisk: 1** (the `/morning` core, where every adopter had to patch the author's
code first, which passes the letter of "without help from the author" and not its spirit).
**Awaiting a first outside user: 4.**

The four waiting are the fastest route to a real number, and three of them already work.

## Recount, 2026-09-02 (added by the runner, not the author)

The counts above are dated 2026-08-21 and three of their inputs have moved since.

**`ticket-brief` has a second user now** (2026-09-02), so "awaiting a first outside user" is **3**,
not 4. It is `pending` rather than `yes`: the skill resolves and is routed, and it has produced no
draft that anyone has shipped.

**My v2 row said `worked? no` and blamed Rovo API-token auth.** Rewritten above from the desktop
app's own dispatch log. Sense and plan worked on my machine for 8 runs; drafting never ran, and the
reason was in the routine and the config rather than in an org admin's hands. Worth separating,
because "blocked on IT" and "the prep was told to stop after Phase 2" lead to completely different
fixes and only one of them was true.

**The number that matters most: 0 of my 8 runs was unattended.** Two fired inside the cron slot and
took 8h53m41s and 7h04m08s to write a plan; two fired during working hours and took about 4 minutes.
That is the signature of a task dispatched in a DarkWake and finished on lid-open, and it means my
row is evidence about my power settings, not about the loop's scheduler.

**The asterisk on the `/morning` core got bigger, not smaller.** Every adopter so far has patched the
author's code first. Daniel Zhu's v3.1 row records the same shape from the OpenCode side, and his
client split is now merged, which is the first time an adopter's platform fix reached the shared
package instead of a Jira comment. My own v3.1 "needed author?" is an unambiguous **yes**. On the
evidence in this file the `/morning` core has still not cleared the L2 bar, and recording that
plainly is worth more than a green row.

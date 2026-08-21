# Morning Loop — Modifications Menu

A browsable catalog of changes squad members have made to their own morning loop, in a format you (or your Claude / Cursor / OpenCode agent) can scan and adopt piece by piece.

**Why this file exists.** Adoption worked; sharing the improvements didn't. Good changes were trapped in personal repos and Jira comments, so nobody could try anyone else's. This is the menu. Read it, or hand it to your agent, and pick the mods that fit your role, client, and OS.

## How to use it

- **Browsing yourself:** skim the table below, then read the cards for the ones marked "applies to" your role/client.
- **Handing it to your agent:** paste this into your morning-loop repo and say:
  > "Read `MODIFICATIONS.md`. I'm a `<role>` on `<Claude Code / Cursor / OpenCode>`, `<macOS / Windows>`. List the mods that apply to me, ranked by benefit, and for each tell me whether it's config-only or needs a file change. Then help me adopt the ones I pick."
- **Adopting a mod:** each card has a **How to adopt** block. Config-only mods are safe to try immediately. Anything touching the shared `/morning` command should stay a personal override until it's folded into the package (see the last section).

## The menu

| # | Mod | Type | Applies to | Status | Benefit in one line |
|---|-----|------|-----------|--------|---------------------|
| 1 | Confluence meeting-notes source | config | all | ✅ in package | Meeting notes with no Granola, works on every client/OS |
| 2 | Namespaced per-user config resolution | command | all sharing a repo | ✅ in package (v2) | `/morning` finds `agent-manager-config.<you>.yml` |
| 3 | `routine_health` self-check | signal + config | anyone with a scheduled pre-run | ✅ in package (v2) | Catches silent scheduler failures (checks the END deliverable exists) |
| 4 | Squad-scope guard | command override | anyone in the shared KM Jira project | ✅ in package (v2) | Stops other-squad tickets leaking into your plan |
| 5 | Cloud routine (unattended, laptop-off) | scheduling | all | ✅ in package (v2) as the `schedule.backstop` | Loop runs and notifies you without your machine on |
| 6 | Windows / PowerShell scheduled pre-run | scheduling | Windows | 🟢 personal | launchd pendant for Windows Task Scheduler |
| 7 | Cursor adapter | client port | Cursor users | 🟢 personal | Run the loop in Cursor (no Claude Code) |
| 8 | OpenCode install + `install.sh` | client port | OpenCode users | 🟢 personal | Fixes the half-adopt trap (commands never copied) |
| 9 | `ticket_brief` engineer drafter | new skill | engineers | 🔶 proposed | First dev-side drafter (kickoff brief for new/stale tickets) |
| 10 | `meeting-debrief` `perspective` param | skill change | non-PO roles | 🔶 proposed | Debrief from your role's angle, not stakeholder framing |
| 11 | `decision_log_sync` | config + skill | Scrum Masters / anyone owning a decision log | 🟢 personal | Decision log stays current, auto-reconciled before retro |
| 12 | `daily-overview` / mm-digest as `daily_spine` | config | PO/POC with an existing daily | ✅ in package (v2) | Map the spine to your own sense tool instead of `/standup` |
| 13 | Day-boundary timezone | config | anyone outside Berlin time | ✅ in package (v2) as `owner.timezone` | "New day" matches your morning, not CET midnight |
| 14 | **Proactive delivery** (RUN→DELIVER→NOTIFY→HEALTH) | command + config | **all, this is the headline v2 change** | ✅ in package (v2) | The full brief reaches you every morning with no trigger and, by default, no signup |
| 15 | MCP preflight check | command | all | ✅ in package (v2) | Names which sources are degraded *before* sensing, so a permission gap stops looking like a broken loop |
| 16 | Ceremony capture writes files | command + config | anyone with a capture KR | ✅ in package (v2) | Sensed meetings become artifacts instead of being reasoned about and discarded |
| 17 | `install.sh` bootstrap + client matrix | tooling | Claude Code / Cursor / OpenCode | 🔶 proposed | Fixes the half-adopt trap (commands never copied into an active dir) |
| 18 | `ticket_brief` engineer drafter | new skill | engineers | 🔶 proposed, **biggest remaining gap** | The package still ships zero drafters for the three devs using it |

Status key: ✅ in the shared package · 🔶 proposed for the package (use as personal override for now) · 🟢 personal (documented here, adopt if it fits you).

---

## The cards

Each mod follows the same shape so it stays scannable and machine-parseable.

### 1. Confluence meeting-notes source
- **Author:** Xitong Deng, Maria Sommer (independently) · **Client/OS:** any
- **What:** Read meeting notes from the shared Confluence folder (`E CRM Events & Meetings`, space `SPEC`), diffed against a processed-pages log, instead of Granola.
- **Why:** Granola is per-person and tool-specific and was the single most-cited adoption blocker. Confluence notes are already posted, already deduped, and readable by every client through the Atlassian MCP.
- **Type:** config · **Applies to:** all · **Status:** ✅ folded into the package (`meeting_source:` in the config template).
- **How to adopt:** set `meeting_source.type: confluence_folder` in your config (it's the default). Point `processed_log` at a path in your workspace. Done.
- **Source:** KM-13612 comments (Xitong 2026-07-22, Maria 2026-07-08).

### 2. Namespaced per-user config resolution
- **Author:** Maria Sommer · **Client/OS:** any (matters when several people share one repo)
- **What:** `/morning` resolves `agent-manager-config.<user>.yml` first, falling back to the default path, so a shared repo doesn't force everyone onto one config.
- **Why:** the command hard-codes `06-skills/skills/agent-manager-config.yml`, so the namespaced copy ADOPT-MORNING recommends is never picked up. Raised twice, still workaround-only.
- **Type:** command · **Applies to:** anyone sharing a repo · **Status:** 🔶 proposed for the package.
- **How to adopt now:** a thin personal command override that points to your config path, leaving the shared command untouched.
- **Source:** KM-13612 (Maria 2026-07-07, re-raised 2026-07-20; +1 Xitong).

### 3. `routine_health` self-check
- **Author:** Maria Sommer · **Client/OS:** any with a machine-dependent scheduled pre-run
- **What:** a daily sense step that checks each monitored scheduled task AND that its END deliverable actually exists (e.g. the Mattermost post got posted), not just that a job ran. Fires a diagnosis draft only on a miss.
- **Why:** Maria's Monday supporter briefing silently failed twice; the cloud half succeeded so output-page checks looked healthy while the real deliverable was missing.
- **Type:** signal + config · **Applies to:** anyone with scheduled pre-runs · **Status:** 🔶 proposed for the package.
- **How to adopt now:** add a `routine_health` routing rule (signal `daily`, bucket `draft`) pointing at a task list + the END artifact path to verify.
- **Source:** KM-13612 (Maria 2026-07-13, 2026-07-20).

### 4. Squad-scope guard
- **Author:** Maria Sommer · **Client/OS:** any
- **What:** decision candidates sourced from the shared KM Jira project must be JQL-verified as members of your current sprint/board before they surface in the plan.
- **Why:** ticket-pattern matching alone pulled the same two other-squad tickets into her plan twice.
- **Type:** command override · **Applies to:** anyone in the shared KM project · **Status:** 🔶 proposed for the package.
- **How to adopt now:** add a mandatory verification step in your override that runs a scoped JQL (`sprint in openSprints() AND ...`) before surfacing any KM ticket.
- **Source:** KM-13612 (Maria 2026-07-13, 2026-07-20).

### 5. Cloud routine (unattended, laptop-off)
- **Author:** Chris Gamrot · **Client/OS:** any (runs in the cloud)
- **What:** the loop set up as a Claude Code cloud routine (Atlassian MCP, read-only, KM-scoped) on a weekday cron, delivering its output and a push notification instead of relying on a local scheduler.
- **Why:** the local scheduler only fires when the laptop is on and VPN is up, which is why every adopter is stuck at "Assisted." The cloud routine survives the laptop being off, so it actually runs without you remembering.
- **Type:** scheduling · **Applies to:** all · **Status:** 🟢 personal, proven. See `RUN-AND-NOTIFY.md` for the standard being built from this.
- **How to adopt now:** follow `RUN-AND-NOTIFY.md`. Caveat: a cloud routine can't read the Lab-GitLab package files, so the loop logic has to live somewhere cloud-reachable (that's the open structural fix).
- **Source:** KM-13612 (Chris 2026-07-18).

### 6. Windows / PowerShell scheduled pre-run
- **Author:** Maria Sommer · **Client/OS:** Windows
- **What:** a `run-prep.ps1` invoking `claude --print "/morning --prep" --permission-mode acceptEdits`, registered via `Register-ScheduledTask` (weekdays 08:00), as the Windows pendant to the macOS `run-prep.template.sh` + launchd.
- **Why:** the shipped script is zsh + launchd, macOS-only.
- **Type:** scheduling · **Applies to:** Windows · **Status:** 🟢 personal.
- **How to adopt:** ask Maria for `run-prep.ps1`. Two gotchas: force UTF-8 output encoding when logging (else mojibake), and prefer `Register-ScheduledTask` over `schtasks` for quoting.
- **Source:** KM-13612 (Maria 2026-07-07).

### 7. Cursor adapter
- **Author:** Daniel Blam · **Client/OS:** Cursor, Windows
- **What:** the loop as a Cursor skill (`~/.cursor/skills/morning-loop/SKILL.md`) + a workspace rule (`morning` / `morning prep`) + a YAML config, same sense → plan → gate → draft contract, no Claude Code.
- **Why:** proves Claude Code is not required; the loop logic ports cleanly.
- **Type:** client port · **Applies to:** Cursor users · **Status:** 🟢 personal.
- **How to adopt:** ask Daniel Blam for the skill + rule + config paths. Map `daily_spine` to your existing daily-overview rather than full `/standup`.
- **Source:** KM-13612 (Daniel Blam 2026-07-07/08).

### 8. OpenCode install + `install.sh`
- **Author:** Xitong Deng · **Client/OS:** OpenCode
- **What:** a bootstrap that copies command files into the active commands dir, creates/symlinks the skills dir, and ends with a "type /morning to test" verification, plus a client-portability matrix (Claude Code / Cursor / OpenCode use different command dirs).
- **Why:** it's easy to half-adopt: working config + drafts + run-log but `/morning` itself doesn't run because command files were never copied out of the package. Three adopters hit this independently.
- **Type:** client port / tooling · **Applies to:** OpenCode users (matrix helps everyone) · **Status:** 🔶 proposed for the package.
- **How to adopt now:** ask Xitong for his symlink setup; a shared `install.sh` is the proposed package fix.
- **Source:** KM-13612 (Xitong 2026-07-22).

### 9. `ticket_brief` engineer drafter
- **Author:** Xitong Deng · **Client/OS:** any
- **What:** a dev drafter that writes an implementation-kickoff brief for tickets newly In Progress or stale 3+ days. The package ships no engineer drafter at all, so he wrote his own.
- **Why:** three developers adopted the loop and zero drafters served them. This is the biggest v2 gap.
- **Type:** new skill · **Applies to:** engineers · **Status:** 🔶 proposed as the first engineer drafter (pairs with Daniel Zhu's test-gen / PR-drafting asks).
- **How to adopt now:** ask Xitong for the drafter; route it on `jira_state`.
- **Source:** KM-13612 (Xitong 2026-07-22).

### 10. `meeting-debrief` `perspective` parameter
- **Author:** Xitong Deng · **Client/OS:** any
- **What:** a `perspective: owner-role` param on `meeting-debrief` so an engineer gets *my commitments, decisions that change my implementation, blockers I own* instead of the PO's stakeholder/escalation framing.
- **Why:** the skill self-describes as "calibrated for PO operations," which is wrong for non-PO adopters.
- **Type:** skill change · **Applies to:** non-PO roles · **Status:** 🔶 proposed for the package.
- **Source:** KM-13612 (Xitong 2026-07-22).

### 11. `decision_log_sync`
- **Author:** Maria Sommer · **Client/OS:** any
- **What:** a rule that diffs a rolling `decisions.md` against the sprint's Decision Log page daily, and drafts the full sprint-close reconciliation on the last business day before Review & Retro.
- **Why:** the decision log was complete and current exactly when it was needed at the retro. Her best-rated job.
- **Type:** config + skill · **Applies to:** Scrum Masters / decision-log owners · **Status:** 🟢 personal.
- **How to adopt:** ask Maria for the rule; Confluence writes stay behind the gate.
- **Source:** KM-13612 (Maria 2026-07-13, 2026-07-20).

### 12. `daily-overview` / mm-digest as `daily_spine`
- **Author:** Daniel Blam · **Client/OS:** any
- **What:** map the `daily_spine` slot to your own sense tool (his = `daily-overview`: Mattermost for-you + Jira reply lens + git WIP) instead of the PO `/standup`. Optionally complement with the services mm-digest for MM summaries.
- **Why:** `/standup` is built for KM squad PO work; a POC/support role needs "what needs *me* today," not "what should the squad ship toward OKRs."
- **Type:** config · **Applies to:** PO/POC with an existing daily · **Status:** 🟢 personal.
- **How to adopt:** set `daily_spine` to your sense skill; keep the same one-spine contract (don't run two).
- **Source:** KM-13612 (Daniel Blam 2026-07-07, 2026-07-16).

### 13. Day-boundary timezone
- **Author:** Daniel Blam · **Client/OS:** any outside Berlin time
- **What:** set the loop's day boundary to your timezone (his = Asia/Singapore, UTC+8) so "new day" matches your morning, not CET midnight.
- **Why:** the seen-log and "since last run" diffs were misaligned to the wrong day.
- **Type:** config · **Applies to:** anyone outside CET · **Status:** 🟢 personal.
- **How to adopt:** add a `timezone` field to your config and use it for the day boundary + seen-log.
- **Source:** KM-13612 (Daniel Blam 2026-07-07).

---

## Add your own mod (the template)

Copy this block, fill it, and add it as a new card + a menu row. Keep it to the same fields so the menu stays scannable and an agent can parse it.

```markdown
### N. <short name>
- **Author:** <you> · **Client/OS:** <Claude Code / Cursor / OpenCode · macOS / Windows>
- **What:** <one or two lines: what the mod does>
- **Why:** <the benefit / the problem it solves>
- **Type:** <config | command | signal | new skill | skill change | scheduling | client port>
- **Applies to:** <who benefits: role / client / OS> · **Status:** 🟢 personal
- **How to adopt:** <exact steps, or the file to copy and from whom>
- **Source:** <Jira comment / file path>
```

**Config-only vs shared-command changes.** Mark honestly whether your mod is config-only (safe for anyone to adopt) or touches the shared `/morning` command (must stay a personal override until folded in). This is the same contract adopters already follow in the ticket: "config-only change, no edits to your shared command."

## Fold-back into the package

Tomek (facilitator) triages the 🔶 proposed mods into the shared package on a cadence. When a mod is folded in, flip its status to ✅ here, note the config field or file it became, and the next person inherits it by default instead of rediscovering it. That triage is the KM-13612 "ship ≥1 improvement back to the shared package" deliverable.

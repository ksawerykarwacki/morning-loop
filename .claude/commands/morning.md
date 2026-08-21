---
description: "Agent-manager daily loop. Senses the day's context, plans which of your JTBD jobs are due, shows you the work + asks permission, then dispatches sub-agents to draft the automatable jobs and hands you a review/decision queue. Built on top of /standup. Two modes: --prep (unattended, read-only sense+plan) and interactive (default, the morning gate + dispatch)."
argument-hint: "[--prep for the unattended pre-run | empty for the interactive morning run]"
---

# Morning — Agent-Manager Daily Loop

This is the orchestration layer over `/standup`. `/standup` gathers context and ends with Next Best Actions. This command goes further: it **decides which of your documented JTBD jobs are due today**, **shows you the work before doing it**, **asks permission**, then **runs sub-agents on the automatable jobs** and gives you back a review queue plus a short "your turn" list.

It is the Quick Win #1 build from the JTBD capture — the single move that flips a cluster of Assisted jobs to Orchestrated. The routing, calendar, sprint cadence, and permission policy all live in the **agent-manager config** — read it first, every run. Do not hard-code anything that belongs there.

**Config resolution (in this order — first hit wins).** Never assume a single fixed path; several people share this repo and adopters have their own layouts:
1. `$MORNING_CONFIG` if set.
2. `<package-relative>/skills/agent-manager-config.<user>.yml` — the namespaced per-user copy `ADOPT-MORNING.md` recommends, where `<user>` is the OS username or the `owner.name` first token, lowercased.
3. `06-skills/skills/agent-manager-config.<user>.yml`, then `06-skills/skills/agent-manager-config.yml` (the default for this workspace).
4. If none resolve, **stop and say which paths you tried** — do not invent a config or fall back to defaults baked into this file.

## The contract (read before anything else)

1. **Sense, plan and deliver are unattended and read-only.** Phases 1–2 and the delivery step in 2b may run with no human present (that is the scheduled pre-run). They query, write local files, and deliver the brief to *you* on your own configured channel. Nothing else leaves the workspace.
2. **Work is gated.** Phase 3 (dispatch) never runs without the owner's explicit approval at the morning gate.
3. **Nothing leaves the workspace automatically.** Creating/editing a Jira issue, publishing Confluence, posting to Mattermost, or sending any external message is in `permissions.never_auto`. Drafts are produced locally; shipping each one is a separate, individually-confirmed action in the review queue. This holds even after the morning approval. Delivering the brief to your own configured channel is not one of these: it moves already-sensed read-only output to you and tells nobody else.
4. **A draft is not automation; a shipped-on-trigger job is.** Be honest in the run log about what actually ran autonomously vs. what you hand-triggered. This is the KR evidence trail.
5. **A silent failure is worse than no automation**, because you think you are covered. Every run ends by verifying its own end deliverable (Phase 2c) and says so.

---

## Mode select

Check `$ARGUMENTS`:
- **`--prep`** → run **Phase 0 → 2c**: preflight, sense, plan, write the plan file, **deliver the full brief**, notify, health-check, stop. This is what the scheduled pre-run invokes on weekday mornings. No dispatch, no questions (no human is present).
- **empty** (you run it when you sit down) → if today's plan file exists, **load it and skip to Phase 3**; otherwise run Phases 0–2c inline, then Phase 3. If the prep already delivered today's brief, do not re-send it — say so and move to the gate.

Resolve `{DATE}` = today (YYYY-MM-DD) **in `owner.timezone`** if set, not the machine's locale — "new day" must match the owner's morning. Load the config (resolution order above) and resolve all `paths`.

---

## Phase 0 — PREFLIGHT (30 seconds, before you sense anything)

Probe each MCP the run depends on with its cheapest read, and print a one-line status table **before** Phase 1. An adopter's first confusing failure is almost always a missing or misnamed tool permission, and a run that discovers this halfway through looks like a broken loop rather than a config gap.

| source | probe | if it fails |
|---|---|---|
| Atlassian | `getVisibleJiraProjects` | try direct Jira REST with the allowlisted token before declaring it degraded |
| Microsoft 365 | `get_me` | `attention_triage` cannot run **and delivery cannot send** — this is a hard finding, say so loudly |
| Amplitude | `get_amplitude_context` | pulse/metric signals degrade to "not checked", never estimated |
| Granola / meeting source | the configured `meeting_source` read | `transcript_new` cannot fire; note it |

Print: `PREFLIGHT: Atlassian ✅ · M365 ✅ · Amplitude ✅ · Granola ⚠️ degraded (reason)`. A **denied tool name is a different failure from an absent server** — distinguish them, because the fix differs (allowlist entry vs reconnect). If a probe fails on a *name*, check whether the allowlist holds a stale alias for that tool and name the correct one in your report. Degradations never abort the run; they narrow it honestly.

---

## Phase 1 — SENSE (read-only, reuses /standup)

Run your `daily_spine` skill (PO default: `/standup`) and capture its full output (meeting-notes sync + open commitments, product pulse, Every.to digest, Jira sprint board, goals/OKR coverage, ads check). Do **not** duplicate that logic here — invoke it. Key signals to carry forward:

- **New meeting notes** since the last run — from `meeting_source` in config (default: the shared Confluence notes folder, diffed against `meeting_source.processed_log`; a `granola`/`local_dir` source uses the same contract) → feeds the `transcript_new` signal.
- **Reconciled commitments ledger** (`paths.commitments_ledger`): `MINE` items with no ticket → your-turn / don't-drop; `WAITING_ON` past its chase window → unblock nudge; any `FUTURE` item whose trigger arrived today → surface in "Your turn"; `IDEAS` → weekly review only. This ledger is the cross-day memory — Step 1 of `/standup` reconciles it, this phase reads the result.
- **Pulse flags**: any experiment at significance or past its decision window → `metric_event` signal.
- **Jira board state**: tickets stale 3+ days, or one push from Done → `jira_state` signal.
- **OKR coverage map**: uncovered/thin KRs in the owner's lane → priority weighting for the plan.

If a source is unavailable (MCP not authenticated), note it and continue — never fabricate. Carry "carried from {date}" forward as `/standup` already does.

**Squad-scope guard (mandatory, not a reminder).** `KM` is a shared multi-squad project. Before any ticket surfaces in the plan — plan item, decision, or stale nudge — it must be **JQL-verified as in scope**, not pattern-matched from a ticket key or a summary that looks familiar. Run the scoped query (`sprint in openSprints() AND ...` on the configured boards, or the squad's `Products Targeted` filter) and drop anything that fails it. If a ticket matters but is out of scope, label it explicitly as another squad's rather than listing it as yours. Pattern matching alone has pulled other-squad tickets into a plan twice.

**Ceremony capture (KR 3.3 — the mechanism, not a nice-to-have).** For every new meeting the sense phase reads, **write it to `paths.meeting_notes_dir` as a file** before the run ends. Reasoning about a transcript inside the run and then discarding it is the exact failure mode that has been missing the ≥95% ceremony-capture bar: the meetings were sensed, they just never became artifacts. One file per meeting, named `{DATE}-{slug}.md`, with source attribution and a `conf:` marker on anything below transcript strength. Never attribute a quote to a named person from an NL summary — summaries paraphrase and their speaker attribution is unreliable.

---

## Phase 2 — PLAN (the manager brain)

Determine today's date context:
- **Weekday** (mon–sun).
- **Sprint phase**: if `sprint.prefer_jira`, use the openSprints() endDate from Phase 1's Jira pull to decide start-week / mid / end-week; else compute from `sprint.anchor_start` + `sprint.length_days`.

Walk every rule in `routing` and decide if it fires today:

| signal | fires when |
|---|---|
| `daily` | always (working day) |
| `calendar` | a `meetings` entry is exactly `prep_lead_days` away (respect its `sprint_phase` gate if set) |
| `sprint_event` | today is sprint start (`when: start`) or sprint end (`when: end`) |
| `transcript_new` | Phase 1 found a new transcript not yet debriefed |
| `metric_event` | Phase 1 pulse flagged significance / overdue read |
| `jira_state` | Phase 1 found stale or nearly-done tickets |

For each firing rule, build a **plan item**: `{job, skill, bucket, external_action, why-it-fired, est. time saved}`. Sort into the four buckets and write the **plan file** (`paths.plan_file`) using the layout below.

```markdown
# Morning Plan — {DATE} ({weekday}, sprint {n}/{len}, {phase})

## 🤖 Agent will draft (your review after)
- [ ] {job} — via `{skill}` — fires because {why} — ships to: {external_action or "local"}

## 🟡 Needs your decision
- {job} — {the decision, with the context the agent gathered}

## 🧠 Your turn (human-only)
- {today's meetings you run/contribute to; the judgment calls}

## ✅ Already done (read-only, sensed for you)
- Product pulse: {1-line health}
- Every.to: {n new / nothing new}
- Jira sprint: {counts; stale flags}
- Open commitments: {n carried}

## Run economics
- Jobs the agent can draft today: {n}  ·  est. time saved if you ship them: ~{x}h
```

**Feedback check (the shared-loop improvement trigger).** If a `feedback` block exists in config and `feedback.enabled`, check whether feedback is due: today ≥ `feedback.first_run` + `feedback.after_days`, and no feedback file for the current round exists in `feedback.collection_dir` (or `reminder_every_days` has elapsed since the last). If `first_run` is blank, stamp it (earliest run-log date or today) and write it back to config. When due, add a 🧠 item to the plan — "Give feedback on the morning loop (~5 min) → runs `feedback.skill`" — and, in interactive mode, offer to run it after the review queue. This is how each adopter's real use improves the one shared loop; it never blocks the run.

---

## Phase 2b — DELIVER (the brief goes to you; you don't go to it)

A plan file on a machine you are not sitting at helps nobody. After the plan file is written, **deliver the brief to `delivery.channel`** — every run, both modes. This is the step that makes the loop proactive instead of something you have to remember to trigger.

**Deliver with `delivery.notifier_script`.** One command, whatever the channel:

```
python3 05-automation/agent-manager/scripts/notify.py \
  --brief {paths.plan_file} --date {DATE}
```

**Zero setup is a hard requirement of this phase, not a preference.** A delivery step that needs an account is a step most people never complete, and an undelivered brief is worth exactly as much as no loop. `macos` is the default: a native notification plus the brief rendered as a local web page, nothing to sign up for, works offline. `mattermost` costs one webhook URL and reaches a phone.

- **Report the outcome from the receipt, not from the fact that you ran the command.** The script always writes `05-automation/agent-manager/delivery-receipts/{DATE}.json`, on success and on failure. On a non-zero exit, read the receipt's `error` field and surface it verbatim. A failed delivery summarised as "delivered" is the precise failure this phase exists to prevent.
- **The notification is one line**, carrying the counts and the single top item. Its job is to get you to open the brief, not to be the brief.
- **The brief itself is the whole update**, in the order below. Never a teaser with a link and nothing else. The script renders the plan file's markdown, so a well-written plan file becomes a well-formatted page: write the plan file properly and delivery takes care of itself.
- **`#id`.** The script numbers each brief and puts it in the title, which is what makes `morning loop #21` and `/brief 21` work later. Same date always reuses the same id, so a re-delivery never burns a number.

```
☀️ MORNING BRIEF — {DATE}   ({weekday}, sprint {n}/{len}, {phase})
Window: {lookback} · Sources: {preflight line, degradations named}

── STATE OF YOUR WORLD ──   (read this first)
{3-6 lines of synthesis, not a list: what actually moved, who is waiting on you,
 the one live decision. This is the part worth reading if you read nothing else.}

── TOP OF YOUR LIST ──
{the single most important item, with the why}

🤖 AGENT WILL DRAFT ({n})        — dispatch is gated; run /morning to approve
  1. {job} — fires because {why} — ships to: {external_action or local}

🟡 NEEDS YOUR DECISION ({m})
  1. {the decision} — {context gathered} — {what turns on it}

🧠 YOUR TURN ({k})
  - {meetings you run/contribute to; the judgment calls}

✅ ALREADY DONE (sensed for you)
  - Sprint: {counts; stale flags}   - Pulse: {1-line health}
  - Commitments: {n carried}        - Meetings captured: {n written to notes}

── FINDINGS THIS RUN ──
{anything no single source showed: contradictions between sources, corrections to
 previous runs, a chain that only appears when two signals are read together.
 If a prior run's claim is now wrong, say so plainly and say what replaced it.}

── HONESTY LINE ──
Truly autonomous this run: {what actually ran unattended}. Dispatch: gated.
Degraded sources: {list or "none"}. Nothing in this brief was fabricated.
```

Other channels behave the same way: `confluence_page` updates one rolling page in place, `mattermost_dm` sends the summary plus a link, `local_file` is the v1 behaviour and only works if you are at that machine.

**Delivery is not a `never_auto` action.** It sends already-sensed read-only output to the owner's own address. It decides nothing and tells nobody else. Posting a draft, creating a ticket, or replying to a human still happens only at the interactive gate.

**Never fail silently.** If the send tool is unavailable: save as a draft; if that fails too, write the brief to `paths.plan_file` and **state at the top of your final output that automated delivery failed and exactly which tool was missing**. A missing delivery is a finding, never a shrug.

## Phase 2c — NOTIFY + HEALTH (verify your own end deliverable)

**Notify.** One line on `notify.channel`, no more — its job is to get you to open the brief, not to be the brief:
```
☀️ Morning brief ready — {n} drafts, {m} decisions, {k} meetings. Top: {the one item}.
```

**Health (`health.enabled`).** Before the run ends, verify the **end deliverable exists**, not that the script exited 0:
1. The plan file was written for `{DATE}`.
2. **The brief was actually delivered** — confirm the sent item exists, don't assume the send call succeeded.
3. The notification was sent.
4. The previous scheduled run happened at all. If yesterday was a working day with no run-log line, **that is a silent miss** — report it today with the gap length.

Check both halves independently. The known trap is a two-stage routine where the first half succeeds, so an "did something run?" check reports healthy while the real deliverable never landed. On any miss, write a diagnosis (what was missing, the probable cause, the one fix) and alert on `health.alert_on_miss`.

In `--prep` mode: stop after 2c. Append one line to `paths.run_log`: `{DATE} prep: planned {n} drafts / {m} decisions (no dispatch) · delivered: {channel} {✅/❌ + reason} · health: {pass/miss detail}`.

---

## Phase 3 — DISPATCH + REVIEW (interactive only — the gate)

### 3a. Show the plan, ask permission
Print the four buckets from the plan file. Then ask, in one message:

> Here's today's plan. I can draft the 🤖 items now. Which should I run?
> **[a] all · [s] select · [n] none — just give me the decisions + my-turn list**
> (Reminder: I'll produce drafts locally. Nothing gets sent to Jira / Confluence / Mattermost until you approve each one in the review queue.)

Wait for the answer. This is the permission gate — do not dispatch before it. If `--prep` produced the plan hours ago, re-pull anything volatile (Jira board, new transcripts) so you're not acting on stale state; note if anything changed.

### 3b. Dispatch + self-check (on approval)
Each approved 🤖 item runs as a short **pipeline, not a single shot**. This draft → verify → revise loop is the rung-three step: the agent checks its own output so it reaches you good enough to ship, not something you send back.

1. **Draft.** A sub-agent runs the named `skill` with today's sensed context and writes its output to `paths.review_dir` as `{job-id}.md`.
2. **Verify (independent skeptic, per-check).** A *separate* agent — never the one that drafted it — resolves the job's rubric: `{paths.rubrics_dir}/{skill}.rubric.yml` extended by `_base.rubric.yml`, falling back to `_base` alone if no skill rubric exists. It grades the draft **check by check**, not with a vibe score — for each check it applies the grader contract *"Apply this single check to the artifact. Return pass | fail | n/a and one sentence why"* and defaults to `fail` when uncertain. Returns `{per_check: [{id, result, reason}], failed: [...], ready: bool}` where `ready` = **every applicable check passes**. Any `block`-severity fail (invented facts, ungrounded targets) = hard NEEDS-EDIT regardless of the rest. (See `rubrics/README.md` for the full grading contract.)
3. **Revise (at most `quality.max_revisions`).** If any check failed, hand the draft back to the skill with the **failed checks' statements + the verifier's one-line reasons** — the specific fixes, not "make it better" — then re-verify. Stop after `max_revisions`; never loop indefinitely.
4. **Label.** Tag the final draft `READY` (all checks pass) or `NEEDS YOUR EDIT` (a check still fails after revision), and write the per-check results + any residual failed checks into the top of the draft file so you see exactly what to fix.

**Scale rigor to risk.** If `quality.stricter_for_external` is set, any job whose `external_action` is not `none` (Confluence publish, Jira create, Mattermost post) gets **two independent verifiers**, and is marked ready only if **both** pass every check. Local-only drafts get one verifier.

Run independent items in parallel. Chained jobs (e.g. `sprint_package` = sprint-report → okr-tracker → ops-update → stakeholder-comms) run as a pipeline and are verified at the end of the chain.

Each item returns: what it produced, the **quality score + READY / NEEDS-EDIT**, the top residual issue if any, and the exact external action it would take if shipped.

### 3c. Review queue
Present results compactly:

```
REVIEW QUEUE — {DATE}   (self-checked · score/10 is the verifier's, not the drafter's)
🤖 Drafts ({n})
  1. ✅ GC update draft        9/10 READY       → .../{DATE}/gc_update.md  (would publish to GC Confluence · 2 verifiers cleared)  [approve & publish / edit / discard]
  2. ⚠️ Tickets from {meeting} 6/10 NEEDS EDIT  → .../{DATE}/meeting_debrief.md  (would create 3 KM tickets · issue: 1 ticket missing acceptance criteria)  [edit / approve each / discard]
🟡 Decisions ({m})
  - {experiment} hit significance: {result}. Recommend {ship/kill/iterate}. → your call
🧠 Your turn ({k})
  - {meeting} at {time} — prep brief: ...{DATE}/meeting_prep.md
  - {judgment call carried from commitments}
```

Lead the queue with READY items (least of your attention); for NEEDS-EDIT items name the specific issue so you know what to fix, not just that it's weak.

For each draft the user approves to ship, **then** perform the external action (create the Jira tickets, publish the Confluence page, etc.) — one at a time, confirming the target before each. This is the only place `never_auto` actions happen, and only with a fresh yes.

### 3d. Close the loop
Append to `paths.run_log`, honestly:
`{DATE} run: drafted {n} ({ready}/{n} READY first-pass; {r} auto-revised; {e}/{x} cleared the stricter external double-verify), shipped {s} ({which external actions}), decisions surfaced {m}. Failed checks this run: {check-id×count, e.g. quantified_claims×2, milestone_status_honest×1}. Truly-autonomous this run: {jobs that ran scheduled + passed every check + shipped without rewrite}.`

Track two things across runs: the **ready-without-edit rate** (the real signal the loop reached rung three) and the **failed-check histogram**. The check that fails most on a given skill is the precise target for the offline skill-improvement loop (`focused-skill-improvements.md`) — it now knows not just *which* skill is weak but *which check* to fix. That loop raises a skill's *baseline* quality; the verify stage here gates *each run's* output. Keep the two distinct.

Then one-line confirm to the owner:
```
Morning loop done. Drafted {n}, you shipped {s}, {m} decisions on your plate, {k} meetings today.
Top of your list: {the single most important your-turn / decision item}.
```

---

## Notes
- **Reuse, don't reinvent.** Phase 1 is `/standup`. The drafters are existing skills (`growth-circle-update`, `meeting-debrief`, `sprint-plan`, `backlog-analysis`, `sprint-report`, `okr-tracker`, `ops-update`, `stakeholder-comms`). This command only orchestrates them.
- **Lead-by-example + L2.** Keep owner-specifics in your config file so the next adopter starts by copying a config, not editing this command. That copyability is what makes the job count toward the KR's reusability bar.
- **Honesty in the run log is the KR.** "Drafted but I hand-triggered and rewrote it" is tooling coverage, not automation. Only `--prep`-scheduled jobs that ship with no heavy rewrite count toward the 80%. Say so plainly.
- **v1 scope** = daily spine + meeting prep/debrief + GC/sprint package. `#22 ideation` and `#23 eval sheets` are deliberately out (no skill yet) — see the commented block in the config.
- **Failure handling.** A sub-agent that errors drops its item to the decision bucket with the error, never silently. A missing MCP downgrades that signal, it does not abort the run.

---
description: "Agent-manager daily loop. Senses the day's context, plans which of your JTBD jobs are due, shows you the work + asks permission, then dispatches sub-agents to draft the automatable jobs and hands you a review/decision queue. Built on top of /standup. Two modes: --prep (unattended: sense, plan, verify the findings, pre-draft the SOLVE work, deliver) and interactive (default: the ship gate + review queue)."
argument-hint: "[--prep for the unattended pre-run | empty for the interactive morning run]"
---

# Morning — Agent-Manager Daily Loop

This is the orchestration layer over `/standup`. `/standup` gathers context and ends with Next Best Actions. This command goes further: it **senses in parallel**, **decides which of your documented JTBD jobs are due today**, **verifies its own findings before they reach you**, **drafts the automatable work unattended**, and hands you a queue where the only question left is what to ship.

The run is a graph, not a queue. Independent work (the sense probes, the verifiers, the drafts) runs at once; the run converges only at the three points that genuinely need the whole set: the plan, the cross-source findings, and the brief. Where that matters is called out at each phase, because the shape is what fixed the failures, not the wording.

It is the build behind Quick Win #1 in `jtbd-tomek-2026-06-19.md` — the single move that flips a cluster of Assisted jobs to Orchestrated. The routing, calendar, sprint cadence, and permission policy all live in the **agent-manager config**. Read it first, every run. Do not hard-code anything that belongs there.

**Config resolution (in this order — first hit wins).** Never assume a single fixed path; several people share this repo and adopters have their own layouts:
1. `$MORNING_CONFIG` if set.
2. `<package-relative>/skills/agent-manager-config.<user>.yml` — the namespaced per-user copy `ADOPT-MORNING.md` recommends, where `<user>` is the OS username or the `owner.name` first token, lowercased.
3. `06-skills/skills/agent-manager-config.<user>.yml`, then `06-skills/skills/agent-manager-config.yml` (the default for this workspace).
4. If none resolve, **stop and say which paths you tried**. Do not invent a config or fall back to defaults baked into this file.

## The contract (read before anything else)

1. **Sense, plan, verify, draft and deliver are unattended and local.** Phases 1, 2, 2v, 2b, 2c and 2p may run with no human present (that is the scheduled pre-run). They query read-only sources, write local files, and deliver the brief to *you* on your own configured channel. Nothing else leaves the workspace.
2. **Shipping is gated, and shipping is the only thing that ever was.** Producing a draft in `agent-drafts/` is a local file write, so the prep may do it (`dispatch.predraft_in_prep`). Sending it anywhere never happens without Tomek's explicit, per-item yes at the gate. The old gate asked permission to *start work*; this one asks permission to *release it*, which is where the risk always lived.
3. **Nothing leaves the workspace automatically.** Creating/editing a Jira issue, publishing Confluence, posting to Mattermost, or sending any external message is in `permissions.never_auto`. Drafts are produced locally; shipping each one is a separate, individually-confirmed action in the review queue. This holds even after the morning approval. Delivering the brief to your own configured channel is not one of these: it moves already-sensed read-only output to you and tells nobody else.
4. **A draft is not automation; a shipped-on-trigger job is.** Be honest in the run log about what actually ran autonomously vs. what you hand-triggered. This is the KR evidence trail.
5. **A silent failure is worse than no automation**, because you think you are covered. Every run ends by verifying its own end deliverable (Phase 2c) and says so.

---

## Mode select

**Decide the mode mechanically, with a shell probe, before anything else — never by eyeballing `$ARGUMENTS`.** Instruction-level matching has failed twice on OpenCode (2026-08-20, 08-24): the argument arrives as `--prep\n` via `opencode run --command morning -- --prep`, and the trailing newline made it read as empty, so the scheduled prep silently ran the interactive path with no human present. Run this exact check first — it trims the argument and honours the out-of-band `MORNING_MODE` env the runner sets as a belt-and-braces override:

```bash
ARG="$(printf '%s' '$ARGUMENTS' | tr -d '[:space:]')"; if [ "$ARG" = "--prep" ] || [ "${MORNING_MODE:-}" = "prep" ]; then echo "MODE=prep"; else echo "MODE=interactive"; fi
```

The printed `MODE=` line is binding — obey it and never re-decide from the raw string. Trimming is harmless where the argument is already clean (Claude) and load-bearing where it is not (OpenCode).

- **MODE=prep** → run **Phase 0 → 1 → 2 → 2v → 2b → 2c → 2p**: preflight, fan-out sense, plan, verify the findings, **deliver the brief on time**, notify, health-check, then pre-draft the SOLVE work and update the same brief in place when the drafts land. This is what the scheduled pre-run invokes on weekday mornings. No shipping, no questions (no human is present).
- **MODE=interactive** (Tomek runs it when he sits down) → if today's plan file exists, **load it, load the pre-drafts, and skip to Phase 3**; otherwise run Phases 0 to 2c inline, then Phase 3. If the prep already delivered today's brief, do not re-send it, say so and move to the gate.

**Phase order matters and it is deliberate.** The brief is delivered *before* pre-drafting starts, so a run that dies mid-draft has still delivered everything it had, and the brief never waits behind the slowest thing in the run. Never reorder these to draft first.

Resolve `{DATE}` = today (YYYY-MM-DD) **in `owner.timezone`** if set, not the machine's locale. "New day" must match the owner's morning. Load the config (resolution order above) and resolve all `paths`.

---

## Phase 0 — PREFLIGHT (30 seconds, before you sense anything)

Probe each MCP the run depends on with its cheapest read, and print a one-line status table **before** Phase 1. An adopter's first confusing failure is almost always a missing or misnamed tool permission, and a run that discovers this halfway through looks like a broken loop rather than a config gap.

| source | probe | if it fails |
|---|---|---|
| Atlassian | `getVisibleJiraProjects` | try direct Jira REST with the allowlisted token before declaring it degraded |
| Microsoft 365 | `get_me` | `attention_triage` cannot run. Say so plainly; it does not affect delivery |
| Amplitude | `get_amplitude_context` | pulse/metric signals degrade to "not checked", never estimated |
| Granola / meeting source | the configured `meeting_source` read | `transcript_new` cannot fire; note it |

**Before the MCP probes, validate the config against reality.** Run:

```
python3 05-automation/agent-manager/morning-loop-share/scripts/doctor.py --json
```

It resolves every routing rule's named skill against the two real load paths (`<repo>/.claude/skills/<n>/SKILL.md` and `~/.claude/skills/<n>/SKILL.md`), plus `.claude/commands/` for rules that name a command rather than a skill. **A rule whose skill cannot resolve is disabled for this run and named in the preflight line**, because the alternative is what has been happening: the rule fires, finds nothing, reports no error, and the config keeps describing coverage that does not exist. It found a real name mismatch in this config on its first run (`sprint-report` where the installed skill is `sprint-reporting`), on a chain that next fires at a sprint boundary.

A missing MCP narrows the run and says so. **A missing skill used to do nothing at all, silently, which is worse.**

Print: `PREFLIGHT: Atlassian ✅ · M365 ✅ · Amplitude ✅ · Granola ⚠️ degraded (reason) · config ✅ 13/13 rules resolve`. A **denied tool name is a different failure from an absent server**, so distinguish them: the fix differs (allowlist entry vs reconnect). If a probe fails on a *name*, check whether the allowlist holds a stale alias for that tool and name the correct one in your report. Degradations never abort the run; they narrow it honestly.

---

## Phase 1 · SENSE (read-only, fan-out, one bounded context per probe)

**This phase is a fan-out, not a chain.** The probes below share no data with each other: the Jira board does not read the pulse, the ledger does not read Every.to, the inbox does not read the Decision Log. Running them end to end inside one growing context is what has been dropping the tail of the list, and the run log names the casualties by name: *"no Every.to; no ExoClick; commitments ledger still unreconciled (4th run)"*. The dropped work is always the last work in the chain. That is a topology symptom, not a diligence one, and no amount of trying harder fixes it.

So: **dispatch every enabled probe in `sense.probes` as a parallel sub-agent, one bounded context each.** Each probe reads its own source, returns its own contract, and never sees another probe's output. `/standup` remains the reference for *what* each probe gathers; this phase runs those steps concurrently instead of queueing them, and the probe that fails degrades alone.

### 1a · The probe contract (no probe ever returns prose)

Every probe returns exactly this shape. A probe that cannot fill it returns `status: unavailable` with a reason, never a softened claim.

```yaml
probe: {id}
status: ok | degraded | unavailable
reason: "{one line, only when not ok}"
claims:
  - claim: "{one assertion, one sentence}"
    evidence: "{VERBATIM excerpt of the row, field, cell or API value the claim rests on}"
    source: "{JQL / chart id / page id + section / experiment id / file path}"
    read_at: "{timestamp}"
    signal: jira_state | metric_event | transcript_new | calendar | none
```

**Every claim carries its evidence, copied verbatim.** Not summarised, not paraphrased, not "the page says". A probe that cannot produce the excerpt has not verified the claim and must return `unavailable` instead.

This is the direct fix for the loop's most repeated defect. Four separate runs matched on a **label** instead of on the **row**, and the fourth one corrupted a live Confluence read rather than a re-read of our own files: a KR label appeared on an M1 row reading `Done / Green`, so an M3 row reading `OPS Team Blocker` was reported as absent, and a correct earlier finding was retracted in error. A verbatim excerpt cannot be label-matched, because the wrong row does not contain the right words. If the excerpt does not contain the words the claim is making, the claim is wrong and the finding gate in Phase 2v will kill it.

### 1b · The probes

| probe | reads | must return | tier |
|---|---|---|---|
| `jira_board` | scoped JQL on `owner.jira_boards` only | in-scope sprint issues, status + age, stale 3+ days, one-push-from-done. Counts come from a `count` query or a complete slice, never from a truncated list | cheap |
| `commitments_ledger` | `paths.commitments_ledger` | reconciled MINE / WAITING_ON / FUTURE / IDEAS with true ages, and it **writes the reconciled file back**. Reconciliation is the deliverable, not a side effect | cheap |
| `pulse` | Amplitude charts | signups and other tracked metrics on **complete days only**. Today is partial and must be excluded: including it printed a false -12% against a true -2.5% on 08-18 | cheap |
| `experiments` | Amplitude **experiment objects** | per-experiment `enabled`, `experimentStartDate`, rollout percentage, exposure. Never infer experiment state from a Jira ticket. A Done ticket is not a launched experiment, and the 08-18 sprint-review correction turned on exactly this | standard |
| `meetings` | configured `meeting_source` | new transcripts since the last run, **and one file per meeting written to `paths.meeting_notes_dir`** before the probe returns, for meetings this loop owns. **Squad ceremonies are Maria's and are never captured here**, see below | standard |
| `decision_log` | Confluence, current **and** previous sprint page | decisions since the last run, plus the reverse check: consequential events with no log entry | cheap |
| `inbox` | Microsoft 365 | `attention_triage` buckets per its config block | cheap |
| `reading` | Every.to | new items or an explicit "nothing new" | cheap |
| `ads` | ExoClick | campaign status including `session_start` totals, last-touch and first-touch | cheap |

**Meeting capture is scoped, and the scope is a squad agreement, not a technical limit (set 2026-08-20).** Maria runs and records the squad ceremonies: standup, refinement, sprint review, retro and planning. **The loop does not write note files for those**, because a second unofficial record of a ceremony someone else owns creates two sources of truth and the loop's copy is the weaker one. It still *reads* her ceremony pages, which is where the Decision Log gap checks come from.

What the loop does capture is **every other meeting**: one-to-ones, design sessions, cross-squad calls, stakeholder conversations, anything with no other owner. Those have no scribe today and are exactly where commitments go missing. If a meeting's ownership is unclear, capture it and mark `owner: unconfirmed` in the file rather than silently skipping it.

**Squad-scope guard, enforced inside the probe.** `KM` is shared across squads. `jira_board` runs the scoped query and drops anything that fails it; a ticket that matters but is out of scope is labelled as another squad's, never listed as Tomek's. Pattern matching a key or a familiar-looking summary has pulled other-squad tickets into a plan twice. The guard lives in the probe because a guard applied after the fan-in is a guard applied to claims whose provenance has already been flattened.

**Model tiering.** Probes marked `cheap` are bounded extraction: run a JQL, read a chart, list an inbox, return the shape. They do not need the session model and `sense.probe_model_cheap` routes them down. Judgment lives in Phase 2 and in the verifiers, and that is where the expensive tokens belong.

### 1c · Fan-in (plain merge, no agent)

Collect the probe results, drop the nulls, and merge. This step is a few lines of deterministic work: concatenate the claim lists, tag each with its probe, carry the degradations into the preflight line. **Do not spawn an agent to combine probe output.** An agent asked to "synthesise the probes" re-summarises evidence it did not gather, which is how verbatim excerpts turn back into paraphrase, and paraphrase is the failure this whole phase exists to remove. Synthesis happens once, in the brief, over claims that have already survived verification.

One probe failing never aborts the run. It narrows it, honestly, and the preflight line says which.

### 1d · Routing-table skills — dispatched here too, not just planned in Phase 2 (added 2026-08-25, local fix, personal loop only)

**The fixed 9 probes above are not the only things this phase senses.** Every firing `routing` rule with `bucket: auto` and a non-null `skill:` (e.g. a personal daily-habit tool wired in via config) gets dispatched **right here, in this same fan-out**, as its own bounded-context sub-agent — not deferred to "mention it somehow" in Phase 2. Phase 2 plans what to do with sensed material; it does not itself go sense anything. A routing rule that never gets an explicit dispatch instruction is a routing rule the loop will treat as a hint rather than a command, and that is exactly how a named skill silently never runs.

Two things this dispatch must do, confirmed live as the two ways it silently failed when this instruction was missing entirely:

1. **Invoke the named `skill:` by its exact name — never substitute a different tool**, even one that seems topically related or is already connected. Resolve and run the literally-named skill or command (via the Skill/Command tool), the same discipline as the fixed probes. Confirmed live: `skill: ac-inbox` never actually ran because the model reached for an already-connected Mattermost MCP connector instead — the wrong tool, just a thematically close one. `doctor.py` only proves a named skill *resolves*; it does not prove a dispatch actually *invoked* it. If the named skill or command cannot be found or invoked for real, that is a degradation named in the preflight line, never a silent swap.
2. **Capture that skill's full output verbatim, unsummarised, the same as a probe's evidence.** Whether it gets compressed for the brief is a Phase 2 rendering decision (`render: bullet` vs `render: section`, see below) — it is not something to pre-summarise here. Confirmed live: without this, a 7-day timesheet grid and a categorized email digest both arrived at Phase 2 already thinned down to a sentence, so even a correct rendering decision downstream had nothing full left to render.

Route these through the same tiering as probes: routing-rule skills doing bounded extraction can use `sense.probe_model_cheap`; anything closer to judgment stays on the session model.

### 1e · Confluence direct mentions (personal addition, ported from v2's KM-14119 work, 2026-09-01)

**Not one of v3.1's 9 fixed probes, and not covered by anything else in this package** — Confluence mentions are explicitly named in `ATTENTION-TRIAGE.md` as a known gap, still unbuilt there. This is a real, validated feature from the old package, ported here as inline logic (like `routine_health`/`ceremony_capture` above), not delegated to an external skill.

Run `mention = "{owner's account ID}" order by lastmodified desc` via Confluence CQL — ground truth, independent of email-notification/read state, so it never misses a mention just because the notification email was already read or archived. Resolve the owner's account ID the same way `ac-timesheet` does: check `$JIRA_ACCOUNT_ID` first, else `atlassianUserInfo`.

**Filter out noise before surfacing anything:** skip any result whose title matches a known meeting-note pattern (`Daily`, `async Standup`, `Standup`, `Refinement`, `Planning`, `Design & Refine`, `Design Session`, `Retro`, `Retrospective`, `Review`, `Demo`, `AMA`) — those pages tag every attendee by design and are already covered by the `meetings` probe; including them here would just be the same content twice.

**Checkbox-aware, not a one-time-seed blanket rule.** Fetch each surviving result's full body (`getConfluencePage`) and check for Confluence task-list syntax (`- [ ]` / `- [x]`) near the mention:
- **Has a checkbox assigned to the owner:** a genuine open/closed action item with state that already lives in Confluence itself — don't invent a parallel "dismissed" flag. Re-check the page live every run and keep surfacing it for as long as the box is unchecked; stop the moment Confluence shows it checked, which the owner can do directly in Confluence, not only through this loop.
- **Plain mention, no checkbox found:** nothing to track — seed it once into `paths.processed_mentions` and never resurface it, same model as `meeting_source`'s dedup.

Wired in as the `confluence_mentions` routing rule (`bucket: auto`, `render: section` — a checkbox action item is exactly the kind of single, load-bearing fact that a bullet would still preserve fine on its own, but rendering it as its own section keeps it visually as prominent as the other personal-tool sections rather than getting lost in "Already done"). State file: `paths.processed_mentions`.

---

## Phase 2 — PLAN (the manager brain)

### 2·0 Every finding is typed. No finding is ever just prose.

The loop's job is to close things, not to describe them. A finding that gets re-listed day after day is a failure of this phase, not diligence. So before anything reaches the plan, classify it into exactly one of three types:

| type | means | the loop's obligation |
|---|---|---|
| **SOLVE** | The agent has everything it needs to do the work. | Put it in the draft bucket and **do it** on approval. Do not ask about it. |
| **ASK** | The agent knows the fix but is missing exactly **one** fact. | Ask **one closed question** whose answer unblocks the work. Never restate the problem instead. |
| **HUMAN** | Genuine judgment, relationship, or authority. | Hand it over cleanly with the context already gathered. |

**The ASK type is the important one and the easiest to get wrong.** "This is 21 days old and nobody has answered it" is not an ASK, it is a complaint. The ASK is *"Did KM-13557's redirect ship at 100% or was it rolled back?"* One fact, closed, answerable in a sentence, and on receiving it the agent proceeds without further instruction. If you cannot phrase the missing fact as a single closed question, it is not an ASK: either it is SOLVE (you already have enough) or HUMAN (it needs judgment, not a fact).

**Carried-item discipline is a convergence rule, and it has hard numbers.** A cycle that does not converge is the expensive failure mode: it pays, every single run, to rediscover the same dead end. This loop has run that failure in public. One config fix reached *"6th time of asking"*. The commitments ledger went unreconciled for four consecutive runs. Both were correctly detected every time and closed by nobody, which means detection was never the missing part.

So every carried item is deduped against **everything ever surfaced**, not against what is still open, and its carry count drives a forced move:

| carry count | the loop's obligation this run |
|---|---|
| 1 | Restate it with the carry count visible (`carried 1×`). |
| 2 | It must **escalate**: an ASK with a named person and a closed question, or a SOLVE. Restating it a second time in the same words is a failure of this phase. |
| 3 | **Auto-promote to SOLVE if the loop can act at all.** If the fix is a local file the loop may write (config, ledger, plan, notes), it stops being an ASK and gets done, per 2·0d. If it genuinely needs another human, it converts to a single named chase with a date. |
| 4+ | The carry count **is the finding**, and it leads the item. `carried 4×` in the brief means the loop has failed to convert this four times; say that plainly, and say what specifically is blocking conversion. |

The three legal moves at any count remain: **escalate**, **close** as overtaken by events (saying what overtook it), or **park** with an explicit date or trigger that suppresses it until then. A parked item does not carry. **Prune aggressively.** An item that no longer matters should be closed, not carried respectfully forever.


### 2·0b Check the Decision Log before escalating anything

The squad keeps a sprint Decision Log in Confluence (`decision_log` in config): every decision, dated, attributed, topic-grouped. It records **why the world is the way it is**; this loop detects **what changed**. Neither is any good without the other, and the gap between them has already produced a false alarm carried for four runs: two Amplitude events went dark, the loop called it broken instrumentation and attributed it to the wrong hypothesis, while the Decision Log recorded that the team had deliberately withdrawn those events days earlier.

So: **before any anomaly, regression, stall or missing-data finding is escalated, search the Decision Log for a decision that explains it.** If one exists, the finding is not "X is broken" but "your decision on {date} had this effect" — and usually that is either fine or a much more precise problem. Also never assert which KR, hypothesis or experiment a metric serves unless you have verified the ownership; guessing it is how a routine cleanup became a fake crisis.

The relationship runs both ways: a decision in the log with no corresponding change in the world is *also* a finding, and often a better one.

### 2·0c Sprint goal outranks everything

Sort the plan by what the squad committed to this sprint, not by age or severity. A sprint-goal item with no owner outranks a 133-day-old ticket, every time. State the sprint goal at the top of the plan and mark each item's relationship to it (`goal-critical` / `goal-adjacent` / `loose end`). Loose ends still get surfaced, because they are how work rots, but they sit below the goal and they are candidates for pruning rather than for attention.


### 2·0d The loop repairs its own configuration

A finding the loop can fix and instead describes is not a finding, it is a chore the loop handed back to you. `write_local_files` has always been in `unattended_allowed`, and `agent-manager-config.yml` is a local file, so a stale config value was never blocked by the permission policy. It was blocked by nothing at all, and it was reported six times.

**When a config value is demonstrably stale and the correct value is verifiable from a live source, apply the fix and log the diff.** Concretely:

1. **Verify the new value** from the source, with a verbatim excerpt, exactly like a probe claim. The current Decision Log page id is whatever the live Confluence search returns for the current sprint, not what looks right.
2. **Edit the config in place**, one value per fix.
3. **Record the before and after in the run log**, in the form `config: {key}: {old} -> {new} ({how it was verified})`. The repo is under git, so any bad edit is one `git diff` from being seen and one `git checkout` from being gone.
4. **Never self-edit these**: `permissions`, `delivery`, `schedule`, and `sprint.anchor_start`. The safety contract, the delivery contract and the cadence anchor are Tomek's. A loop that widens its own permissions is not a loop worth running.

If the correct value cannot be verified, it stays an ASK with a closed question. Guessing a config value is worse than a stale one, because a stale value fails loudly and a wrong one fails quietly.


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

**Rendering a `bucket: auto` rule's already-sensed output — invocation happened back in 1d, this is only about how it appears in the brief (added 2026-08-25, local fix, personal loop only — proposed upstream on KM-14354, not yet part of the shared package).** An optional `render:` field on the rule controls this. Default is `render: bullet` — a one-line summary folded into "Already done," fine for anything that's genuinely a single fact (a count, an "N new"). Set `render: section` on a rule whose 1d output is multi-item or structured (a table, a categorized list, several distinct entries): folding that into one bullet silently discards the individual items that made the job worth running.

**This config currently has exactly five `render: section` rules — `timesheet_grid`, `email_digest`, `mattermost_inbox`, `blocked_ticket_watch`, `confluence_mentions` — and the template below names their sections explicitly rather than describing a generic loop, on purpose (2026-08-26, extended 2026-09-03 per KM-14354 when `blocked_ticket_watch` was found still folded into a bullet despite carrying `render: section` in config).** A generic "one heading per render:section rule, figure out the rest" instruction was tried first and did not hold on a real unattended run — the plan file still folded all three into "Already done" bullets despite the rule and the instruction both being correctly in place, confirmed by comparing a forced/prompted re-test (worked) against the next real scheduled run (didn't). Named, concrete placeholders are what actually held reliably for the equivalent problem in the old v2 package — so this local fix trades genericity for reliability on purpose. If a sixth `render: section` rule gets added later, add its own named heading here the same way rather than trusting a loop-shaped instruction to cover it.

**These five headings are mandatory whenever their rule fires — never optional, never replaced by a bullet, regardless of how routine or quiet that day's output is.** Before writing "Already done," check off `timesheet_grid` / `email_digest` / `mattermost_inbox` / `blocked_ticket_watch` / `confluence_mentions` against this list — if any fired in 1d, its full output goes ONLY in its own named heading below, never also (or instead) as a line in "Already done." A quiet day ("nothing needs a reply", "nothing blocked") still gets its full heading, just with less under it — quietness is not a reason to compress it back into a bullet. `blocked_ticket_watch` and `confluence_mentions` in particular will often have nothing to report most days — that quiet result still gets its own heading, not silence.

```markdown
# Morning Plan — {DATE} ({weekday}, sprint {n}/{len}, {phase})

**Sprint goal:** {the goal, verbatim from the sprint} → {on track / at risk, and the one reason}

## 🤖 SOLVE — agent does these on your approval ({n})
- [ ] {job} · via `{skill}` · {goal-critical|goal-adjacent|loose end} · fires because {why} · ships to: {external_action or "local"}

## ❓ ASK — one question each, and the agent proceeds ({m})
- **{the closed question}** → ask {person} · unblocks: {what the agent will then do} · {carried N× if >1}

## 🧠 HUMAN — judgment, relationship, or authority ({k})
- {the item} · {context already gathered so you don't start cold}

## 🗑️ Closed / parked this run
- {item} · closed, overtaken by {what} · or · parked until {date/trigger}

## ✅ Already done (read-only, sensed for you)
- Product pulse: {1-line health}
- Every.to: {n new / nothing new}
- Jira sprint: {counts; stale flags}
- Open commitments: {n carried}
{one bullet per fired `bucket: auto` rule with render: bullet (the default) ONLY — never timesheet_grid/email_digest/mattermost_inbox/blocked_ticket_watch/confluence_mentions, those never appear here, not even as a summary line}
{if any of the five named render:section rules did NOT fire today (signal didn't match), say so explicitly here in one line each — e.g. "ac-inbox: not run this signal" — never just silently absent}

## 📊 `ac-timesheet` — timesheet_grid (skip this whole heading only if the rule didn't fire today)
{the rule's full 1d output, verbatim — the grid, Rippling status, zero-hour/done-ticket offers, all of it}

## 📧 `ac-email-digest` — email_digest (skip this whole heading only if the rule didn't fire today)
{the rule's full 1d output, verbatim — every category, every item, not a count}

## 📬 `ac-inbox` — mattermost_inbox (skip this whole heading only if the rule didn't fire today)
{the rule's full 1d output, verbatim — needs-reply list and FYI list both, not a channel count}

## 🔓 `ac-blocked-watch` — blocked_ticket_watch (skip this whole heading only if the rule didn't fire today)
{the rule's full 1d output, verbatim — new comments on BLOCKED tickets, or "nothing new on blocked tickets" if quiet}

## 📌 Confluence Mentions — confluence_mentions (skip this whole heading only if the rule didn't fire today)
{every open checkbox action item (re-checked live) plus a note of any newly-seeded plain mentions this run — or "nothing open" if there are open checkboxes to report but none currently unchecked}

## Run economics
- Jobs the agent can draft today: {n}  ·  est. time saved if you ship them: ~{x}h
```

**Feedback check (the shared-loop improvement trigger).** If a `feedback` block exists in config and `feedback.enabled`, check whether feedback is due: today ≥ `feedback.first_run` + `feedback.after_days`, and no feedback file for the current round exists in `feedback.collection_dir` (or `reminder_every_days` has elapsed since the last). If `first_run` is blank, stamp it (earliest run-log date or today) and write it back to config. When due, add a 🧠 item to the plan — "Give feedback on the morning loop (~5 min) → runs `feedback.skill`" — and, in interactive mode, offer to run it after the review queue. This is how each adopter's real use improves the one shared loop; it never blocks the run.

---

## Phase 2v · VERIFY THE FINDINGS (runs after PLAN, before DELIVER)

The drafts have been verified against rubrics since v2. The **brief** has not, and the brief is the thing you actually read. Every correction in the run log is a finding that went out unchecked: the false alarm on withdrawn Amplitude events carried for four runs, the retraction of a correct earlier finding, the -12% that was really -2.5%. Verification was applied where it was cheap to add, not where the errors were.

So before the brief is delivered, **every claim that asserts a status, a number, a change, or an absence goes through a grounding gate.** This is a router, not a blanket pass: descriptive and low-risk claims skip it, and the expensive treatment is reserved for the shapes that have actually been wrong.

### The gate

Dispatch verifiers in parallel, one per claim, on `quality.verifier_model`. A verifier sees **only** the claim, its evidence excerpt, and its source. It never sees the plan, the brief, or the agent that produced the claim. Its job is to kill the claim, not to appreciate it.

**The verifier re-runs the query itself. It never grades the claim against the probe's own output.** Checking a probe's claim against that probe's notes only establishes that the probe agrees with itself, which is how "KM-14064 has nine subtasks" reached a delivered brief when the true answer was six. The verifier goes back to Jira, Confluence or Amplitude and reads the row for itself. This holds however many claims are gated: **batching claims into one verifier call to save tokens silently turns the gate back into self-agreement**, so batch by source if you must, never by claim.

| the claim asserts | what the verifier must confirm | on failure |
|---|---|---|
| a **status** ("still BLOCKED", "reads Done") | the evidence excerpt contains the asserted status **and** identifies the row it came from by its own text, not by a label that appears elsewhere on the page | KILLED |
| a **number** | it came from a `count` query or a complete slice, and any per-day rate excludes today's partial day | KILLED |
| an **absence** ("no ticket exists", "the row is not there") | the query that *would* have found it is stated, and it was actually run this session. An absence claimed from a truncated list is not an absence | DOWNGRADED to "not found by {query}" |
| a **change** ("went dark", "stalled", "regressed") | the Decision Log was searched first, per 2·0b, and either explains it or does not | reframed as "your decision on {date} had this effect" |
| an **experiment state** | it came from the Amplitude experiment object, never from a Jira ticket status | KILLED |

**Two independent verifiers, both of which must clear it, for any claim that contradicts a previous run or contradicts a leadership-facing page.** Those are the two shapes with the worst track record: a retraction is the one claim type that damages trust in every prior brief at once, and a contradiction of Maria's or the squad's published page is the one most likely to be repeated out loud in a meeting. Scale rigour to the blast radius, the same way `quality.stricter_for_external` already does for drafts.

A **KILLED** claim never reaches the brief. It is logged in the run log as `killed: {claim} ({why})`, because a claim the loop generated and then rejected is real evidence about the loop and is exactly what the offline skill-improvement pass needs.

### Cross-probe findings (this is where the FINDINGS section comes from)

The probes ran blind to each other, so contradictions between them are visible only here, and they are the most valuable output the loop produces. Compare surviving claims across probes and surface:

- **Two sources disagreeing.** The sprint-review page assessing the goal `Reached` while the Amplitude experiment object reads `enabled: false, percentage: 0` is the canonical case, and it was the run that justified this whole phase.
- **A decision in the log with no corresponding change in the world**, and its reverse: consequential events with no log entry.
- **A prior run's claim that is now wrong.** Say so plainly, say what replaced it, and mark it as a correction rather than quietly restating the new version.

Do not spawn an agent per pair. Compare the claim lists directly, and dispatch an agent only for the candidate contradictions that survive that comparison.

---

## Phase 2b — DELIVER (the brief goes to you; you don't go to it)

A plan file on a machine you are not sitting at helps nobody. After the plan file is written, **deliver the brief to `delivery.channel`** on every run, in both modes. This is the step that makes the loop proactive instead of something you have to remember to trigger.

**Deliver with `delivery.notifier_script`.** One command, whatever the channel:

```
python3 {delivery.notifier_script} \
  --brief {paths.plan_file} --date {DATE} --channel {delivery.channel}
```

Pass `--channel` explicitly. The script also reads `delivery.channel` itself when
the flag is omitted, but a phase that says it delivers to `delivery.channel` should
name it in the command: until 2026-09-03 neither did, the script defaulted to
`macos`, and a config that said `file` produced a receipt that said `macos`.

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

🤖 DRAFTED FOR YOU ({n})         (drafting… on first delivery; this section is
                                  rewritten in place when the drafts land)
  1. {✅ READY | ⚠️ NEEDS EDIT} {job} → {path}
     fires because {why} · would ship to: {external_action or "local only"}
     {the one residual issue, if NEEDS EDIT} · {expires {time} today, if it does}

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
Truly autonomous this run: {what actually ran unattended}. Shipping: gated, nothing sent.
Claims killed by the finding gate: {n}. Degraded sources: {list or "none"}.
Nothing in this brief was fabricated, and every status/number claim carries a source.
```

Other channels behave the same way: `confluence_page` updates one rolling page in place, `mattermost_dm` sends the summary plus a link, `local_file` is the v1 behaviour and only works if you are at that machine.

**Delivery is not a `never_auto` action.** It sends already-sensed read-only output to the owner's own address. It decides nothing and tells nobody else. Posting a draft, creating a ticket, or replying to a human still happens only at the interactive gate.

**Never fail silently.** If the send tool is unavailable: save as a draft; if that fails too, write the brief to `paths.plan_file` and **state at the top of your final output that automated delivery failed and exactly which tool was missing**. A missing delivery is a finding, never a shrug.

## Phase 2c — NOTIFY + HEALTH (verify your own end deliverable)

**Notify — already done, do not send a second one here (clarified 2026-08-27, local fix, personal loop only).** The one-line notification this section describes is the *same* notification `delivery.notifier_script` already sent as part of Phase 2b — `notify.py`'s own delivery mechanism produces exactly this "counts + top item" line via the OS notification. **Do not call `osascript` or any other notification mechanism directly in this phase, and do not re-invoke the notifier script here either.** Confirmed live (2026-08-27): treating this as a separate step produced two real notifications for one brief, plus a delivery claim inside the session that didn't match what was actually on disk when checked immediately after — the same "confidently wrong" pattern as a fabricated file-write claim. If Phase 2b's delivery succeeded, this line's job is already satisfied; if it didn't, that's a Health finding below, not a second delivery attempt.

**Health (`health.enabled`).** Before the run ends, verify the **end deliverable exists**, not that the script exited 0:
1. The plan file was written for `{DATE}`.
2. **The brief was actually delivered** — confirm the sent item exists, don't assume the send call succeeded.
3. The notification was sent.
4. The previous scheduled run happened at all. If yesterday was a working day with no run-log line, **that is a silent miss**, so report it today with the gap length.
5. **Planned versus produced.** Count the SOLVE items in the plan against the files in `paths.review_dir`, and the files against those carrying a verify stamp. Report all three (`6 planned · 5 written · 0 verified`). Run #30 lost a planned item silently and nobody knew until the files were counted by hand.
6. **Yesterday's pre-drafts: how many were shipped?** A run of days where drafts are produced and never shipped is the same class of silent failure as a brief that never arrived, and it is the one this loop actually had. Report the streak (`0 shipped of 11 drafted across 4 days`) rather than waiting for someone to notice.

Check both halves independently. The known trap is a two-stage routine where the first half succeeds, so an "did something run?" check reports healthy while the real deliverable never landed. On any miss, write a diagnosis (what was missing, the probable cause, the one fix) and alert on `health.alert_on_miss`.

In `--prep` mode: continue to **Phase 2p**, then stop. Append one line to `paths.run_log`: `{DATE} prep: planned {n} SOLVE / {m} ASK / {k} HUMAN · delivered: {channel} {✅/❌ + reason} · pre-drafted {p} ({ready} READY, {skipped} skipped: {why}) · claims killed: {n} · config self-repairs: {list or none} · health: {pass/miss detail}`.

---

## Phase 2p · PRE-DRAFT (runs AFTER the brief is delivered, when `dispatch.predraft_in_prep`)

**The plan being right has never been the problem.** Across seven consecutive prep runs the loop planned 2 to 6 SOLVE items a day and dispatched **zero**, and on the last of them four of the five SOLVE items expired at ceremonies happening that same day. The work was correctly identified every morning and done by nobody. That is a fact about the gate, not about the plan, and no improvement to sensing or planning touches it.

So when `dispatch.predraft_in_prep` is true, the unattended prep **does the SOLVE work before you sit down**. The brief stops being a list of things that could be drafted and becomes a set of finished, graded drafts waiting for a yes.

1. Take every **SOLVE** item in the plan, up to `dispatch.max_predrafts`, ordered by `sprint goal first`, then by whether the item **expires today** (a refinement agenda for a meeting at 11:00 is worthless at 14:00).
2. Run each through the **existing Phase 3b pipeline unchanged**: draft, then independent per-check rubric verify, then at most `quality.max_revisions` revision, then label `READY` or `NEEDS YOUR EDIT`. `quality.stricter_for_external` still applies, so anything bound for Confluence or Jira still needs two verifiers to clear every check.
3. Write each to `paths.review_dir` exactly as dispatch does today, with the per-check results at the top of the file.

   **Verify and stamp each item as it finishes, never as a batch at the end. Update the brief after each one, not once at the end.** This is not a style preference, it is what a watchdog kill costs you.

   Run #30 (2026-08-21) is the worked example. It fired on time, delivered the brief unattended, and wrote 5 drafts between 08:31 and 08:40 before the watchdog killed it at 08:42. **None of the five carried a verify stamp and the brief still read `drafting…`**, because verification and the brief update were both batched behind the last draft. So a kill that should have cost one unfinished item cost the grading of all five, and v3's promise turned from *finished, graded drafts waiting for a yes* into *finished, ungraded drafts*, which is most of what v2 already did.

   Verified per item, the same kill leaves 5 graded drafts and one missing. Ordering also matters: **shortest job first inside the priority band.** In run #30 the largest artefact finished last and the smallest planned item never ran at all, and nothing reported its absence.
4. Skip, and say why, any item whose inputs are missing (a degraded probe, an unanswered ASK). A skipped item is listed in the brief as skipped, never silently dropped.
5. **Nothing ships.** Not one external action. `never_auto` is untouched by this phase, and a draft sitting in `agent-drafts/` has left the workspace exactly as much as it did before, which is not at all.

The brief then carries the drafts, so the 🤖 section reads:

```
🤖 DRAFTED FOR YOU ({n})         (nothing sent; each ships only with your yes)
  1. ✅ GC update            READY        .../{DATE}/gc_update.md      (would publish to GC Confluence · 2 verifiers cleared)
  2. ⚠️ Refinement agenda    NEEDS EDIT   .../{DATE}/refinement.md     (issue: 2 candidates missing acceptance criteria)  · expires 11:00 today
```

**This changes the honest accounting, in the direction that matters.** A job that was scheduled, drafted unattended, cleared every check, and shipped without a heavy rewrite is the definition the run log has been using for "truly autonomous" all along, and until now the loop has structurally been unable to produce one, because drafting could not happen unattended. Keep the bar exactly where it is. A pre-drafted item that Tomek rewrites before shipping is still tooling coverage, and the run log still says so.

**This phase runs after delivery, on purpose.** Drafting six items with independent verification takes far longer than sensing and planning, and the brief must not wait behind it: you would be reading yesterday's arrival time for the same information. So the brief goes out on schedule with the 🤖 section marked `drafting…`, and when the drafts land this phase **updates the same brief in place and re-runs the notifier with the same `{DATE}`**, which reuses the same `#id` rather than burning a new one.

**This second notifier call is silent, on purpose (local fix, 2026-09-09, KM-14354): pass `--no-notify`.** One OS notification and one browser tab per day is the standing preference — a second real ping just to say "drafts are ready" is more interruption than it's worth for a personal daily tool. `--no-notify` still re-renders the brief HTML and re-writes the receipt (status stays `sent`), so the underlying file is correct whenever you next look — it just doesn't push a second alert or reopen a tab. You find out the drafts are ready by running `/morning` when you sit down, same as any other day with nothing pre-drafted.

Two consequences worth stating plainly. **A watchdog kill mid-pre-draft costs nothing that was not already delivered**, because the plan and the verified findings left the building before drafting started. And **`dispatch.max_predrafts` is the cost ceiling**: it is what stops a bad morning from becoming an expensive one, so lower it before you conclude the loop is too costly to run.

---

## Phase 3 — SHIP + REVIEW (interactive only, the gate)

### 3a. The gate: ship, edit, or discard

**When the prep pre-drafted (the normal case), the gate is not "shall I start?" any more.** The work is done and graded. Print the drafts with their labels and their would-be external action, then ask, in one message:

> Here's what I drafted this morning. {n} READY, {m} need your edit.
> **[a] ship all READY · [s] select · [e] edit one with me · [n] none, just the decisions**
> (Each ship is confirmed individually against its target before it happens. Nothing has left the workspace yet.)

**Freshness before shipping, not before drafting.** A draft written at 07:52 and shipped at 11:00 rests on a four-hour-old read. Before any ship, re-verify the volatile claims **inside that draft** (ticket statuses, experiment state, counts) against live sources, and say what changed. If a claim moved, the draft goes back for one targeted revision rather than shipping with a number that was true at breakfast. Re-pull new transcripts and the board state too, since a new item may have appeared since the prep and belongs in today's plan.

**When there are no pre-drafts** (pre-drafting disabled, the watchdog fired, or new SOLVE items appeared since the prep), fall back to the original gate: show the four buckets and ask which 🤖 items to draft now, then run 3b. Say plainly which situation you are in. A gate that silently offers a smaller menu than usual reads as "quiet morning" when it actually means "the prep did not finish".

Wait for the answer either way. This is the permission gate, and nothing external happens before it.

### 3b. The draft pipeline (used by Phase 2p unattended, and here for anything new)
Each 🤖 item runs as a short **pipeline, not a single shot**, whether Phase 2p ran it unattended at 07:52 or you asked for it at the gate. One definition, two callers. This draft → verify → revise loop is the rung-three step: the agent checks its own output so it reaches you good enough to ship, not something you send back.

1. **Draft.** A sub-agent runs the named `skill` with today's sensed context and writes its output to `paths.review_dir` as `{job-id}.md`.
2. **Verify (independent skeptic, per-check).** A *separate* agent — never the one that drafted it — resolves the job's rubric: `{paths.rubrics_dir}/{skill}.rubric.yml` extended by `_base.rubric.yml`, falling back to `_base` alone if no skill rubric exists. It grades the draft **check by check**, not with a vibe score — for each check it applies the grader contract *"Apply this single check to the artifact. Return pass | fail | n/a and one sentence why"* and defaults to `fail` when uncertain. Returns `{per_check: [{id, result, reason}], failed: [...], ready: bool}` where `ready` = **every applicable check passes**. Any `block`-severity fail (invented facts, ungrounded targets) = hard NEEDS-EDIT regardless of the rest. (See `rubrics/README.md` for the full grading contract.)
3. **Revise (at most `quality.max_revisions`).** If any check failed, hand the draft back to the skill with the **failed checks' statements + the verifier's one-line reasons** — the specific fixes, not "make it better" — then re-verify. Stop after `max_revisions`; never loop indefinitely.
4. **Adjudicate disagreements with a third agent (`quality.disagreement_judge`).** When two verifiers run and they disagree on any check, **spawn a judge**. The judge sees the artifact, the disputed checks only, and both verdicts with their one-line reasons. It does not see which verifier said what, and it decides **per disputed check** with a reason. Its verdict is final.

   Two limits that keep the judge from becoming a rubber stamp:
   - **A `block`-severity fail that BOTH verifiers agree on is not disputed and is not sent to the judge.** Invented facts and ungrounded numbers never get a second hearing.
   - The judge rules on the checks in dispute, not on whether the artifact is good overall. "It reads well" is not an adjudication of `targets_flag_iren`.

   Disagreement is a normal outcome, not an error state. The 2026-08-19 GC update is the worked example: one verifier passed 17 of 17 and called the voice unmistakably Tomek's, the other failed `ready_to_ship` and `slf_fields_terse`. Those two checks are exactly what a judge should have settled, and the 15 they agreed on should never have reached it.

5. **Label.** Tag the final draft `READY` (all checks pass, after adjudication) or `NEEDS YOUR EDIT` (a check still fails), and write the per-check results, the judge's rulings, and any residual failed checks into the top of the draft file so Tomek sees exactly what to fix.

**Scale rigor to risk.** If `quality.stricter_for_external` is set, any job whose `external_action` is not `none` (Confluence publish, Jira create, Mattermost post) gets **two independent verifiers**, and is marked ready only if **both** pass every check. Local-only drafts get one verifier.

Run independent items in parallel. Chained jobs (e.g. `sprint_package` = sprint-report → okr-tracker → ops-update → stakeholder-comms) run as a pipeline and are verified at the end of the chain.

Each item returns: what it produced, the **quality score + READY / NEEDS-EDIT**, the top residual issue if any, and the exact external action it would take if shipped.

### 3c. Review queue
Present results compactly:

```
REVIEW QUEUE — {DATE}   (independently verified · the verdict is the verifier's, never the drafter's)
🤖 Drafts ({n})   {p} pre-drafted at {prep time}, {g} drafted just now
  1. ✅ GC update draft        READY       drafted 07:58 · .../{DATE}/gc_update.md
        would publish to GC Confluence · 2 verifiers cleared every check
        freshness: re-checked at the gate, no claim moved            [ship / edit / discard]
  2. ⚠️ Tickets from {meeting} NEEDS EDIT  drafted 08:04 · .../{DATE}/meeting_debrief.md
        would create 3 KM tickets · failed: acceptance_criteria_testable (ticket 2)  [edit / ship each / discard]
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
`{DATE} run: pre-drafted {p} unattended ({ready}/{p} READY first-pass; {r} auto-revised; {e}/{x} cleared the stricter external double-verify), drafted {n} more at the gate, shipped {s} ({which external actions}), decisions surfaced {m}. Claims killed by the finding gate: {n} ({claim: why}). Carried items converted: {closed}/{escalated}/{parked}, still carrying: {list with counts}. Config self-repairs: {key: old -> new}. Failed checks this run: {check-id×count}. Truly-autonomous this run: {jobs that ran scheduled + drafted unattended + passed every check + shipped without rewrite}.`

Track four things across runs, because each one points at a different repair:

| the number | what a bad value means | where the fix goes |
|---|---|---|
| **ready-without-edit rate** | the drafters are not yet shippable | the skill, via its failed-check histogram |
| **failed-check histogram** | one specific check fails most on one skill | `focused-skill-improvements.md`, which now knows *which check* |
| **claims killed at the finding gate** | the sense probes are producing claims they cannot ground | the probe's contract, usually a missing evidence excerpt |
| **pre-drafted but never shipped** | the loop is drafting work you do not want | the routing rules, not the drafters. This is the number that would have caught seven dead runs on day two instead of day fourteen |

The first two are about output quality, the last two about whether the loop is aimed at the right work. Keep them distinct; they have never had the same cause.

Then one-line confirm to Tomek:
```
Morning loop done. Drafted {n}, you shipped {s}, {m} decisions on your plate, {k} meetings today.
Top of your list: {the single most important your-turn / decision item}.
```

---

## Notes
- **The shape of the run is the design.** Independent work fans out (Phase 1's probes, the verifiers, the pre-drafts); work converges only where a step genuinely needs the whole set (the plan, the cross-probe findings, the brief). Two rules follow. Never spawn an agent to do plumbing: flattening probe results and comparing claim lists is deterministic work that costs nothing and cannot hallucinate. And never chain two steps because you typed them in that order: if the second does not read the first's output, the wait buys nothing and the tail of the queue is what gets dropped.
- **Reuse, don't reinvent.** Phase 1's probes are `/standup`'s steps, run concurrently. The drafters are existing skills (`growth-circle-update`, `meeting-debrief`, `sprint-plan`, `backlog-analysis`, `sprint-report`, `okr-tracker`, `ops-update`, `stakeholder-comms`). This command only orchestrates them.
- **Lead-by-example + L2.** Keep owner-specifics in `agent-manager-config.yml` so Arame/Xitong/Cynthia adopt by copying the config, not editing this command. That copyability is what makes the job count toward the KR's reusability bar.
- **Honesty in the run log is the KR.** "Drafted but I hand-triggered and rewrote it" is tooling coverage, not automation. Only `--prep`-scheduled jobs that ship with no heavy rewrite count toward the 80%. Say so plainly.
- **v1 scope** = daily spine + meeting prep/debrief + GC/sprint package. `#22 ideation` and `#23 eval sheets` are deliberately out (no skill yet) — see the commented block in the config.
- **Failure handling.** A sub-agent that errors drops its item to the decision bucket with the error, never silently. A missing MCP downgrades that signal, it does not abort the run. A failed probe is one missing section, not a failed run: the fan-in tolerates gaps by design and names them in the preflight line.
- **What v3 changed, and the evidence behind each.** SENSE fans out because a single long context was dropping the last items on its list. Findings are verified because four runs matched a label instead of a row and one of them retracted a correct finding. Carried items converge on a numbered ladder because a config fix reached its sixth ask. The prep pre-drafts because seven consecutive runs planned the right work and dispatched none of it. The loop repairs its own config because the permission to do so was always there and was never used. Each of these is a topology change, not a prompt change, which is why "be more careful next time" would not have fixed any of them.
- **Watch these two numbers before anything else.** *Pre-drafted but never shipped* tells you the loop is aimed at the wrong work; the fix is in the routing rules. *Claims killed at the finding gate* tells you the probes are asserting things they cannot ground; the fix is in the probe contract. Both are new in v3 and both are early warnings the old run log could not produce.

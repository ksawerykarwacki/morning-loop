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
6. **A verdict is computed, never claimed.** No agent in this run writes the words READY, VERIFIED or a rubric grid into a draft by hand. Grading is recorded as agent ids and per-check results in a stamp, and `trust.py` derives the verdict from them. On 2026-08-26 a full two-verifier grid rendered out of a session that had no subagents at all, and three drafts carried READY that nothing had checked. That failure is now structurally unavailable: READY is unreachable unless the stamp names verifier ids that exist, differ from the drafter, and differ from each other. If you find yourself typing a verdict, you are doing the thing that broke.

---

## Mode select

**Decide the mode mechanically before anything else, never by eyeballing `$ARGUMENTS`.** Instruction-level matching has failed twice on OpenCode (2026-08-20, 08-24): the argument arrives as `--prep\n` via `opencode run --command morning -- --prep`, the trailing newline made it read as empty, and **the scheduled prep silently ran the interactive path with no human present.** Run this first:

```bash
ARG="$(printf '%s' '$ARGUMENTS' | tr -d '[:space:]')"; if [ "$ARG" = "--prep" ] || [ "${MORNING_MODE:-}" = "prep" ]; then echo "MODE=prep"; else echo "MODE=interactive"; fi
```

The printed `MODE=` line is binding. Obey it and do not re-decide from the raw string.

**If the probe cannot run, fall back and say so in one line.** It is a compound command, and some sandboxes (Tomek's unattended prep among them) refuse those. Then take the mode from the argument with surrounding whitespace stripped, treating `--prep` and `--prep\n` as identical, and honour `MORNING_MODE=prep` if it is set. **Never treat a whitespace-only argument as empty**, which is the exact bug this replaces. Trimming is a no-op where the argument is already clean and load-bearing where it is not.

- **MODE=prep** → run **Phase 0 → 1 → 2 → 2v → 2s → 2b → 2c → 2p**: preflight, fan-out sense, plan, verify the findings, **deliver the brief on time**, notify, health-check, then pre-draft the SOLVE work and update the same brief in place when the drafts land. This is what the scheduled pre-run invokes on weekday mornings. No shipping, no questions (no human is present).
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
| Mattermost (only if `mattermost_triage.enabled`) | `get_team_info` | `mattermost_triage` cannot run. Say so on the MATTERMOST line; it does not affect delivery |

**One command per Bash call.** The unattended sandbox refuses compound commands, `find -exec`, and the project venv. Bare `python3` has no `httpx`, so anything needing it degrades silently to mock data rather than failing loudly.

**Before the MCP probes, validate the config against reality.** Run:

```
python3 05-automation/agent-manager/morning-loop-share/scripts/doctor.py --json
```

It resolves every routing rule's named skill against the two real load paths (`<repo>/.claude/skills/<n>/SKILL.md` and `~/.claude/skills/<n>/SKILL.md`), plus `.claude/commands/` for rules that name a command rather than a skill. **A rule whose skill cannot resolve is disabled for this run and named in the preflight line**, because the alternative is what has been happening: the rule fires, finds nothing, reports no error, and the config keeps describing coverage that does not exist. It found a real name mismatch in this config on its first run (`sprint-report` where the installed skill is `sprint-reporting`), on a chain that next fires at a sprint boundary.

A missing MCP narrows the run and says so. **A missing skill used to do nothing at all, silently, which is worse.**

**Then ask whether this run can grade what it is about to draft.** Independence is not always available: a session without subagents cannot produce an independent verifier, and the correct response is to say so before drafting, not to discover it at the stamp:

```
python3 05-automation/agent-manager/scripts/trust.py preflight \
  --routed {comma-separated routing ids firing today} --subagents {yes|no}
```

A non-zero exit means at least one job routed today would leave the workspace and cannot be independently verified this run. That is not a reason to abort: it is a reason to draft it, label it honestly, and never let it render READY. Carry the line into the preflight output, because a run that quietly downgrades its own grading is exactly the shape that cost a retraction.

Print: `PREFLIGHT: ... · config ✅ 13/13 rules resolve · trust ⚠️ 2 external jobs, no independent verifier available this run`.

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
| `mattermost` | Mattermost MCP, **read tools only**, only if `mattermost_triage.enabled` | buckets per the `mattermost_triage` block: mentions since the last run, the watchlist channels since the last run, threads where the owner is owed a reply or promised an action. The MCP exposes no unread state, so never claim "unread". Never call a Mattermost write tool, not even with the morning approval | cheap |
| `reading` | Every.to, only if `reading.enabled` is not false | new items or an explicit "nothing new" | cheap |
| ~~`ads`~~ | ExoClick | **off since 2026-09-24**: no ads running there. Do not run it, do not list ExoClick as a degraded source, do not report campaign status. The one exception is the leaked-token rotation in hygiene, which is a security item and stays until it is done. Re-enable only when it is back in `sense.probes` | n/a |

**Meeting capture is scoped, and the scope is a squad agreement, not a technical limit (set 2026-08-20).** Maria runs and records the squad ceremonies: standup, refinement, sprint review, retro and planning. **The loop does not write note files for those**, because a second unofficial record of a ceremony someone else owns creates two sources of truth and the loop's copy is the weaker one. It still *reads* her ceremony pages, which is where the Decision Log gap checks come from.

What the loop does capture is **every other meeting**: one-to-ones, design sessions, cross-squad calls, stakeholder conversations, anything with no other owner. Those have no scribe today and are exactly where commitments go missing. If a meeting's ownership is unclear, capture it and mark `owner: unconfirmed` in the file rather than silently skipping it.

**Squad-scope guard, enforced inside the probe.** `KM` is shared across squads. `jira_board` runs the scoped query and drops anything that fails it; a ticket that matters but is out of scope is labelled as another squad's, never listed as Tomek's. Pattern matching a key or a familiar-looking summary has pulled other-squad tickets into a plan twice. The guard lives in the probe because a guard applied after the fan-in is a guard applied to claims whose provenance has already been flattened.

**Model tiering.** Probes marked `cheap` are bounded extraction: run a JQL, read a chart, list an inbox, return the shape. They do not need the session model and `sense.probe_model_cheap` routes them down. Judgment lives in Phase 2 and in the verifiers, and that is where the expensive tokens belong.

### 1c · Fan-in (plain merge, no agent)

Collect the probe results, drop the nulls, and merge. This step is a few lines of deterministic work: concatenate the claim lists, tag each with its probe, carry the degradations into the preflight line. **Do not spawn an agent to combine probe output.** An agent asked to "synthesise the probes" re-summarises evidence it did not gather, which is how verbatim excerpts turn back into paraphrase, and paraphrase is the failure this whole phase exists to remove. Synthesis happens once, in the brief, over claims that have already survived verification.

One probe failing never aborts the run. It narrows it, honestly, and the preflight line says which.

---

## Phase 2 — PLAN (the manager brain)

### 2·0 Every finding is typed. No finding is ever just prose.

The loop's job is to close things, not to describe them. A finding that gets re-listed day after day is a failure of this phase, not diligence. So before anything reaches the plan, classify it into exactly one of three types:

| type | means | the loop's obligation |
|---|---|---|
| **SOLVE** | The agent has everything it needs to do the work. | Put it in the draft bucket and **do it** on approval. Do not ask about it. |
| **ASK** | The agent knows the fix but is missing exactly **one** fact. | Ask **one closed question** whose answer unblocks the work. Never restate the problem instead. |
| **HUMAN** | Genuine judgment, relationship, or authority. | Hand it over cleanly with the context already gathered. |

**Write the ASKs to a file he answers inline, not into the brief as prose.** This is the fix for the defect that has blocked the loop for a month: between 2026-08-28 and 2026-09-24 the loop asked 9 things and recorded 0 answers, not because he was unwilling but because answering meant a second trip to a terminal.

```
python3 05-automation/agent-manager/scripts/asks.py --date {DATE} render --in /tmp/asks-{DATE}.json
```

Each ask is `{question, why_it_matters, ask (who can answer), options[] OR recommendation, evidence[], carried}`. **`why_it_matters` is mandatory and names what changes depending on the answer**; if nothing changes it is not a blocker and does not belong in front of him. **Options appear only where the candidate answers change the outcome in materially different ways.** Where there is one defensible answer, drop the list, set `recommendation`, and the question becomes a confirmation. A one-item options list is refused. A clean run gets zero questions, and the file is still written, because absence and zero must not look identical.

**Every run, read last run's answers first and carry the rest:**

```
python3 05-automation/agent-manager/scripts/asks.py --date {DATE} carry --from {LAST_RUN_DATE}
```

An answered ask is **recorded, not just consumed**: draft it into the action queue as `kind: question` with `derived_from` pointing at the ask, so the answer reaches provenance and the circle closes. An unanswered one comes forward with its carry count incremented and enters the ladder below.

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

```markdown
# Morning Plan — {DATE} ({weekday}, sprint {n}/{len}, {phase})

**Sprint goal:** {the goal, verbatim from the sprint} → {on track / at risk, and the one reason}
**Confidence:** {the census line, verbatim from `trust.py claims census`}. Markers: [V] verified live, [R] reported, [I] inferred, [C] carried.

## 🤖 SOLVE — agent does these on your approval ({n})
- [ ] {job} · via `{skill}` · {goal-critical|goal-adjacent|loose end} · fires because {why} · ships to: {external_action or "local"}

## ❓ ASK — one question each, and the agent proceeds ({m})
- **{the closed question}** → ask {person} · unblocks: {what the agent will then do} · {carried N× if >1}

## 🧠 HUMAN — judgment, relationship, or authority ({k})
- {the item} · {context already gathered so you don't start cold}

## 🗑️ Closed / parked this run
- {item} · closed, overtaken by {what} · or · parked until {date/trigger}

## ✅ Already done (read-only, sensed for you)
- Product pulse: {1-line health. If the config lists `okr_kpis.pulse_always_print`, every metric in it is printed every day, each vs the prior 7 days}
- Season funnel: {only if the config lists `okr_kpis.season_funnel_always_print`: every KPI in that list, every brief, each with its baseline and target from the goals file. Never print the objective alone}
- Every.to: {n new / nothing new; omit the line when `reading.enabled: false`}
- Jira sprint: {counts; stale flags}
- Open commitments: {n carried}

## Run economics
- Jobs the agent can draft today: {n}  ·  est. time saved if you ship them: ~{x}h
```

**Feedback check (the shared-loop improvement trigger).** If a `feedback` block exists in config and `feedback.enabled`, check whether feedback is due: today ≥ `feedback.first_run` + `feedback.after_days`, and no feedback file for the current round exists in `feedback.collection_dir` (or `reminder_every_days` has elapsed since the last). If `first_run` is blank, stamp it (earliest run-log date or today) and write it back to config. When due, add a 🧠 item to the plan — "Give feedback on the morning loop (~5 min) → runs `feedback.skill`" — and, in interactive mode, offer to run it after the review queue. This is how each adopter's real use improves the one shared loop; it never blocks the run.

---

## Phase 2v · VERIFY THE FINDINGS (runs after PLAN, before DELIVER)

The drafts have been verified against rubrics since v2. The **brief** has not, and the brief is the thing you actually read. Every correction in the run log is a finding that went out unchecked: the false alarm on withdrawn Amplitude events carried for four runs, the retraction of a correct earlier finding, the -12% that was really -2.5%. Verification was applied where it was cheap to add, not where the errors were.

So before the brief is delivered, **every claim that asserts a status, a number, a change, or an absence goes through a grounding gate.** This is a router, not a blanket pass: descriptive and low-risk claims skip it, and the expensive treatment is reserved for the shapes that have actually been wrong.

### The gate

**Dispatch every sub-agent as `general-purpose`, never as the pinned types.** `sense-probe`, `claim-verifier`, `disagreement-judge` and `job-drafter` each declare a `tools:` list, and an agent with a `tools:` list gets **only** those tools: no MCP, and `ToolSearch` will not surface MCP inside it either. So a verifier of that type cannot re-query Jira, Confluence or Amplitude, which is the single thing a verifier exists to do. Verified 2026-09-07: 7 of 9 probes returned live evidence through `general-purpose`, and the only 2 that came back degraded were the 2 given a pinned type. Keep the no-write rules as prompt constraints, never as a `tools:` list.

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

### Record every claim that reaches the brief, so its marker is computed (V3-TO-V4 D6, D7)

The drafts have carried a provenance header since v3. The brief carries roughly 40 claims and got one verdict, and on the first v3 run the gate was pointed at 3 of about 40. Uniform presentation invites uniform trust. So **every claim that survives the gate and reaches the brief is recorded**, and trust.py, not you, decides its marker:

```
# Write to /tmp/claims-{DATE}.json, then pass the path. No heredocs in the prep sandbox.
python3 05-automation/agent-manager/scripts/trust.py --date {DATE} claims record --in /tmp/claims-{DATE}.json
# the file's contents, one entry per claim in the brief (killed ones too, with "killed": true):
[{"id": "{short slug}", "text": "{the claim as it reads in the brief}",
  "probe_agent": "{agent id of the probe that produced it}",
  "source": "{JQL / chart id / page id}", "read_at": "{YYYY-MM-DDTHH:MM, from the probe}",
  "verifiers": [{"agent_id": "{the verifier's agent id}", "requeried": "{what it re-ran}",
                 "at": "{YYYY-MM-DDTHH:MM}", "result": "pass"}],
  "derived_from": ["{claim ids, only when it has no direct source}"],
  "carried_from": "{brief #id, only when it comes forward from an earlier brief unchecked}"}]
```

It prints the **census line** and one **tag** per claim. The four markers, and the rule behind each:

| tag | marker | computed when |
|---|---|---|
| `[V hh:mm]` | verified | a verifier whose agent id is not the probe's own re-queried the source this run, and the time is recorded |
| `[R]` | reported | one source, read this run, not re-queried |
| `[I]` | inferred | derived from other claims, no direct source |
| `[C]` | carried | from an earlier brief, or read on an earlier day, and not re-checked today |

A claim with none of these comes back `[?]` and the census says `UNSOURCED`; fix it or drop it, never ship it tagged. **Only copy the tags trust.py printed.** An agent id you did not get back from a real dispatch is a fabricated verifier, which is the 2026-08-26 failure in a new place. Re-run `claims census` after any late correction, because the census line counts corrections too.

### Corrections propagate to the drafts, or nothing ships

**A claim killed or corrected after a draft was written does not stay in Phase 2v.** On 2026-08-26 the loop discovered mid-session that the Icebreakers experiment object existed, recorded the correction in the run log, and the GC update drafted **in that same session** still told the room in three places that it did not exist, naming two queries as evidence. Note the shape: that draft's stamp had *passed* `absence_names_its_query`. A false absence with provenance attached is the most dangerous output this loop can make, because the provenance is what earns belief.

So every correction, whenever it is learned in the run, is registered:

```
python3 05-automation/agent-manager/scripts/trust.py correct add \
  --was "{the claim as drafted, verbatim}" \
  --now "{what is actually true}" \
  --source "{where the correct value was read}"
```

This puts **every draft already stamped this session on `HOLD`** and names the ones whose text literally carries the wrong claim. Nothing renders READY out of a session with an open correction. Clear each one only after you have actually patched the draft (`correct apply --id c1 --job {job}`) or established it does not apply (`correct dismiss --id c1 --job {job} --reason "..."`, and the reason is mandatory). Re-run the drafter for the patch; do not hand-edit the claim out and leave the surrounding argument standing on it.

### Cross-probe findings (this is where the FINDINGS section comes from)

The probes ran blind to each other, so contradictions between them are visible only here, and they are the most valuable output the loop produces. Compare surviving claims across probes and surface:

- **Two sources disagreeing.** The sprint-review page assessing the goal `Reached` while the Amplitude experiment object reads `enabled: false, percentage: 0` is the canonical case, and it was the run that justified this whole phase.
- **A decision in the log with no corresponding change in the world**, and its reverse: consequential events with no log entry.
- **A prior run's claim that is now wrong.** Say so plainly, say what replaced it, and mark it as a correction rather than quietly restating the new version.

Do not spawn an agent per pair. Compare the claim lists directly, and dispatch an agent only for the candidate contradictions that survive that comparison.

---

## Phase 2s · COACH + SHARPEN (two short sections, both earned, both capped)

These are the two things Tomek asked the loop to do for him rather than for his work. They run after the findings are verified and before delivery, because they belong in the brief and the brief is what he reads.

### 2s·a Coaching, every morning, one nudge

> *"the coaching should also look at my past decisions, actions, goals and help me see the forest from the trees and the other way around when I need to look wider or narrower... I'm a fan of stoicism so I'm really interested in focusing on what I can control and change, and I have a growth mindset so I want to keep getting better every day... even ok for the coach to have a long term plan that I'm not aware of and it's helping me achieve that plan by the daily morning loop coaching. I don't want to have to call the coach."*

**Ask the engine first. It decides what and how, you write the words.**

```
python3 05-automation/agent-manager/scripts/coach.py --date {DATE} due --json
```

It returns the **thread** due today (from `coach/plan.md`, by priority and staleness, never the same thread two mornings running, parked threads skipped), the **zoom** (`wide` or `narrow`, measured from the ticket spread across the last five morning plans, not chosen), its reason, the open observations on that thread, and the last three nudges so you do not repeat one. `{"nudge": false}` means nothing is due. **Render the section anyway, with one line saying why.** Absence and zero must never look identical: a quiet day and a broken `coach.py` currently produce an identical brief, which is the silent-failure class this loop exists to remove. `COACHING: nothing due, every thread was raised too recently` is information. Do not overrule the zoom because another angle feels more interesting.

**Then write the nudge, and record it. The recording is what enforces the frame:**

```
# Write to /tmp/nudge-{DATE}.json, then pass the path. No heredocs in the prep sandbox.
python3 05-automation/agent-manager/scripts/coach.py --date {DATE} nudge --zoom {zoom} --in /tmp/nudge-{DATE}.json
# the file's contents:
{"thread": "{thread id}",
 "observation": "{what you actually see, with the evidence in it}",
 "in_your_control": "{the part he can change today}",
 "not_in_your_control": "{the part he can put down, named so he stops paying rent on it}",
 "today_action": "{one thing, doable between the brief and lunch}",
 "evidence": ["{run-log line / ledger row / brief id / file path}"],
 "closes_observations": ["{observation ids this resolves}"]}
```

`coach.py nudge` **rejects** a nudge missing any of the three frame fields, and rejects an observation that repeats an earlier one word for word. Both rejections are correct: without the frame it is an observation, and observations go to `coach.py observe`; repeated verbatim, coaching becomes wallpaper.

Four rules for the writing itself:

- **Evidence or nothing.** A run-log line, a ledger row, a brief id, a date. He will check. An unfalsifiable observation costs the whole thread its credibility.
- **Stoic means practical.** `not_in_your_control` exists so he can put something down, not so the nudge can sound wise.
- **Growth means the delta.** "You closed three of four findings this week against one of six last week" is coaching. "You are good at detection" is a compliment and does nothing.
- **One ask, today-sized.** If it cannot be done before lunch it is a project, not a nudge.

**The plan is not recited.** `coach/plan.md` holds the long-term threads and the brief never quotes it, which is what he asked for. It is a file in his own repo and `coach.py plan` prints it in full, so it is undisclosed by default and never withheld on request. Never claim there is no plan.

### 2s·b Product feedback, occasionally, and usually not at all

> *"product feedback should be there occasionally when it's needed, not always. I don't make product decisions every day, but I know sometimes I need to think about some upcoming experiment, feature or problem users have and I need help sharpening my thinking on that."*

```
python3 05-automation/agent-manager/scripts/sharpen.py --date {DATE} candidates --json \
  [--signal experiment="{id + why it is live}"] [--signal sprint_goal="{goal}"] \
  [--signal meeting="{a decision meeting today or tomorrow}"]
```

Pass the signals this run actually found: an experiment the pulse flagged, a goal being set at a sprint boundary, a decision meeting on the calendar. It also watches `04-features/` on its own. **`{"challenge": false}` is the normal answer.** **Render the section anyway with the reason**, for the same rule as above: `WORTH SHARPENING: nothing, no decision signal` is information, an absent section is not, and a silently broken `sharpen.py` must not look like a quiet week. Do not force a challenge, do not save one up, and never argue with the cooldown: a challenge every morning is the thing he explicitly did not ask for.

When one fires, write **one closed question** about the specific claim, number or assumption, and record it:

```
# Write to /tmp/challenge-{DATE}.json, then pass the path.
python3 05-automation/agent-manager/scripts/sharpen.py --date {DATE} fired --in /tmp/challenge-{DATE}.json
# the file's contents:
{"topic": "{short slug}", "question": "{one closed question, ending in a question mark}",
 "why_now": "{why this morning is the moment}", "evidence": ["{what makes it real}"]}
```

The recorder **refuses** a generic prompt. `have you considered the risks`, `what are the trade-offs`, `is this the right approach` are all rejected, because a question that could be asked about anything was not asked about this. Name the claim you are testing. The shape to aim for: *"Icebreakers is the sprint goal and its experiment object has zero metrics attached, so which single number will you read on day 3 to decide whether the learning launch taught you anything?"*

---

## Phase 2b — DELIVER (the brief goes to you; you don't go to it)

A plan file on a machine you are not sitting at helps nobody. After the plan file is written, **deliver the brief to `delivery.channel`** on every run, in both modes. This is the step that makes the loop proactive instead of something you have to remember to trigger.

**Deliver with `delivery.notifier_script`.** One command, whatever the channel:

```
python3 05-automation/agent-manager/scripts/notify.py \
  --brief {paths.plan_file} --date {DATE}
```

**Zero setup is a hard requirement of this phase, not a preference.** A delivery step that needs an account is a step most people never complete, and an undelivered brief is worth exactly as much as no loop. `macos` is the default: a native notification plus the brief rendered as a local web page, nothing to sign up for, works offline. `mattermost` costs one webhook URL and reaches a phone.

- **Report the outcome from the receipt, not from the fact that you ran the command.** The script always writes `05-automation/agent-manager/delivery-receipts/{DATE}.json`, on success and on failure. On a non-zero exit, read the receipt's `error` field and surface it verbatim. A failed delivery summarised as "delivered" is the precise failure this phase exists to prevent.
- **The notification is one line**, carrying the counts and the single top item. Its job is to get you to open the brief, not to be the brief.
- **The brief itself is the whole update**, in the order below. Never a teaser with a link and nothing else. The script renders the plan file's markdown, so a well-written plan file becomes a well-formatted page: write the plan file properly and delivery takes care of itself.
- **Call things by their name, never by their id (Tomek, 2026-09-24).** A ticket reads as its plain name ("the shortened signup build", "the Icebreakers second read"), and an experiment reads as its name ("the intent-driven signup experiment", "Icebreakers", "Plus retention"), never as `KM-14881` or `10442808`. He does not know what the numbers are, and a name is what lets him answer in one read. If a key is needed for traceability, put it once in brackets after the name, e.g. "the shortened signup build (KM-14881)", and never as the subject of a sentence. Amplitude object ids and Confluence page ids stay in the evidence and source lines, out of the prose. The same goes for internal jargon: if a phrase like "the gate's signup prompt" needs a gloss to be understood, write the gloss instead of the phrase. **This is enforced, not just asked for:** `.claude/hooks/house-rules.mjs` denies any Write or Edit to `morning-plan-{DATE}.md` that has a bare `KM-` key or an 8-digit experiment id outside a `Source:`/`Evidence:` line, in both `--prep` and interactive runs. When it fires, rewrite the line with the name; do not route the write through Bash to get around it. To find a name, read the ticket summary from Jira or the experiment's `name` from Amplitude; never make one up.
- **`#id`.** The script numbers each brief and puts it in the title, which is what makes `morning loop #21` and `/brief 21` work later. Same date always reuses the same id, so a re-delivery never burns a number.

```
☀️ MORNING BRIEF — {DATE}   ({weekday}, sprint {n}/{len}, {phase})
Window: {lookback} · Sources: {preflight line, degradations named. A probe the owner switched off in config is not a degradation; leave it out}
Confidence: {census line from trust.py claims census, verbatim, e.g. "41 claims: 12 verified
 live, 22 reported, 3 inferred, 4 carried. 2 corrections registered, both cleared."}

── STATE OF YOUR WORLD ──   (read this first)
{3-6 lines of synthesis, not a list: what actually moved, who is waiting on you,
 the one live decision. This is the part worth reading if you read nothing else.
 EVERY factual claim in this section and below ends with its tag from trust.py:
 [V 08:14] verified live · [R] reported · [I] inferred · [C] carried. Tag the claim,
 not the line: a sentence with two claims carries two tags. Instructions, draft
 paths and questions are not claims and carry none.}

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
  - Commitments: {n carried}        - Meetings: {n notes written} · {n ceremony pages read} · {n action points pulled into meeting-actions}

── OPEN QUESTIONS ──   ({n} asked, {a} answered since last run, {o} open)
{EVERY open question printed in full, here, in the brief (Tomek, 2026-09-28: "I don't
 want to have to go to other files"). Per question: the question, why it matters, the
 options or the default answer, carry count. Never a count plus a pointer.}
Answer in {questions file path}. No command, type under **Answer:** and save.

── INBOX ──   ({k} read yourself, {d} draft-worthy, {f} FYI, {p} noise)
{EVERY triaged item printed here, in the brief. READ THIS YOURSELF,
 DRAFT-WORTHY and FYI items each get one line of WHAT / WHY / HOW; noise is grouped with
 a count. "Folded into this brief" means the items are HERE, not just their counts. If
 the inbox probe did not run or is not enabled, say so on this line instead of
 omitting the section.}

── MATTERMOST ──   ({r} need your reply, {a} decision or action, {f} FYI, {p} noise)
{Only when `mattermost_triage.enabled`. Same contract as INBOX: every item printed here, one
 line of WHAT / WHY / HOW with channel and time, noise grouped with a count. A promise the
 owner made in a thread ("I'll create the ticket") is an action item and goes to the ledger.
 If the probe did not run, say so here.}

── COACHING ──   (one, today only. A different thread tomorrow.
                 ALWAYS rendered: "nothing due, and why" is information, absence is not.)
{the observation, with its evidence}
In your control: {the part you can change today}
Not in your control: {the part you can put down}
Today: {one thing, doable before lunch}

── WORTH SHARPENING ──   (usually "nothing, no decision signal", which is still rendered)
{one closed question} · why now: {the signal}

── FINDINGS THIS RUN ──
{anything no single source showed: contradictions between sources, corrections to
 previous runs, a chain that only appears when two signals are read together.
 If a prior run's claim is now wrong, say so plainly and say what replaced it.}

── TRUST ──
Packet: {paths.review_packet}   (every draft, its verdict, its ship action, in one file)
Grading: {n} stamped · {counts by verdict} · {n} UNSTAMPED · {n} open corrections
Every verdict above is computed by trust.py from recorded agent ids. No agent wrote one.
The same holds for the claim tags: [V] needs a recorded, independent verifier id and a
re-query time, and a tag nobody recorded is not a tag.
Out under your name since the last run: {shipped.py list --since; or "nothing recorded"}.

── HONESTY LINE ──
Truly autonomous this run: {what actually ran unattended}. Shipping: gated, nothing sent.
Claims killed by the finding gate: {n}. Degraded sources: {list or "none"}.
Nothing in this brief was fabricated, and every status/number claim carries a source.
```

Other channels behave the same way: `confluence_page` updates one rolling page in place, `mattermost_dm` sends the summary plus a link, `local_file` is the v1 behaviour and only works if you are at that machine.

**Delivery is not a `never_auto` action.** It sends already-sensed read-only output to the owner's own address. It decides nothing and tells nobody else. Posting a draft, creating a ticket, or replying to a human still happens only at the interactive gate.

**Never fail silently.** If the send tool is unavailable: save as a draft; if that fails too, write the brief to `paths.plan_file` and **state at the top of your final output that automated delivery failed and exactly which tool was missing**. A missing delivery is a finding, never a shrug.

## Phase 2c — NOTIFY + HEALTH (verify your own end deliverable)

**Notify.** One line on `notify.channel`, no more. Its job is to get you to open the brief, not to be the brief:
```
☀️ Morning brief ready — {n} drafts, {m} decisions, {k} meetings. Top: {the one item}.
```

**Health (`health.enabled`).** Before the run ends, verify the **end deliverable exists**, not that the script exited 0:
1. The plan file was written for `{DATE}`.
2. **The brief was actually delivered** — confirm the sent item exists, don't assume the send call succeeded.
3. The notification was sent.
4. The previous scheduled run happened at all. If yesterday was a working day with no run-log line, **that is a silent miss**, so report it today with the gap length.
5. **Planned versus produced.** Count the SOLVE items in the plan against the files in `paths.review_dir`, and the files against those carrying a verify stamp. Report all three (`6 planned · 5 written · 0 verified`). Run #30 lost a planned item silently and nobody knew until the files were counted by hand.
6. **Yesterday's pre-drafts: how many were shipped?** A run of days where drafts are produced and never shipped is the same class of silent failure as a brief that never arrived, and it is the one this loop actually had. Report the streak (`0 shipped of 11 drafted across 4 days`) rather than waiting for someone to notice.
7. **On time, not just delivered (V3-TO-V4 D3).** Delivery success said 20 of 27 weekdays; lag against the fire said 1 of 21. Same artefacts, and only the second number redirects the work. Run:
   ```
   python3 05-automation/agent-manager/scripts/ontime.py record --date {DATE}
   python3 05-automation/agent-manager/scripts/ontime.py report
   ```
   `record` classifies today against `schedule.time` and `health.on_time.grace_minutes`: **unattended** (delivered by the unattended runner within the grace window), **late** (after it, or only because someone ran it by hand), or **missed**. It writes the result into today's receipt and one run-log line. `report` prints the rolling rate with its denominator, e.g. `unattended 3 of 10 weekdays, late 6, missed 1 · median lag 52 min`. Copy the report line into the health line verbatim. Never estimate a lag for a day it reports as `no record`; those have no receipt and no runner attempt, and they stay out of the denominator. The runner (your copy of `scripts/run-prep.template.sh`) also calls `record` at the end of every run, so a day the model never reached still gets its line.

Check both halves independently. The known trap is a two-stage routine where the first half succeeds, so an "did something run?" check reports healthy while the real deliverable never landed. On any miss, write a diagnosis (what was missing, the probable cause, the one fix) and alert on `health.alert_on_miss`.

In `--prep` mode: continue to **Phase 2p**, then stop. Append one line to `paths.run_log`: `{DATE} prep: planned {n} SOLVE / {m} ASK / {k} HUMAN · delivered: {channel} {✅/❌ + reason} · pre-drafted {p} ({ready} READY, {skipped} skipped: {why}) · claims killed: {n} · census: {the census line} · config self-repairs: {list or none} · health: {pass/miss detail} · {the ontime.py report line}`.

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
4. **Stamp it, and let the stamp decide the label.** The moment a draft's verification finishes, record how it was graded and let `trust.py` compute the verdict. Do not write a label into the file yourself.

   ```
   # Write this JSON with the Write tool to /tmp/stamp-{job}.json FIRST, then pass the PATH.
   # A heredoc with braces and quotes is refused by the unattended sandbox as "expansion
   # obfuscation". Every one of these scripts takes --in <path> as well as --in -.
   python3 05-automation/agent-manager/scripts/trust.py --date {DATE} stamp --in /tmp/stamp-{job}.json
   # the file's contents:
   {"job": "{routing id}", "skill": "{skill}", "external_action": "{from the routing rule}",
    "artifact": "{path under paths.review_dir}",
    "destination": "{the actual page id / ticket / channel it would go to}",
    "drafter":  {"agent_id": "{the drafting sub-agent's id}", "model": "{model}"},
    "verifiers": [{"agent_id": "{verifier 1 id}", "checks": [{"id": "{check}", "result": "pass|fail|n/a", "severity": "block|normal", "reason": "{one line}"}]}],
    "judge": {"agent_id": "{judge id}", "rulings": [{"id": "{check}", "result": "pass|fail"}]},
    "requeried": [{"source": "{JQL / chart id / page id}", "at": "{HH:MM}"}],
    "carried":   [{"claim": "{what was carried}", "from_brief": {id}, "age_days": {n}}],
    "expires":   [{"what": "{the cells or claims}", "why": "not re-verified this week"}],
    "unavailable": ["{probe that could not run}"]}
   ```

   The command writes the stamp, computes the verdict and injects the provenance header at the top of the draft. **Every field is evidence, not decoration.** `requeried` is what the reader can skim past; `carried` and `expires` are what they must not publish over; `unavailable` is why the draft is thinner than usual. An empty `verifiers` list is the honest record of a run with no subagents, and it renders `UNVERIFIED` rather than a grid.

   A drafted item with no stamp is listed in the review packet as **UNSTAMPED**, which is a defect, not a neutral state.

   **Meeting output is the exception to "one draft, one file", and it has its own queue.** When `meeting_debrief` (or any rule with `ticket_queue: true`) produces anything actionable, it does not go into the debrief prose where it gets re-typed by hand or lost. **All three kinds go through `tickets.py`**, which renders one reviewable file grouped by meeting, with a checkbox per item: six kinds, each with its own destination and its own rule. Set `kind` on every item:

   | kind | goes to | the rule that gets it refused |
   |---|---|---|
   | `ticket` | Jira | the four house headers, the stub rule |
   | `decision` | Decision Log, or the Design Decisions table via `home: design_table` | hedged, or an action, or names a speaker from a paraphrase |
   | `update` | a named channel | no channel, an unsourced number, a hygiene item |
   | `research` | a note or a spike | no `changes_what`, which makes it curiosity |
   | `question` | one named person | not closed, two questions, no person, unblocks nothing |
   | `idea` | an Idea Engine ticket | no riskiest assumption, which makes it a preference |


   ```
   # Same rule: Write the JSON to /tmp/actions-{DATE}.json, then pass the path.
   python3 05-automation/agent-manager/scripts/tickets.py --date {DATE} draft --in /tmp/actions-{DATE}.json
   # the file's contents:
   [{"kind": "ticket", "title": "[FE] ...", "issue_type": "Story", "role": "{accountable role}",
     "epic": "KM-...", "verified_keys": ["{every KM key you confirmed on board 1847/1946}"],
     "context": "...", "problem": "...", "what_we_need": "...", "why_this_matters": "...",
     "acceptance_criteria": ["..."],
     "source": {"meeting": "...", "when": "...", "fidelity": "verbatim|summary",
                "excerpt": "{quote the meeting, verbatim}"}},
    {"kind": "decision", "decision": "{what was decided, stated as decided}",
     "rationale": "{why, because the log is read six weeks later}",
     "decided_on": "YYYY-MM-DD", "binds": "{the role or group it constrains}",
     "source": {...}},
    {"kind": "update", "audience": "{GC Confluence | Escort CRM | KM Growth}",
     "substance": "...", "detail": "...", "sources": ["{every number needs one}"],
     "source": {...}},
    {"kind": "research", "question": "...", "owner": "{role or person}",
     "changes_what": "{the decision or action that changes depending on the answer}",
     "source": {...}},
    {"kind": "question", "question": "{one closed question ending in ?}", "ask": "{one person}",
     "unblocks": "{what proceeds once answered}", "source": {...}},
    {"kind": "idea", "title": "...", "problem": "{who faces it, in their situation}",
     "proposed_solution": "...", "strategic_alignment": "{the KR, or plainly none}",
     "riskiest_assumption": "{the thing the next step has to test}", "source": {...}}]
   ```

   **Link every item to what caused it.** Set `derived_from` to the durable ids it follows from
   (`["2026-09-16/i1"]`), and `supersedes` on a decision that replaces an earlier one. Durable ids
   are `{DATE}/{id}` and are stamped at draft time, because `t1` collides across days and so cannot
   be pointed at. This is what makes the full circle readable later: `tickets.py chain --uid
   2026-09-16/i1` walks the meeting it came from, what it spawned, and what came of each.

   Two rules are enforced by that command rather than asked of you, because both have already put a bad ticket into Jira:

   - **The four house headers**, `**Context:**`, `**Problem:**`, `**What we need:**`, `**Why this matters:**`. Measured on 2026-08-26: 8 of 10 real ticket drafts carried none of them.
   - **A decision must be decided.** `We might cap it` is a leaning and `We should cap it` is an action. Neither belongs in the Decision Log, which records why the world is the way it is. The first is not decided yet; the second is a ticket. Both are refused.
   - **No speaker named from a paraphrase.** A decision drawn from a summary-level source records what the room decided and never who said it. Same root cause as the stub rule.
   - **An update names its channel and sources its numbers**, and a hygiene-queue item never becomes an update, because `hygiene.never_external` is set and the whole point of that queue is that the finding is true, actionable and not for the room.
   - **The stub rule.** Set `fidelity` honestly. Granola transcripts are summary-level paraphrase, so acceptance criteria written from one are invented. A `summary` source ships as a **STUB with exactly one criterion**, `confirm scope with {role} before estimating`, and five invented ones are a validation error, not a nicer draft. A stub someone confirms in 40 seconds beats a plausible ticket nobody trusts.

   Also required: a verbatim `source.excerpt` on every ticket, a role tag in the title with the assignee left empty, and every referenced KM key listed in `verified_keys` after you actually confirmed it sits on board 1847 or 1946. `KM` is shared. A blocked ticket is rendered with its reason and **cannot be approved until it is fixed**, so re-draft it rather than arguing with the checker.
5. Skip, and say why, any item whose inputs are missing (a degraded probe, an unanswered ASK). A skipped item is listed in the brief as skipped, never silently dropped.
6. **Build the review packet, and rebuild it after every stamp.** One file holds every draft, its computed verdict, its ship action and its full text, so the review is a single pass down one page rather than a directory crawl:

   ```
   python3 05-automation/agent-manager/scripts/trust.py --date {DATE} packet
   python3 05-automation/agent-manager/scripts/trust.py --date {DATE} status
   ```

   The packet also pulls the decisions, your-turn items and findings out of the plan file, so it is the whole morning in one place. Its path goes in the brief. Rebuild it whenever a stamp, a correction or a revision changes anything: it is generated, never hand-edited, and anything typed into it is lost on the next rebuild.
5. **Nothing ships.** Not one external action. `never_auto` is untouched by this phase, and a draft sitting in `agent-drafts/` has left the workspace exactly as much as it did before, which is not at all.

The brief then carries the drafts, so the 🤖 section reads:

```
🤖 DRAFTED FOR YOU ({n})         (nothing sent; each ships only with your yes)
  1. ✅ GC update            READY        .../{DATE}/gc_update.md      (would publish to GC Confluence · 2 verifiers cleared)
  2. ⚠️ Refinement agenda    NEEDS EDIT   .../{DATE}/refinement.md     (issue: 2 candidates missing acceptance criteria)  · expires 11:00 today
```

**This changes the honest accounting, in the direction that matters.** A job that was scheduled, drafted unattended, cleared every check, and shipped without a heavy rewrite is the definition the run log has been using for "truly autonomous" all along, and until now the loop has structurally been unable to produce one, because drafting could not happen unattended. Keep the bar exactly where it is. A pre-drafted item that Tomek rewrites before shipping is still tooling coverage, and the run log still says so.

**This phase runs after delivery, on purpose.** Drafting six items with independent verification takes far longer than sensing and planning, and the brief must not wait behind it: you would be reading yesterday's arrival time for the same information. So the brief goes out on schedule with the 🤖 section marked `drafting…`, and when the drafts land this phase **updates the same brief in place and re-runs the notifier with the same `{DATE}`**, which reuses the same `#id` rather than burning a new one. Second notification, one line: `🤖 {n} drafts ready ({ready} READY). /morning to ship.`.

Two consequences worth stating plainly. **A watchdog kill mid-pre-draft costs nothing that was not already delivered**, because the plan and the verified findings left the building before drafting started. And **`dispatch.max_predrafts` is the cost ceiling**: it is what stops a bad morning from becoming an expensive one, so lower it before you conclude the loop is too costly to run.

---

## Phase 3 — SHIP + REVIEW (interactive only, the gate)

### 3a. The gate: ship, edit, or discard

**When the prep pre-drafted (the normal case), the gate is not "shall I start?" any more.** The work is done and graded. **Open the review packet first** (`trust.py --date {DATE} packet` to rebuild it, then read it): it holds every draft, its computed verdict, its ship action and its full text in one file, plus the decisions and your-turn items from the plan. Then print the drafts with their labels and their would-be external action, and ask, in one message:

> Here's what I drafted this morning. {n} READY, {m} need your edit.
> **[a] ship all READY · [s] select · [e] edit one with me · [n] none, just the decisions**
> (Each ship is confirmed individually against its target before it happens. Nothing has left the workspace yet.)

**Freshness before shipping, not before drafting.** A draft written at 07:52 and shipped at 11:00 rests on a four-hour-old read. Before any ship, re-verify the volatile claims **inside that draft** (ticket statuses, experiment state, counts) against live sources, and say what changed. **A claim that moved is a correction, so register it** (`trust.py correct add --was ... --now ... --source ...`), which holds every draft in the session that rests on the same fact, not only the one you happened to be reading. Then the draft goes back for one targeted revision rather than shipping with a number that was true at breakfast, and it is re-stamped afterwards so the freshness re-check lands in `requeried`. Re-pull new transcripts and the board state too, since a new item may have appeared since the prep and belongs in today's plan.

**When there are no pre-drafts** (pre-drafting disabled, the watchdog fired, or new SOLVE items appeared since the prep), fall back to the original gate: show the four buckets and ask which 🤖 items to draft now, then run 3b. Say plainly which situation you are in. A gate that silently offers a smaller menu than usual reads as "quiet morning" when it actually means "the prep did not finish".

**Meeting actions have their own gate, and it is a file, not a question.** If an action queue exists for today, say so and point at it rather than reading the items out:

```
python3 05-automation/agent-manager/scripts/tickets.py --date {DATE} status
```

> `{n} actions from {meetings}: {t} tickets, {d} decisions, {u} updates. Tick what you want done in {queue path}, then I act on only those.`

He ticks `[x]` to build and `[-]` to drop, saves, and then:

```
python3 05-automation/agent-manager/scripts/tickets.py --date {DATE} sync
python3 05-automation/agent-manager/scripts/tickets.py --date {DATE} approved --json
```

`sync` reads the boxes back into state and **refuses a ticked box on a blocked item**, naming the rule. Approval is not action: each approved item is still confirmed individually at the ship gate below, because creating a Jira issue, editing Confluence and posting to a channel are all `never_auto` and stay that way.

Wait for the answer either way. This is the permission gate, and nothing external happens before it.

### 3b. The draft pipeline (used by Phase 2p unattended, and here for anything new)
Each 🤖 item runs as a short **pipeline, not a single shot**, whether Phase 2p ran it unattended at 07:52 or you asked for it at the gate. One definition, two callers. This draft → verify → revise loop is the rung-three step: the agent checks its own output so it reaches you good enough to ship, not something you send back.

1. **Draft.** A sub-agent runs the named `skill` with today's sensed context and writes its output to `paths.review_dir` as `{job-id}.md`.
2. **Verify (independent skeptic, per-check).** A *separate* agent — never the one that drafted it — resolves the job's rubric: `{paths.rubrics_dir}/{skill}.rubric.yml` extended by `_base.rubric.yml`, falling back to `_base` alone if no skill rubric exists. It grades the draft **check by check**, not with a vibe score, and it reads the rubric's `calibration_target` and `_base`'s `tolerances` first. **The target names the reader to grade against, and it is never Tomek's voice. If the reason you are about to fail a judgement check appears in `tolerances`, the verdict is `pass`.** Failing a draft for phrasing, ordering, formatting or for being shorter than expected is the specific error this exists to stop — for each check it applies the grader contract *"Apply this single check to the artifact. Return pass | fail | n/a and one sentence why"* and defaults to `fail` when uncertain. Returns `{per_check: [{id, result, reason}], failed: [...], ready: bool}` where `ready` = **every applicable check passes**. Any `block`-severity fail (invented facts, ungrounded targets) = hard NEEDS-EDIT regardless of the rest. (See `rubrics/README.md` for the full grading contract.)
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

**Every send is recorded the moment it lands, before you move to the next item:**

```
python3 05-automation/agent-manager/scripts/shipped.py add \
  --job {job} --to "{the real page id / ticket key / channel}" --by loop
```

The `verified` column is read from the stamp, not typed, so a draft that went out ungraded says so in the ledger permanently. That is the point: a ledger that cannot embarrass the loop is decoration. **Tomek shipping something by hand runs the same command with `--by hand`, and that is the path that matters** — loop-initiated sends were always countable, his were invisible. `/shipped` is the shorthand.

If a ship is refused mid-queue, record nothing. The ledger holds what left, never what was intended.

**For each approved item, do the thing, then record where it landed:**

```
python3 .../tickets.py --date {DATE} done --id {t1} --key KM-14501
python3 .../tickets.py --date {DATE} done --id {t2} --to "confluence 6000804064"
python3 .../tickets.py --date {DATE} done --id {t3} --to "mattermost KM Growth"
```

That marks the queue, appends to the outbound ledger, **and writes the provenance row** in one step, so every meeting action is a send like any other and carries its own origin. The provenance row leaves an `outcome` slot empty on purpose: the outbound ledger proves a thing left, and the outcome is the half that makes the loop learnable. **Never record a destination the call did not actually return.** A decision goes to the current sprint Decision Log page, which is Maria's: append an entry, never restructure her page.

**Sweep for outcomes once a week, on the same day as the coaching deep pass.** This is the other half of the circle and nothing else fills it:

```
python3 05-automation/agent-manager/scripts/tickets.py pending-outcomes --older-than 7
```

For each item it names, go and read the real source, then record it:

```
python3 .../tickets.py outcome --uid 2026-09-16/i1 \
  --result "became experiment 10460112, +3.1% toggle use, not significant" \
  --source "Amplitude experiment object 10460112"
```

**`--source` is mandatory and the command refuses without it.** An outcome with no named source is the loop marking its own homework. A ticket's outcome is its Jira resolution, a decision's is whether a later decision superseded or reversed it, an idea's is what the experiment it became actually returned.

The question this makes answerable is worth more than the chain itself: **which meetings produce decisions that survive.** If Season Planning decisions get reversed within a sprint and Design and Refine decisions do not, that is a measurable fact about how the squad decides, and nothing else in this workspace can see it.

**Close the coaching and challenge loops here too, when he answers them.** An unanswered nudge is not a neutral result, it is the coaching equivalent of a carried item:

```
python3 05-automation/agent-manager/scripts/coach.py   respond --id {n7} --outcome acted|declined|deferred
python3 05-automation/agent-manager/scripts/sharpen.py respond --id {s3} --outcome engaged|declined|deferred
```

Record `declined` honestly. Declining twice parks that thread or topic for a month, and that is the mechanism that keeps daily coaching from becoming daily nagging. Softening a decline into a deferral disables it.

### 3d. Close the loop
Append to `paths.run_log`, honestly:
`{DATE} run: pre-drafted {p} unattended ({ready}/{p} READY first-pass, computed by trust.py from {v} recorded verifier ids; {u} UNSTAMPED; {r} auto-revised; {e}/{x} cleared the stricter external double-verify), corrections registered {c} ({applied}/{dismissed}/{still open}), drafted {n} more at the gate, shipped {s} ({which external actions}; {sv} verified-at-send per the outbound ledger), decisions surfaced {m}, tickets {td} drafted / {ta} approved / {tc} created, coaching `{thread}` ({zoom}) {outcome or "no outcome yet"}, challenge {s or "none, no decision signal"}. Claims killed by the finding gate: {n} ({claim: why}). Carried items converted: {closed}/{escalated}/{parked}, still carrying: {list with counts}. Config self-repairs: {key: old -> new}. Failed checks this run: {check-id×count}. Truly-autonomous this run: {jobs that ran scheduled + drafted unattended + passed every check + shipped without rewrite}.`

Track four things across runs, because each one points at a different repair:

| the number | what a bad value means | where the fix goes |
|---|---|---|
| **ready-without-edit rate** | the drafters are not yet shippable | the skill, via its failed-check histogram |
| **failed-check histogram** | one specific check fails most on one skill | `focused-skill-improvements.md`, which now knows *which check* |
| **claims killed at the finding gate** | the sense probes are producing claims they cannot ground | the probe's contract, usually a missing evidence excerpt |
| **pre-drafted but never shipped** | the loop is drafting work you do not want | the routing rules, not the drafters. This is the number that would have caught seven dead runs on day two instead of day fourteen |
| **shipped without an independent verifier** (`shipped.py list --unverified`) | the trust layer is running as paperwork, not as a gate | either the verifiers are not actually running, or the drafts are good and the bar is theatre. The ledger tells you which, because it holds both halves |

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
- **The trust layer is code, not prose, and that is the whole point.** Grading, correction propagation, the provenance header and the outbound record live in `scripts/trust.py` and `scripts/shipped.py`, with `trust.py selftest` proving the verdict rules on every change. Everything this command had specified about independent verifiers was already correct and had twice rendered as if it were running when it was not. A rule an agent can narrate its way around is not a rule; a verdict computed from recorded ids is. See `05-automation/agent-manager/TRUST-LAYER.md`.
- **Watch these two numbers before anything else.** *Pre-drafted but never shipped* tells you the loop is aimed at the wrong work; the fix is in the routing rules. *Claims killed at the finding gate* tells you the probes are asserting things they cannot ground; the fix is in the probe contract. Both are new in v3 and both are early warnings the old run log could not produce.

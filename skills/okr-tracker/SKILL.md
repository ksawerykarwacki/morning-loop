---
name: okr-tracker
description: This skill should be used when the user asks to "track OKR progress", "generate OKR report", "run OKR tracker", "update OKR status", "how are we doing on OKRs", "OKR progress this sprint", or "prepare OKR update". Produces a weekly OKR progress report in two formats — squad review (detailed, with ticket references) and steering committee (outcome-focused, with KR percentages and confidence).
version: 1.0.0
---

# OKR Tracker Skill

## Overview

Generates a structured OKR progress report for the Escort CRM & CAI squad. Reads the OKR-to-epic mapping, pulls live Jira data for the current sprint and all mapped epics, calculates per-KR completion estimates, flags stale KRs, and produces two output formats. Appends a snapshot to the progress log on every run.

---

## Configuration

```yaml
workspace: /Users/tomek/Projects/po-workspace
okr_map: /Users/tomek/Projects/po-workspace/okr-epic-map.md
progress_log: /Users/tomek/Projects/po-workspace/01-sprint-operations/okr-progress-log.md
jira:
  cloudId: koko-app.atlassian.net        # use this directly as cloudId in all Atlassian tool calls
  base_url: https://koko-app.atlassian.net
  board_id: 1847
  project_key: KM
  mapped_epics: [KM-12205, KM-10878, KM-10904, KM-10909, KM-12010, KM-12133]
season:
  name: Q2 2026
  total_sprints: 6
  start_date: 2026-03-30
  end_date: 2026-06-20
  sprint_boundaries:        # approximate — update each sprint
    sprint_1: "2026-03-30 to 2026-04-08"
    sprint_2: "2026-04-09 to 2026-04-18"
    sprint_3: "2026-04-21 to 2026-05-02"
    sprint_4: "2026-05-05 to 2026-05-16"
    sprint_5: "2026-05-19 to 2026-05-30"
    sprint_6: "2026-06-02 to 2026-06-13"
```

---

## Step 1 — Load context (read all three sources before pulling Jira data)

Run all three reads before proceeding. These together give the full picture: what the OKRs require, what the team actually did, and what the metrics show.

### 1a — Load the OKR map

Read `/Users/tomek/Projects/po-workspace/okr-epic-map.md` in full.

Extract for each KR:
- KR ID and full description
- Target (the measurable threshold)
- Mapped epic(s) and their Jira keys
- How epic progress translates to KR progress (per the "How ticket progress translates" sections)

Do not rely on memory — always re-read the file to catch updates.

### 1b — Read the sprint report

Read the most recent sprint report at `/Users/tomek/Projects/po-workspace/sprint-reports-[timestamp].md` (use the latest file if multiple exist).

Extract:
- **Completed tickets** — grouped by epic; cross-reference with KR mappings from 1a to attribute sprint work to KRs
- **In-progress tickets** — directional signal for next sprint KR trajectory
- **Velocity and completion rate** — context for assessing whether KR pace is realistic
- **Blockers** — may explain why a KR appears stale even if the epic is active
- **What shipped** — any launches or experiments that are directly tied to a KR milestone

If the sprint report is not available, ask the user to provide: what was completed, what is in progress, and any known blockers before continuing.

### 1c — Read the insight brief

Read `/Users/tomek/Projects/po-workspace/insight-brief.md` — output from the data-analysis skill.

Extract:
- **Metric movements** tied to any KR (especially KR 2.3 Sian WAU/D30 if data exists, and any feature adoption metrics for sprint deliverables)
- **Risk flags** — metrics moving in the wrong direction relative to a KR target
- **Opportunity signals** — metrics that suggest a KR is closer to its target than the Jira ticket count implies
- **Amplitude gaps** — metrics flagged as not yet tracked; note these explicitly in KR assessments that depend on them

If `insight-brief.md` does not exist (data-analysis not yet run), flag this and proceed with Jira data only. Note in the report: "Metric evidence unavailable — run data-analysis before this step for complete KR confidence assessments."

---

## Step 2 — Pull Jira data

Use `cloudId: koko-app.atlassian.net` for all Atlassian tool calls. Run all calls in the same message where possible to minimise round-trips.

### Query A — Epic statuses (run all 6 in parallel)

Call `mcp__claude_ai_Atlassian__getJiraIssue` on each epic key with `fields: ["summary", "status", "assignee"]`. This gives the headline status without downloading every child ticket.

```
KM-12205  KM-10878  KM-10904  KM-10909  KM-12010  KM-12133
```

### Query B — Tickets completed in the last 28 days under mapped epics (primary sprint contribution data)

This single query is the most important — it answers both "what moved this sprint" and "which KRs are stale".

```jql
project = KM AND status = Done AND updated >= -28d
AND "Epic Link" in (KM-12205, KM-10878, KM-10904, KM-10909, KM-12010, KM-12133)
ORDER BY updated DESC
```

Request `fields: ["summary", "status", "assignee", "updated"]` and `maxResults: 100`. If the result count equals 100, run a second query with `offset: 100` to check for additional Done tickets.

If the `"Epic Link"` field name is rejected (next-gen Jira projects use `parent` instead), try:
```jql
project = KM AND status = Done AND updated >= -28d
AND parent in (KM-12205, KM-10878, KM-10904, KM-10909, KM-12010, KM-12133)
ORDER BY updated DESC
```

### Query C — Active sprint: DO NOT RUN

❌ **All active-sprint JQL queries overflow context regardless of field or result limits.** The Atlassian MCP returns full ADF document bodies for each ticket even when specific fields are requested — 30 results still produces 60k+ characters.

**Skip Query C entirely.** Queries A and B together give everything needed for the OKR report:
- Epic headline status → Query A
- What moved this sprint and which KRs advanced → Query B (Done in 28 days)
- Which KRs are stale → Query B (zero results for an epic = stale)

If you specifically need to know which tickets are In Progress right now (not Done), ask the user directly rather than running a Jira query.

### Staleness detection (derived from Query B)

After Query B returns, group results by epic. Any epic with **zero** Done tickets in the result set is stale (no contributions in 28 days). Flag with ⚠️ STALE. Note the exception: epics that are Backlog by design because they are sequentially dependent (KM-10904 and KM-10909 both depend on KM-10878 completing first) should be noted as "sequentially blocked" rather than stale.

### Sprint attribution (assign tickets to the right sprint)

Use the `updated` date from each Done ticket and the sprint boundary dates in Configuration to assign each ticket to Sprint N. A ticket updated on 2026-04-09 belongs to Sprint 2; one updated on 2026-04-08 belongs to Sprint 1. When boundary is ambiguous, note it but don't omit.

### Fallback — if Jira is unavailable

Ask the user to provide:
1. Current status of each mapped epic (Backlog / Ready / In Progress / Done)
2. Tickets completed this sprint with their epic link
3. Any known baseline or measurement data for O1 KRs

---

## Step 2b — Detect epic status lag

After Query A (epic statuses) and Query B (Done tickets) return, cross-check them:

For each epic, ask: **does the epic's status reflect what its Done tickets say?**

A lag exists when:
- Epic status is **Backlog** or **Ready**, but Done tickets exist under it within the last sprint
- Epic status is **In Progress**, but all child tickets are Done (epic should be closing)

When a lag is detected:
- Note it explicitly in the squad report with the recommended Jira update (e.g., "KM-12133 shows Ready but KM-12134 is Done — update epic to In Progress")
- Do **not** use the lagging epic status for KR progress calculation — use the evidence from Done tickets instead

---

## Step 3 — Calculate KR progress

Use the rules below to estimate percentage completion and confidence level. Never invent metric values — use `[REQUIRES PO INPUT]` when data is genuinely unknown.

### Season-pace baseline
```
Weeks elapsed since 2026-03-30 ÷ Total season weeks (12)
= Expected completion % at this point in time
```
KRs tracking at or above season-pace → **On track**
KRs 10–25% behind season-pace → **At risk**
KRs 25%+ behind, or with structural blockers → **Off track**

---

### KR 1.1 — Dev workflows ≤30% of baseline time (3 workflows, ≥5 samples each)

| State | % |
|-------|---|
| No workflows with baseline data | 0% |
| 1 workflow: baseline set + ≥5 samples taken | 33% |
| 2 workflows complete | 67% |
| All 3 workflows at ≤30% target | 100% |

**Evidence to look for:** Jira tickets 2, 3, 4 under KM-12205 (test generation, PR drafting, code review). Status = Done with logged before/after = workflow complete.

---

### KR 1.2 — Designer AI explorations <2 hrs to approval (≥3 screens)

| State | % |
|-------|---|
| Design system not yet packaged for AI (Ticket 5 open) | 0% |
| Design system packaged (Ticket 5 Done) | 20% |
| 1 exploration with logged time | 40% |
| 2 explorations | 70% |
| ≥3 explorations, avg <2 hrs | 100% |

**Evidence to look for:** Jira tickets 5, 6 under KM-12205.

---

### KR 1.3 — PO time on targeted tasks −40%; ≥2 autonomous workflows

| State | % |
|-------|---|
| Workflows not yet built | 0% |
| Workflows built and in use (no baselines) | 25% |
| Baselines logged (recalled or formal) | 45% |
| After measurements taken (≥5 samples each) | 70% |
| ≥40% reduction evidenced, ≥2 fully autonomous | 100% |

**Current known state:** Ticket drafting, hypothesis generation, and stakeholder reporting workflows are built and in active daily use. Baselines not yet formally logged.

---

### KR 1.4 — 100% of squad with ≥1 AI workflow in playbook (≥20% improvement)

| State | % |
|-------|---|
| Kick-off session not held | 0% |
| Kick-off held, all squad members have named their workflow | 15% |
| ≥50% of squad with completed playbook entries | 50% |
| 100% of squad with completed before/after in playbook | 85% |
| Confirmed at season retro with demos | 100% |

**Stale threshold:** If kick-off ticket (KM-12205 Ticket 1) is still open after Sprint 3, flag KR 1.4 as Off Track.

---

### KR 2.1 — ≥3 hypotheses validated/invalidated with go/no-go + evidence

| State | % |
|-------|---|
| All epics in Backlog/Ready, no interviews or testing started | 0% |
| First outreach or test session begun | 10% |
| 1 hypothesis with completed go/no-go verdict | 33% |
| 2 hypotheses complete | 67% |
| All 3 hypotheses complete | 100% |

**Hypothesis pipeline:**
- H1 → KM-10904 (AI assistant internal testing go/no-go)
- H2 → KM-12010 (high-volume escort interviews go/no-go)
- H3 → KM-10909 (200-escort beta go/no-go)

---

### KR 2.2 — ≥3 prototypes demo'd to users; feedback → backlog within 1 week

| State | % |
|-------|---|
| No demos completed | 0% |
| 1 prototype demo'd with feedback synthesized | 33% |
| 2 demos complete | 67% |
| All 3 demos + feedback backlog items created | 100% |

**Note:** Only 2 of 3 prototypes currently have mapped epics (P1 = KM-10904 internal test, P2 = KM-10909 beta). Third prototype is unidentified — flag this as a structural gap if still unresolved.

---

### KR 2.3 — Sian Messenger: App Store + Play launch; ≥1,000 WAU in 12 weeks; D30 ≥25%

| State | % |
|-------|---|
| KM-12133 not yet started | 0% |
| KM-12133 In Progress | 15% |
| Launched on Android (Google Play) | 30% |
| Launched on iOS (App Store) | 45% |
| WAU tracking active, on trajectory for ≥1k | 70% |
| ≥1,000 WAU achieved within 12 weeks | 85% |
| D30 retention ≥25% confirmed | 100% |

**Time-sensitive:** Milestone % is not enough — also calculate **weeks remaining in 12-week WAU window** from Android launch date. Flag if launch is delayed beyond Sprint 3.

---

### KR 2.4 — Dev-ready backlog ≥10 items by mid-season

| State | % |
|-------|---|
| Count not yet validated | [REQUIRES PO INPUT] |
| X items confirmed dev-ready | X/10 × 100% |

**Count methodology:** A backlog item qualifies when it has: (a) validated hypothesis or research finding, (b) designed mockup or sufficient context for dev, (c) written acceptance criteria. Pull from KM-10878 output, KM-12010 synthesis, KM-10909 post-beta items, and KM-12133 v2 backlog.

**Mid-season deadline:** Sprint 4 start (~2026-05-11). Flag if count is <7 by Sprint 3 end.

---

## Step 4 — Detect stale KRs

A KR is **stale** when no ticket linked to any of its mapped epics has moved to Done in the last 28 days (2 sprints).

For each mapped epic, check the JQL staleness query from Step 2. If 0 results:
- Mark the KR with ⚠️ STALE in the report
- Note the last date any ticket moved to Done (or "never" if first sprint)
- Include in the Recommended Actions section

---

## Step 5 — Generate progress bars

For each KR, render a simple ASCII progress bar and status badge:

```
KR 1.1  [████░░░░░░]  33%  🟡 At risk
KR 1.2  [░░░░░░░░░░]   0%  🔴 At risk
KR 1.3  [███░░░░░░░]  25%  🟢 On track
KR 1.4  [█░░░░░░░░░]  10%  🟡 On track (caution)
KR 2.1  [█░░░░░░░░░]  15%  🟢 On track
KR 2.2  [░░░░░░░░░░]  10%  🟡 At risk
KR 2.3  [███░░░░░░░]  30%  🟢 On track
KR 2.4  [??????????]  --   🟡 At risk (count unvalidated)
```

Bar scale: 10 blocks = 100%. Round to nearest 10%.

Status badge rules:
- 🟢 On track: ≥ season-pace % (or structurally sound with clear path)
- 🟡 At risk: < season-pace % but recoverable; or known structural gap
- 🔴 Off track: significantly behind; structural blocker with no resolution plan

---

## Output Format A — Squad Review (detailed)

Save to: `/Users/tomek/Projects/po-workspace/okr-progress-report.md` (overwrite)

```markdown
# OKR Progress Report — [SEASON]
**Squad:** Escort CRM & CAI
**Report date:** [DATE]
**Period covered:** [SPRINT RANGE]
**Prepared by:** Tomek (PO)
**Audience:** Squad review

---

## Progress Summary

### Objective 1 — [O1 NAME]

| KR | Progress | Target | Status |
|----|----------|--------|--------|
| KR 1.1 | [bar] [%] | [target description] | [badge] |
| KR 1.2 | [bar] [%] | [target] | [badge] |
| KR 1.3 | [bar] [%] | [target] | [badge] |
| KR 1.4 | [bar] [%] | [target] | [badge] |

[Per-KR detail block for each KR:]
**KR X.X — [description]**
- Current value: [what we know]
- Evidence: [ticket references or "none yet"]
- Blocker / note: [if any]

### Objective 2 — [O2 NAME]
[Same structure]

---

## Sprint Contributions

### [SPRINT NAME]

| Ticket | Epic | KR | Contribution |
|--------|------|----|-------------|
| KM-XXXXX — [summary] | KM-XXXXX | KR X.X | [what this moved] |
[one row per relevant completed ticket]

---

## Stale KRs

KRs with no ticket contributions in the last 2 sprints (28 days):

| KR | Last activity | Risk |
|----|--------------|------|
| [KR ID] | [date or "never"] | [what stalls if this continues] |

---

## Recommended Actions for Next Sprint

[For each at-risk or stale KR, one concrete action:]

1. **KR X.X — [action title]**
   - What: [specific task]
   - Who: [owner]
   - Why now: [consequence of waiting]

---

## Unmapped Sprint Work

Work completed this sprint with no direct KR tie:

| Ticket | Category | Note |
|--------|----------|------|
| [KM-XXXXX] | [type] | [why it exists] |

---

*Sources: okr-epic-map.md, Jira board 1847, sprint data [DATE]*
*Verify against Oboard before sharing externally — see reminder below.*
```

---

## Output Format B — Steering Committee Update

Print directly to conversation (do not overwrite the squad report file).

```markdown
## OKR Progress — [SEASON] Sprint [N] Update
**Date:** [DATE] | **Squad:** Escort CRM & CAI

### Objective 1 — [NAME]

| KR | % | Status | Sprint highlight |
|----|---|--------|-----------------|
| KR 1.1 Dev workflows | [%] | [badge] | [one-line: what moved or "no activity"] |
| KR 1.2 Designer workflows | [%] | [badge] | [one-line] |
| KR 1.3 PO workflows | [%] | [badge] | [one-line] |
| KR 1.4 Squad adoption | [%] | [badge] | [one-line] |

### Objective 2 — [NAME]

| KR | % | Status | Sprint highlight |
|----|---|--------|-----------------|
| KR 2.1 Hypotheses | [%] | [badge] | [one-line] |
| KR 2.2 Prototypes | [%] | [badge] | [one-line] |
| KR 2.3 Sian launch | [%] | [badge] | [one-line] |
| KR 2.4 Dev backlog | [%] | [badge] | [one-line] |

### Risks requiring attention
- [KR ID]: [one sentence on what's at risk and what's needed]

### Top actions for next sprint
1. [Action] → moves [KR ID]
2. [Action] → moves [KR ID]

⚠️ *Verify against Oboard before sharing externally.*
```

---

## Step 6 — Append to progress log

After generating both outputs, append a snapshot to the progress log at:
`/Users/tomek/Projects/po-workspace/01-sprint-operations/okr-progress-log.md`

If the file does not exist, create it with a header first.

**Append format:**

```markdown
---

## [DATE] — [SPRINT NAME]

| KR | % | Status | Key change since last entry |
|----|---|--------|-----------------------------|
| KR 1.1 | [%] | [badge] | [what changed, or "no change"] |
| KR 1.2 | [%] | [badge] | [change] |
| KR 1.3 | [%] | [badge] | [change] |
| KR 1.4 | [%] | [badge] | [change] |
| KR 2.1 | [%] | [badge] | [change] |
| KR 2.2 | [%] | [badge] | [change] |
| KR 2.3 | [%] | [badge] | [change] |
| KR 2.4 | [%] | [badge] | [change] |

**Stale KRs this period:** [list or "none"]
**Key sprint contributions:** [2-3 bullet points]
```

When comparing to the previous log entry, call out KRs where status degraded (e.g., moved from 🟢 to 🟡) — these need explicit mention in the squad report.

---

## Oboard Verification Reminder

⚠️ **Before sharing any OKR report externally (Growth Circle, stakeholders, Confluence):**

> "Have you checked Oboard for the latest OKR state? Oboard is the system of record — this report is generated from Jira and local workspace files. Percentages may differ from what stakeholders see in Oboard. Reconcile any differences before the meeting."

Flag specifically if:
- A KR percentage here is more than 15 points different from what Oboard shows
- Oboard has a KR status (On track / At risk / Off track) that conflicts with this report's assessment
- Any KR has been updated in Oboard within the last 7 days that isn't reflected here

---

## Validation Checklist

Before delivering either output:

- [ ] OKR map re-read from file (not from memory)
- [ ] Jira data pulled for all 6 mapped epics
- [ ] All `[REQUIRES PO INPUT]` placeholders surfaced to user — never silently filled
- [ ] Season-pace % calculated for today's date
- [ ] Stale KR check run (28-day window)
- [ ] KR 2.2 third prototype status noted (identified or still open gap)
- [ ] KR 2.4 item count: confirmed tally or flagged as unvalidated
- [ ] Progress log appended
- [ ] Oboard reminder included in output

---

## Trigger Phrases

- "Track OKR progress"
- "Generate OKR report"
- "Run OKR tracker"
- "How are we doing on OKRs?"
- "OKR update for Growth Circle"
- "Prepare OKR section for steering committee"
- "Which KRs are at risk?"
- "OKR progress this sprint"
- "Update OKR status"

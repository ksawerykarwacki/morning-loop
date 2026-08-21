---
name: sprint-reporting
description: Generate a single Confluence sprint report for the Growth Circle from live Jira data. One output, one audience. Use on "generate sprint report", "sprint report for stakeholders", "Confluence sprint report", "sprint status for all stakeholders".
---

# Sprint Reporting Skill

## Trigger Phrases
- "Generate sprint report"
- "Create sprint reports for stakeholders"
- "Prepare Growth Circle update"
- "Sprint status for all stakeholders"
- "Generate Confluence sprint report"

## Description
Generates a single Confluence sprint report for the Growth Circle from live Jira data. One output, one audience.

## Configuration
```yaml
jira:
  project_key: "Escort CRM"
  board_id: 1847
  base_url: "https://koko-app.atlassian.net"
```

## Prerequisites

No manual exports required. Data is pulled live via the Atlassian MCP.

1. **Atlassian MCP access** — use `cloudId: koko-app.atlassian.net` for all calls
   - board_id: 1847, project_key: KM
   - Mapped epics: KM-12205, KM-10878, KM-10904, KM-10909, KM-12010, KM-12133

2. **Read Core Context Files**
   - `/Users/tomek/Projects/po-workspace/00-core/CLAUDE.md` — project configuration
   - `/Users/tomek/Projects/po-workspace/02-stakeholder-comms/communication-matrix.md` — communication patterns

## Workflow

### Step 1: Pull Jira data via MCP

⚠️ **Context safety rule:** The Atlassian MCP returns full ADF document bodies for every ticket, even when specific fields are requested. A query returning 30 tickets produces 60k+ characters and will overflow context. Follow the query limits below strictly.

Run Queries A, A0, and B in parallel. Queries D (per-epic in-progress) run after Query A resolves — they depend on knowing which epics are active.

#### Query A0 — Sprint goal

⚠️ **Known limitation:** JQL-based sprint goal retrieval consistently fails (the sprint goal lives in sprint metadata, not ticket fields). Skip the JQL attempt entirely and use the direct approach below.

**Before starting the report, ask the user:** "What's the sprint goal for Sprint [N]?" — this takes 5 seconds and avoids a guaranteed placeholder in the output.

If the user doesn't have it handy, provide the board link for a one-click lookup:
`https://koko-app.atlassian.net/jira/software/projects/KM/boards/1847`

Do not leave `[REQUIRES PO INPUT]` as the sprint goal in the final output — the sprint goal is the first line stakeholders read.

**Sprint names (for the JQL `sprint = "..."` filter):**
- Sprint 1: "Sprint 1 Q2 2026"
- Sprint 2: "Sprint 2 Q2 2026"
- Sprint 3: "Sprint 3 Q2 2026"
(adjust pattern if naming convention differs)

#### Query A — Epic statuses (run all 6 in parallel)

Call `mcp__claude_ai_Atlassian__getJiraIssue` on each epic key with `fields: ["summary", "status", "assignee"]`.

```
KM-12205  KM-10878  KM-10904  KM-10909  KM-12010  KM-12133
```

This gives headline epic status and assignee without downloading child tickets.

#### Query B — Tickets completed this sprint

Determine the sprint start date from the sprint boundaries below, then run:

```jql
project = KM AND status = Done AND updated >= [sprint-start-date]
AND parent in (KM-12205, KM-10878, KM-10904, KM-10909, KM-12010, KM-12133)
ORDER BY updated DESC
```

`fields: ["summary", "status", "assignee", "updated"]`, `maxResults: 100`

If `parent` is rejected, try `"Epic Link" in (...)` instead.

**Sprint start dates:**
- Sprint 1: 2026-03-30
- Sprint 2: 2026-04-09
- Sprint 3: 2026-04-21
- Sprint 4: 2026-05-05
- Sprint 5: 2026-05-19
- Sprint 6: 2026-06-02

#### Query D — In-progress/Ready tickets per active epic (run AFTER Query A)

⚠️ Query B only surfaces Done tickets. Active sprint work (In Progress, Ready) is invisible from Query B. After Query A resolves, identify which epics have status "In Progress" or "Ready" with recent activity (updated within last 14 days).

For each such epic, run a targeted child query:

```jql
parent = [epic_key] AND status in ("In Progress", "Ready") ORDER BY updated DESC
```

`fields: ["summary", "status", "assignee", "updated"]`, `maxResults: 5`

Run these per-epic queries in parallel. This is context-safe because each query is scoped to a single epic (typically returns 2–6 tickets).

**Do not skip this step.** In-progress work under active epics is a significant part of the sprint picture and will be missing from the report if only Done tickets are queried.

#### Deriving sprint metrics from MCP results

From Queries A + B + D combined:
- **Completed tickets:** all Done tickets from Query B
- **Active work:** In Progress + Ready tickets from Query D, grouped by epic
- **Epic progress:** cross-reference epic status (Query A) with Done + active tickets
- **Stale epics:** epics with status Backlog/Ready AND zero Done AND zero In Progress in sprint window
- **Velocity proxy:** count of Done tickets per epic (story points not reliably available via MCP)
- **Blockers:** epics with In Progress status but no Done movement — flag for manual input

### Step 2: Generate Report

One output only: the full Confluence report for the Growth Circle. No Mattermost summary. No cross-team highlights.

## Report: Full Confluence Report

```markdown
# Sprint [SPRINT_NAME] Status Report
*Generated: [DATE]*

## 📊 Sprint Overview
- **Sprint Goal:** [SPRINT_GOAL — from Jira sprint metadata; if unavailable, link: https://koko-app.atlassian.net/jira/software/projects/KM/boards/1847]
- **Duration:** [START_DATE] - [END_DATE]
- **Progress:** Day [X] of [Y]

## 🎯 Key Metrics

| Metric | Sprint so far | Notes |
|--------|--------------|-------|
| Tickets Done | [COUNT] | Across [N] active epics |
| Active epics | [COUNT] of 6 | [LIST epic names] |
| Stale epics | [COUNT] | [LIST epic names] — no sprint activity |
| Sequentially blocked | [COUNT] | [LIST] — blocked on upstream |

## 📈 Progress by Epic

### [EPIC_NAME_1] (KM-XXXXX) — [KR reference]
**Epic status:** [STATUS] [⚠️ lag flag if applicable]
**OKR tie:** [KR reference]

**Completed this sprint:**
- ✅ KM-[NUMBER]: [TICKET_SUMMARY] — Done [DATE] · [ASSIGNEE]

**In Progress / Ready this sprint:**
- 🔄 KM-[NUMBER]: [TICKET_SUMMARY] — [STATUS] · [ASSIGNEE]

**Significance:** [Why this matters for OKRs]

### [EPIC_NAME_2]
[Similar structure...]

## 👥 Team Contributions (Sprint [N] to date)

| Person | Done | Active | Notes |
|--------|------|--------|-------|
| [Name] | [X] | [Y] | [Epic + tickets] |

*Note: Only tickets parented to the 6 mapped OKR epics are captured here.*

## 🚨 Risks & Blockers

[Numbered list of blockers — from Jira data + manual context]
[Add: [REQUIRES PO INPUT — add any team-reported blockers from standup]]

## 🔮 Next Sprint Preview

[Suggested focus areas from OKR risk analysis]
[Add: [REQUIRES PO INPUT — confirm Sprint N+1 planned work]]

## 📝 Key Decisions Made

[REQUIRES PO INPUT — add decisions from Growth Circle, standup, or planning]

## 🎯 OKR Impact
<!-- Intentional placeholders — completed by data-analysis (Phase 2) and okr-tracker (Phase 3) -->
- **Feature adoption (sprint deliverables):** [PENDING — data-analysis Phase 2]
- **KR progress summary:** [PENDING — okr-tracker Phase 3]

## ✅ Definition of Done Met (per completed ticket)
- Acceptance criteria verified by PO
- Code reviewed + QA tested
- Supporters informed (where applicable)
- PO approved + deployed (where applicable)
```

## Output

Save to the workspace root:

```
/Users/tomek/Projects/po-workspace/sprint-reports-[YYYYMMDD-HHMM].md
```

Include a downstream data summary section at the end (not for posting — for data-analysis and okr-tracker phases):

```markdown
---
## SPRINT DATA SUMMARY FOR DOWNSTREAM PHASES
*This section is for data-analysis (Phase 2) and okr-tracker (Phase 3) — not for stakeholder posting.*

**What launched / is in-flight that Amplitude should check:**
- [Feature + ticket + date + what events to query]

**Active workstreams by OKR:**
- [KR]: [status and sprint evidence]

**People active this sprint:** [names + roles]
**People with no visible Done tickets:** [names — may be in-progress]
```

## Validation Checklist

Before saving the report, verify:

- [ ] Sprint goal populated (from Jira metadata or Jira board link provided)
- [ ] All metrics calculated correctly
- [ ] Epic groupings include BOTH Done and In Progress/Ready tickets
- [ ] Team contributions reflect active work (not just Done)
- [ ] Stale epics correctly identified (no Done AND no In Progress in sprint)
- [ ] OKR Impact section left as structured placeholders
- [ ] [REQUIRES PO INPUT] markers left for standup blockers and key decisions

## Stakeholder Mapping

### Growth Circle (Confluence Report)
- **Focus:** Roadmap progress, OKR impact, dependencies
- **Detail Level:** Comprehensive with metrics
- **Frequency:** Weekly

## Fallback — if Atlassian MCP is unavailable

Ask the user to provide:
1. Sprint name and dates
2. Sprint goal (from sprint settings)
3. Tickets completed this sprint (key + summary + assignee), grouped by epic
4. Tickets currently in progress per epic
5. Any flagged blockers
6. Team capacity notes for next sprint

## Manual Enrichment Points

Always add manually (from standup / planning notes):
- Key decisions (Growth Circle, standup, 1:1s)
- Business impact metrics (from Amplitude)
- External dependencies (from cross-team discussions)
- Support team readiness (from Chris/Support team)
- Blockers not visible in Jira (context or team dynamics)

Sprint goal is retrieved from Jira — do not ask the user for it before attempting the Jira query.

## Usage

Run `/sprint-reporting` — no file export required. The skill pulls all data live from Jira via Atlassian MCP.

After the skill completes:
1. Review the output at `sprint-reports-[timestamp].md` in the workspace root
2. Add manual context for placeholders (blockers, key decisions, Confluence link)
3. This file is the input for the next phase — data-analysis reads it to identify what launched

## Troubleshooting

### Sprint goal not available from Jira
- The sprint goal is stored in sprint metadata (sprint object), not on individual tickets
- Standard JQL `sprint in openSprints()` does not return the goal field
- The `fetch` MCP tool requires ARIs (Atlassian Resource Identifiers) not REST URLs — cannot directly call the Agile REST API
- Best fallback: provide the Jira board URL `https://koko-app.atlassian.net/jira/software/projects/KM/boards/1847` so the user can check in one click

### In-progress tickets missing
- If Query D returns empty for an epic that should have active work: check if the tickets use different status names (e.g., "Review" vs "Code Review")
- If `parent` field is rejected by JQL: try `"Epic Link" = KM-XXXXX` instead
- If Query D overflows context: run one epic at a time rather than all in parallel

### Metrics don't match what's visible in Jira board
- Check status mappings — Jira next-gen projects may use different status names
- Confirm epic keys in the JQL match the current mapped epics

## Success Criteria

Reports are successful when:
1. Generated within 10 minutes of skill invocation
2. Sprint goal is populated (or Jira link provided)
3. Both Done AND In Progress/Ready tickets are reflected per epic
4. Stakeholders can make decisions from the report
5. Team understands priorities for next sprint

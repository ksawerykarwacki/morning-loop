---
name: backlog-analysis
description: Assess backlog health and prepare a refinement agenda: what is stale, what is duplicated, what should be closed, what is ready to refine. Use on "run backlog analysis", "backlog health check", "prepare refinement agenda", "what's stale in the backlog", "which tickets should we close".
---

# Backlog Analysis Skill

## Triggers
- "run backlog analysis", "backlog health check", "analyze the backlog"
- "prepare refinement agenda", "groom the backlog", "backlog review"
- "what's stale in the backlog", "which tickets should we close"

## Inputs Required
- Live Jira data: all non-Done, non-Cancelled tickets for project key `KM` filtered to `Products Targeted = Escort CRM`
- `04-features/prioritization-framework.md` — scoring criteria and category definitions
- `00-core/CLAUDE.md` — current sprint, OKR context, team assignments

## Output
Save to `01-sprint-operations/current/backlog-analysis.md` (overwrite previous).

---

## Skill Flow

### Step 1 — Fetch backlog from Jira

Pull all tickets where:
- Project = `KM`
- `Products Targeted = Escort CRM`
- Status ≠ Done, Cancelled

For each ticket capture: key, summary, status, assignee, last updated date, epic link, story points.

Separate tickets into two pools:
- **Active sprint** — status is Code Review, Ready to Test, Ready for Release, Testing, Review (already in flight — not competing for backlog slots)
- **Backlog** — everything else (To Do, Backlog, Ready, Refinement, In Progress but not in active sprint)

Also separate and mark as `N/A`:
- Epics
- Admin/meeting sub-tasks (titles containing "Meetings", "Work Epic", "Log", "sub-task", "Prep")
- Liah work-log items

### Step 2 — Score backlog tickets

Read `04-features/prioritization-framework.md` for category definitions and rubric.

**Category assignment (do first):**
- Direct OKR impact
- Indirect OKR impact
- User research
- Not impactful / park

**Rubric scoring (for ties and ranking within category):**

| Dimension | 3 | 2 | 1 |
|---|---|---|---|
| **D — Deliverability** | Ready + assigned | Refinement + assigned OR Ready + unassigned | Refinement + unassigned OR externally blocked |
| **UV — User Value** | Direct user-facing this sprint | Enables user value next sprint | Foundational / internal only |
| **OKR** | Moves current OKR metric directly | Unblocks / supports current OKR | Adjacent / future OKR |

Total = D + UV + OKR (max 9). Sort descending within each category.

**Stale flag:** Mark `STALE Xd` if last updated > 30 days ago. Calculate days since last update.

### Step 3 — Identify clusters and near-duplicates

Scan titles and descriptions for:
- **Delivery clusters** — tickets that form a dependency chain (Spike → Design → BE → FE). Group them and identify the gate item.
- **Near-duplicates** — tickets with highly similar titles or descriptions that may be redundant. Flag for merge or close.
- **Orphans** — tickets referencing an epic or parent story that no longer exists or has been completed.

Label each cluster (A, B, C…) and note gate item and risk level.

### Step 4 — OKR alignment map

For each active OKR (from CLAUDE.md):
- List which tickets serve it (Track 1 = deliver now, Track 2 = unlock later, Park = not this OKR)
- Note coverage gaps (OKRs with thin or no backlog coverage)
- Flag OKRs where Track 1 is empty or all tickets are blocked

### Step 5 — Generate output

Produce a report with these sections:

#### Section 1: Summary Table
All scored tickets sorted by score descending. Active sprint items listed separately first. N/A items at bottom.

Columns: `Key | Summary | Status | Assignee | D | UV | OKR | Total | Stale | Feature Area`

#### Section 2: Feature Area Groupings
Group scored tickets by theme/epic. For each group:
- Sprint goal context
- Dependency chain if applicable
- Concerns (capacity, blockers, sequencing)

#### Section 3: Override Triggers
Any critical bugs or agreed stakeholder asks that should jump the queue per the framework's override conditions. State the override action explicitly.

#### Section 4: Cluster and Duplicate Analysis
Named clusters (A, B, C…) with dependency chains, gate items, risk level, and days stale.
Near-duplicates flagged with recommendation (merge / close one / keep both).

#### Section 5: Stale Ticket Audit
All tickets stale > 30 days, sorted by staleness descending.

Columns: `Key | Area | Days Stale | Status | Assignee | Recommended Action`

Actions should be one of: Assign immediately / Verify active / Park explicitly / Check if blocked / Schedule for next sprint.

Include a stale backlog health summary: total stale count, % of scorable tickets, pattern observations.

#### Section 6: OKR Alignment Map
Per-OKR breakdown of ticket coverage (Track 1 / Track 2 / Park). Coverage assessment (thin / moderate / strong). Gaps called out explicitly.

#### Section 7: Refinement Agenda
The top 5–8 prioritized PO actions before the next sprint planning session.

For each action:
- What to do
- By when (today / next standup / sprint planning / before season planning)
- Why it matters (impact if not done)
- Owner

Lead with the highest-leverage item. End with a stale triage action if > 30% of tickets are stale.

---

## Quality Checks

Before saving output, verify:
1. Every ticket in Jira appears somewhere in the report (scored, N/A, or active sprint)
2. No made-up estimates — only scores derived from actual ticket status/assignee/description
3. At least one refinement agenda item per override trigger identified
4. OKR alignment map covers every OKR listed in CLAUDE.md
5. Stale count is accurate — cross-check days since last update with today's date

## Reference Format

The output at `01-sprint-operations/current/backlog-analysis.md` (generated 2026-04-14) is the reference example for structure, depth, and tone. Match it.

---

*Save output with header: `# Backlog Analysis — KME CRM&AI Squad` | `**Date:** YYYY-MM-DD` | `**Active sprint:** [sprint name]` | `**Framework:** 04-features/prioritization-framework.md` | `**Scope:** N tickets — all non-Done, non-Cancelled`*

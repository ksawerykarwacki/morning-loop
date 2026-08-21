---
name: product-pulse
description: A one-page plain-language product health brief: Amplitude signals, live experiments, sprint health, and stakeholder-mapped callouts written as a narrative rather than a dashboard. Use on "run pulse", "product pulse", "how are we doing today", "what's the metric situation".
---

# Product Pulse Skill

## Description

Generates a single-page, plain-language product health report in ~60 seconds. Combines Amplitude metric signals, active experiment status, sprint health, and stakeholder-mapped callouts into one narrative — not a dashboard, a briefing. Saves to `01-sprint-operations/current/pulse-reports/` for trend comparison over time.

Inspired by the CE Plugin's `/ce-product-pulse` skill, rebuilt specifically for Kaufmich/ECRM metrics and stakeholder structure.

## Triggers

- "run pulse", "product pulse", "quick pulse check", "how are we doing today"
- "what's the metric situation", "pulse report", "morning pulse"
- Called automatically as the Amplitude step in morning standup prep

## What It Covers

### 1. Core Platform Metrics (from Amplitude)
- **DAU Escorts** — Julius's North Star. WoW direction + 7-day moving average. Flag if >10% swing.
- **DAU Clients** — Christoph metric. WoW direction. Flag if declining >5% 3 days in a row.
- **W1 Retention cohort trend** — weekly cohort W1% over last 4 cohorts. Must show trend, not a single number.
- **Daily Signups** — escorts and clients separately. WoW direction.
- **Signup → Plus Conversion** — Andre's metric. Current rate vs. last period.

### 2. Sian Messenger (from Amplitude)
- **Sian WAU** — query `messenger opened` event filtered by `platform = android`. WoW direction.
- Flag anomalies vs. expected post-launch growth curve.

### 3. Active Experiments
For each experiment currently running:
- Name + hypothesis one-liner
- Days running + sample size
- Current direction (positive/negative/flat) + significance status
- Recommended action: wait / check / act

### 4. AI Assistant Usage (once beta is live)
- Suggestions shown per session
- Suggestion acceptance rate (accepted / shown)
- Acceptance rate trend WoW
- If not yet live: skip this section entirely, do not show empty placeholders.

### 5. Sprint Health Mini-Digest
- Days remaining in sprint + % of sprint elapsed
- Tickets: Done / In Progress / Blocked counts
- One-line sprint goal feasibility signal: on track / at risk / off track
- Source: Jira (active sprint board)

### 6. Stakeholder Callouts
Map anomalies to the stakeholder who owns them:
- **Julius flag:** Any DAU Escorts movement >±10% WoW
- **Andre flag:** Conversion rate movement or experiment with significance reached
- **Christoph flag:** DAU Clients declining trend or W1 retention regression
- Only surface a callout if there's actually something to flag. Never generate empty callouts.

### 7. Follow-up Items (1–5 max)
Concrete investigation items that the data raised. Not generic observations — specific actionable questions.
Example: "Escort DAU dropped 8% Monday–Tuesday — check if this correlates with the inbox folders deploy on Monday."
Skip this section if nothing concrete surfaced.

---

## Output Format

Single page, ~30–40 lines. Plain markdown. No tables unless comparing cohorts.

```
# Product Pulse — {{YYYY-MM-DD}}

## Headlines
- {{3-5 key bullets: what changed, what matters, directional signal}}

## Core Metrics
**DAU Escorts:** {{value}} ({{WoW %}} WoW) {{↑/↓/→}}
**DAU Clients:** {{value}} ({{WoW %}} WoW) {{↑/↓/→}}
**W1 Retention trend:** {{cohort 1 %}} → {{cohort 2 %}} → {{cohort 3 %}} → {{cohort 4 %}} {{improving/flat/declining}}
**Signups today:** {{escorts}}/{{clients}} escorts/clients
**Signup→Plus conversion:** {{%}} (prev: {{%}})

## Sian Messenger
**WAU:** {{value}} ({{WoW %}} WoW)
{{one line on trend}}

## Experiments
**{{Experiment name}}:** Day {{N}}, n={{size}}. {{direction}}. {{significance status}}. → {{wait/check/act}}

## Sprint Health
Day {{N}} of {{total}} ({{%}} elapsed). Done: {{N}} / In Progress: {{N}} / Blocked: {{N}}
Sprint goal: {{on track / at risk / off track}} — {{one sentence why}}

## Stakeholder Flags
{{Only show if there's something to flag. E.g.: "⚑ Julius: DAU Escorts -14% WoW — below 3-week average."}}

## Follow-ups
1. {{specific investigation item}}
2. {{...}}
```

---

## Execution Instructions

1. **Pull Amplitude data** using the Amplitude MCP. Use `query_chart` for DAU and retention metrics. Never use partial-day data — 7-day moving average only for DAUs.
2. **W1 retention:** Must query weekly cohort data showing W1% trend across last 4 cohorts — not a single aggregate number.
3. **Sian WAU:** Query `messenger opened` event filtered by `platform = android`. Do not use `sian_*` events.
4. **Experiments:** Use `query_experiment` in Amplitude for each active experiment. Pull current stats, not just names.
5. **Sprint data:** Use Jira API — active sprint board, count tickets by status column.
6. **Delta from last pulse:** If a previous pulse file exists in `01-sprint-operations/current/pulse-reports/`, load the most recent one and compute key metric deltas for the Headlines section.
7. **Save output** to `01-sprint-operations/current/pulse-reports/pulse-{{YYYY-MM-DD}}.md`.

## What This Skill Does Not Do

- Does not replace the full standup brief — it feeds into it as the Amplitude/metrics step.
- Does not make ship/kill decisions on experiments — that's experiment-analysis-workflow.md.
- Does not pull qualitative signals (Mattermost, user feedback) — standup prep handles that.
- Does not generate metrics that don't exist yet (AI assistant section stays silent until beta is live).

## Staleness Guard

If the most recent pulse file in `01-sprint-operations/current/pulse-reports/` is from today, ask: "A pulse was already run today ({{time}}). Run again or use the existing one?"

If the most recent sprint report (`01-sprint-operations/current/sprint-reports-*.md`) is older than 24 hours, prepend a warning to the output: "⚠ Sprint data may be stale — last sprint report was {{date}}."

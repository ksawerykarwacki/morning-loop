---
description: "Run morning standup prep, then recommend what to work on next. Optional: pass a team member's name for their personal brief (e.g. /standup Andres). No argument = full PO standup + next-best-actions for Tomek."
argument-hint: "[optional: team member name, e.g. Andres, David, Daniel, Xitong]"
---

# Morning Standup

Run the full standup workflow in sequence. All steps are mandatory unless a step's data source is unavailable. The point of the workflow is not just to report status — it is to gather every relevant signal and then **tell Tomek what to start working on next**, ranked and tied to the team's goals. Steps 1–6 gather context; Step 7 turns it into recommendations.

**Mode:** Check `$ARGUMENTS`.
- Empty or "Tomek" → **PO mode**: full brief — pulse, experiments, stakeholder flags, every.to digest, goal alignment, and Next Best Actions.
- Any other name (e.g. "Andres", "David") → **Team member mode**: personal ticket brief + sprint health + every.to digest + a suggested focus order. Skip stakeholder flags, experiment decisions, goals/OKR synthesis, and ads.

---

## Step 1: Meeting Notes Sync

Read the meeting-notes source from `meeting_source` in `agent-manager-config.yml`. **Default (`type: confluence_folder`):** list the child pages of `meeting_source.confluence_parent_page_id` in space `meeting_source.confluence_space` (the shared squad notes folder), and compare their page ids against `meeting_source.processed_log`. Any page not in that log is a new meeting note — read it and record its id. (For `type: granola`, use `mcp__granola__list_meetings` / `last_30_days`; for `type: local_dir`, diff the folder. Same contract either way.) Skip and note if the source is unreachable — never fabricate.

**Also extract open commitments (PO mode):** from the new notes, pull any action items, decisions, or promises **owned by Tomek** that are still open. Capture: the commitment, who's waiting on it, and the source meeting/date. These feed Step 7. If a commitment already has a Jira ticket, note the key so it isn't double-counted.

---

## Step 2: Product Pulse

Check if `01-sprint-operations/current/pulse-reports/pulse-{TODAY}.md` exists.
- **Exists** → load it, skip re-querying Amplitude.
- **Does not exist** → run the full pulse per `06-skills/skills/product-pulse.md` and save it. If the Amplitude MCP is not authenticated, do **not** silently fabricate numbers — note "Amplitude not connected; metrics carried from {last pulse date}" and load the most recent pulse instead.

In **team member mode**: load the pulse file if it exists (Tomek may have already run it). If not, run a lightweight version — DAU escorts 7D avg and any active experiments only. Skip full retention cohort analysis.

Extract from pulse:
- Sprint health signal (on track / at risk / off track)
- Any experiment reaching significance, or any past its decision window (overdue read)
- Stakeholder flags (PO mode only)

---

## Step 3: Every.to Digest

Fetch `https://every.to` — extract all article titles, authors, dates, and descriptions.

Load `06-skills/recipes/every-to-seen.md`. Skip any article already listed there.

If no new articles → output: "Every.to: nothing new." and continue.

For new articles: fetch up to 4 in parallel using WebFetch. Prioritise in this order:
1. Claude Code, Claude API, MCP, AI agents, agentic workflows
2. AI-native product management, PO or team workflows
3. AI adoption, team transformation, AI champions
4. Experiment design, product analytics, growth strategy
5. Any other framework applicable to a sprint team

For each relevant article produce:
- Title, author, date, URL
- 2–3 sentence summary
- **Apply:** specific actions referencing the team's actual context — escort AI assistant (KM-11720), client screening, Sian / Quick Check app, ECRM / acquisition-retention squad, Claude Code skills, po-workspace, Growth Circle

Skip articles with no plausible connection to product/team/AI work. If an article suggests a concrete action Tomek could take, carry it into Step 7 as a candidate (tagged "Learning").

In **team member mode**: include the same every.to digest — same articles, same content. Only the "Apply" actions should be reframed for a developer's perspective (e.g. "add eval cases to your PR" rather than "raise with the team").

Append newly fetched articles to `06-skills/recipes/every-to-seen.md`:
`- [YYYY-MM-DD] Title — URL`

---

## Step 4: Jira Sprint Tickets

Query Jira using the Atlassian MCP. Cloud ID: `54c58828-ac60-4b04-acd4-9cb19aaea61e`.

**PO mode JQL:**
```
project = KM AND sprint in openSprints() ORDER BY status ASC, updated DESC
```
Summarise: counts by status; In Progress / Code Review / Testing / PO Review tickets with assignees; anything updated in last 24h; anything **stuck in the same status 3+ days** (stale). Note tickets that are one push from Done (Code Review / Testing) — these are low-effort, high-ROI candidates for Step 7.

`openSprints()` returns multiple squads (KMMS, KMP) and paginates past 100 — results are a floor, not a precise tally; say so. Focus the read on the acquisition-retention / CRM&AI squad's tickets.

**Team member mode JQL** (substitute the actual name from `$ARGUMENTS`):
```
project = KM AND sprint in openSprints() AND assignee = "{name}" ORDER BY status ASC
```
List every ticket for that person: key, summary, current status, last updated. Flag any stuck in the same status for 2+ days.

If Jira returns too many results (token-limit error), the output is saved to a file — extract compact fields with `jq` (`.issues.nodes[] | {key, status, assignee, summary}`) or hand it to a subagent. Do not Read the raw file directly.

---

## Step 5: Team Goals & Commitments (PO mode only)

**Skip in team member mode.** This step grounds the recommendations in what the squad is actually trying to achieve.

Read, in order:
1. **Current OKRs.** The newest OKR doc in `01-sprint-operations/planning/` (glob `*okr*` / `*okr*proposal*`, take the latest), and the OKR block in the most recent `02-stakeholder-comms/updates/growth-circle-update-*.md`. Capture each Objective + KR with its target. These are the season's goals.
2. **Squad allocation** — who owns which objective (Tomek vs Arame vs platform/CRM), so recommendations land on Tomek's lane and aren't someone else's job.
3. **Previous standup brief** — the most recent `01-sprint-operations/current/standup-prep-*.md`. Pull its "Next Best Actions" and "Today" so today's recommendations show continuity (what carried over, what's now done, what slipped).

Build a quick **goal-coverage map**: for each KR, is there in-flight sprint work moving it? Mark each KR as `covered` (active ticket/experiment), `thin` (some work but at risk), or `uncovered` (no in-flight work). Uncovered/thin KRs that sit in Tomek's lane are the strongest candidates for "start next."

---

## Step 6: ExoClick Ads Check (PO mode only)

**Skip entirely in team member mode.**

Run the daily ExoClick pacing check + UTM audit via the agent's own venv (no `uv`/PATH dependency).
Working dir: `04-features/kaufmich-ads-agent`. Runner: `.venv/bin/python`.

**Live-mode guard — run this first:**
```
.venv/bin/python -c "from dotenv import load_dotenv; load_dotenv(); import os; print('MODE='+(os.environ.get('ADS_MODE') or 'mock'))"
```
- If it does NOT print `MODE=live` → output **"Ads check: SKIPPED — runtime not in live mode (would show mock data)"** and move on. Do **not** report any pacing numbers. This prevents the brief from ever showing fixture data as if it were the real account.
- If `MODE=live` → proceed:

```
.venv/bin/python scripts/daily_pacing.py --network exoclick
.venv/bin/python scripts/audit_utm.py --network exoclick
```

This is **read-only** — it never applies a mutation (no `--notify`; the digest lands in the brief, not a webhook). Summarise into the brief's Ads section:
- pacing flags (🟢 AUTONOMOUS vs 🔴 ESCALATE counts + one line each), or "no flags"
- any UTM non-compliance (e.g. capitalized `utm_source=ExoClick` fragments Amplitude attribution — flag for fix; carry into Step 7 if it gates a launch)
- if there are **0 enabled campaigns**, say so plainly ("nothing live to pace yet")

**To act on a flag:** do NOT attempt mutations here — the `kaufmich-ads` MCP isn't loaded in po-workspace, and autonomous apply stays off until CPA targets are set (needs Iren). Point to: *"open the ads project (`04-features/kaufmich-ads-agent`) and run the daily pacing prompt to apply."*

---

## Step 7: Next Best Actions — Synthesis (PO mode)

This is the payoff. Cross-reference everything gathered in Steps 1–6 and produce a **ranked list of what Tomek should work on next**. Do not just restate status — make a call.

**Inputs to weigh:**
- **Goal coverage** (Step 5): uncovered/thin KRs in Tomek's lane → things to *start*.
- **Momentum** (Step 4): tickets in Code Review/Testing that one nudge takes to Done → high-ROI *ship* actions.
- **Decision debt** (Steps 2, 4): experiments past their read window, tickets stale 3+ days, anything waiting on a Tomek decision → *decide / unblock*.
- **Open commitments** (Step 1): meeting action items Tomek owns with no movement → *don't-drop* items.
- **Risk flags** (Step 2): pulse risks (e.g. retention decline) with no owner → *assign / investigate*.
- **Calendar pressure**: GC Thursday, season kickoff, sign-offs, demos due this week → *prep*.
- **Learning** (Step 3): a high-value idea worth a small experiment → optional *learning* action.

**Ranking heuristic** — sort by (impact on a goal × urgency) ÷ effort. A blocked-revenue or blocked-launch item with a named waiter outranks a nice-to-have. Prefer actions that unblock *others* (the team is idle without them) over solo work. Cap at **5–7 actions**.

**Output each action as:**
- **[Category] One-line action** — categories: `Ship`, `Unblock`, `Decide`, `Start`, `Prep`, `Investigate`, `Learning`
- **Why:** the goal/KR it serves + why now (urgency / who's waiting)
- **Effort:** S / M / L (rough)
- **First step:** the single concrete thing to do first (a ticket to move, a person to message, a query to run)

Then add:
- **One thing if you only do one:** the single highest-leverage action, called out.
- **Don't drop:** open commitments (Step 1) with no in-flight ticket — short list so they aren't lost.

Be honest about uncertainty: if a recommendation rests on a number you couldn't refresh (e.g. Amplitude offline), say the recommendation is provisional on that data.

**Team member mode** — produce a lighter **Suggested Focus Order** instead: order their own tickets by what to touch first (Code Review/Testing to unblock reviewers → anything stale/blocked → in-progress), one line of why each. No OKR-level strategy.

---

## Step 8: Compose the Brief

**PO mode output:**

```
# Standup Brief — {DATE}
Sprint {name}, Day {N} of {total}.  [or: season-transition / cooldown note]

## Next Best Actions
1. **[Category] Action** — Why: {goal/KR + urgency}. Effort: {S/M/L}. First step: {…}
2. …
(5–7 items, ranked)
**If you only do one:** {the one}
**Don't drop:** {open commitments with no ticket}

## My Update
**Yesterday:** [tickets moved to Done or CR since yesterday]
**Today:** [top 1–2 priorities — should match the top of Next Best Actions]
**Blockers:** [any]

## Goal Alignment
[Per KR in Tomek's lane: covered / thin / uncovered, one line each. Flag uncovered KRs.]

## Team Check-ins
- **{Developer}:** "[targeted question about their specific ticket]"
[3–4 people max — prioritise Code Review queue and anyone at risk]

## Sprint Goal Check
[on track / at risk / off track] — [one sentence why]
"[Question to ask the team today]"

## Experiment / Launch Callouts
[Only include if there's a real signal or decision needed]

## Ads Check — ExoClick
[From Step 6. Pacing flags or "no flags". UTM compliance. If 0 enabled campaigns: "nothing live to pace yet."]

## Every.to Digest
[Article summaries with Apply sections — omit if nothing new]

## Learning / Tool Update
[One-liner on the most actionable every.to finding → specific next action]
```

**Team member mode output:**

```
# Standup Brief — {NAME}, {DATE}
Sprint {name}.

## Suggested Focus Order
1. {ticket} — {why touch first}
2. …

## Your Tickets
| Key | Summary | Status | Last Updated |
|-----|---------|--------|--------------|
[full list of their tickets]

**Attention needed:** [any ticket stuck, blocked, or in CR >1 day]

## Sprint Health
[on track / at risk / off track] — [one sentence]

## Every.to Digest
[Same articles as PO mode, Apply sections reframed for developer perspective]
```

---

## Step 9: Save Output

Save the brief to `01-sprint-operations/current/standup-prep-{DATE}.md`.
If team member mode, save to `01-sprint-operations/current/standup-{NAME}-{DATE}.md`.

---

## Sharing This Command With the Team

This file lives at `.claude/commands/standup.md` in the po-workspace repo. Anyone with Claude Code who clones or pulls this repo can run `/standup` or `/standup {their name}`.

**To install globally** (so it works in any directory, not just po-workspace):
Copy this file to `~/.claude/commands/standup.md`. Update the Jira cloud ID and every.to seen log path if needed.

**Prerequisites for team members:**
- Claude Code installed
- Atlassian MCP configured (`mcp__claude_ai_Atlassian__*` tools available)
- Amplitude MCP configured (for pulse — optional, PO typically runs this first)
- Meeting notes read from the shared Confluence folder via the Atlassian MCP (see `meeting_source` in config; Granola is an optional personal alternative, not required)

**What each person gets:**
- A ranked **what-to-do-next** list (PO) or **suggested focus order** (team member)
- Their own Jira ticket list filtered by their name
- Sprint health + goal alignment (PO)
- Every.to digest (same articles, developer-framed Apply sections)
- Saved brief they can paste into standup

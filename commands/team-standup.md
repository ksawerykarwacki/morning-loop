---
name: team-standup
description: "Personal daily standup brief for any team member. Pulls your active sprint tickets from Jira, generates a standup update, and delivers a digest of the latest Every.to articles with specific actionable ideas for your work. Run as /team-standup or /team-standup {your name}."
argument-hint: "[optional: your name, e.g. Andres, David, Daniel, Xitong, Tomek]"
---

# Team Standup Skill

Generates a personal standup brief in two parts: your Jira ticket status for today's standup, and a digest of the latest Every.to articles with actionable ideas you can apply to your work.

Takes ~60 seconds. No setup required beyond having Jira (Atlassian MCP) and web access.

---

## Phase 0 — Identify Who Is Running This

Check `$ARGUMENTS`:
- If a name is provided → use it as the team member name for Jira filtering
- If empty → ask using AskUserQuestion: "What's your name? (Used to filter your Jira tickets)" with options: Andres, David, Daniel, Xitong, Tomek, Other

Map common names to Jira display names for the query:
- Andres → "Andres Cagua"
- David → "David Predusel"
- Daniel → "Daniel Zhu"
- Xitong → "Xitong Deng"
- Tomek → "Tomek Duda"
- If Other → ask for their exact Jira display name

---

## Phase 1 — Your Jira Tickets

Query Jira using the Atlassian MCP.
- **Cloud ID:** `54c58828-ac60-4b04-acd4-9cb19aaea61e`
- **JQL:** `project = KM AND sprint in openSprints() AND assignee = "{display name}" ORDER BY status ASC`
- **Fields:** summary, status, updated, priority, issuetype
- **Max results:** 25

For each ticket produce a one-line entry:
`{KEY} | {STATUS} | {summary truncated to 60 chars} | last updated {N days ago or "today"}`

Then generate the standup text:

**Yesterday:** Tickets moved to Done or Code Review since yesterday (updated >= yesterday). If none visible, say "No status changes detected — check manually."

**Today:** Tickets currently In Progress or in a review state that need action. Prioritise: anything in Code Review >1 day (needs a nudge), anything blocked, anything due at sprint end.

**Blockers:** Any ticket stuck in the same non-Done status for 3+ days, or any ticket that mentions a dependency in the summary.

If Jira returns no tickets for the person → say so clearly and suggest checking their username spelling.

---

## Phase 2 — Every.to Digest

### Step A: Fetch the homepage
Use WebFetch on `https://every.to` with prompt: "List all articles visible with title, author, date, section, and one-sentence description."

### Step B: Deduplicate
Read `$KM_ROOT/state/every-to-seen.md` (create it if it doesn't exist — start empty). Relocated here 2026-09-01 from `.claude/every-to-seen.md`: the latter was blocked from writing 6+ consecutive runs when this skill ran inside a sub-agent session, and Andres confirmed this file should be personal, machine-local state rather than git-tracked/team-shared going forward (see `ac-state-location.md`'s convention).
Skip any article whose title already appears in that file.
If all articles are already seen → output "Every.to: nothing new since last check." and skip to Phase 3.

### Step C: Fetch new articles (parallel, max 4)
For each new article not in seen log, use WebFetch to get the full content.
Prompt: "Summarize the key argument, frameworks, tools, and practical takeaways. Be specific about what can be applied and how."

**Prioritise articles in this order:**
1. Claude Code, MCP, AI agents, agentic workflows, prompt engineering
2. AI-native ways of working, AI-assisted development, developer productivity
3. Product management, experiment design, feature development, user research
4. Team workflows, async communication, sprint/agile practices
5. Any tool, framework, or mental model applicable to a software product team

**Skip** articles about: pure finance/investing, journalism, creative writing craft, topics with no plausible connection to building software products.

### Step D: Write the digest
For each relevant article:

```
**{Title}** — {Author}, {Date}
{URL}
{2–3 sentence summary of the core argument}
**Ideas for your work:**
- {Specific actionable idea tied to KM/escort AI assistant/client screening/Sian/daily dev workflow}
- {Another specific idea — reference a real tool they use: Claude Code, Jira, Amplitude, Mattermost}
- {Optional third idea if genuinely distinct}
```

The "Ideas for your work" bullets must be concrete and specific — not "consider using AI more" but "when writing acceptance criteria for KM-XXXXX, try the ce-brainstorm pattern: define the problem in one sentence before writing any requirement." Reference the team's actual product context (escort CRM, AI assistant suggestions, client screening, Sian messenger) and tools (Claude Code, Jira, Mattermost).

If an article has nothing applicable after reading → skip it silently.

### Step E: Update seen log
Append newly fetched articles to `$KM_ROOT/state/every-to-seen.md`:
```
- [YYYY-MM-DD] {Title} — {URL}
```
This file is personal, machine-local state (relocated 2026-09-01) — it no longer benefits from git-tracked team-wide deduplication.

---

## Phase 3 — Compose and Output the Brief

```markdown
# Standup — {NAME}, {DATE}

## Your Update

**Yesterday:**
{1–3 bullets of what you completed or progressed}

**Today:**
{1–3 bullets of what you're working on}

**Blockers:**
{Any blockers, or "None"}

---

## Your Sprint Tickets

| Key | Status | Summary | Updated |
|-----|--------|---------|---------|
{one row per ticket}

---

## Every.to — What's New

{Article digests with Ideas for your work}

--- OR ---

Every.to: nothing new since last check.
```

---

## Sharing This Skill

**To use this in your own Claude Code setup:**

1. Copy this file to `.claude/commands/team-standup.md` inside any repo you work in
2. Run `/team-standup` or `/team-standup {your name}` from that repo
3. The Every.to seen log defaults to `.claude/every-to-seen.md`, shared in the repo — commit it so the whole team shares deduplication. (Andres's own setup instead points this at `$KM_ROOT/state/every-to-seen.md` — personal state, not shared — after the git-tracked path was blocked from writing across sub-agent sessions for 6+ consecutive runs; adjust per-adopter if the same write-block shows up elsewhere.)

**Requirements:**
- Claude Code installed
- Atlassian MCP configured (provides `mcp__claude_ai_Atlassian__*` tools)
- Web access for Every.to fetching

**No Amplitude access needed** — this skill does not query analytics. It is purely for personal standup prep and learning.

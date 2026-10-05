---
name: ops-update
description: Write the bi-weekly ops update: what the squad achieved, what is blocked, what is next, in the format the ops meeting and its Confluence page expect. Use on "generate ops update", "prepare ops meeting update", "what did we achieve and what are we blocked on", "ops update for Confluence".
---

# Ops Update Skill

## Trigger Phrases
- "Generate ops update"
- "Prepare ops meeting update"
- "What did we achieve and what are we blocked on"
- "Ops update for Confluence"
- "Bi-weekly ops update"
- "do standup"
- "standup"

## Description
Produces two outputs:
1. **Ops update** — clean bullet-point update covering what the team achieved and what external blockers exist. Copy-paste ready for Confluence.
2. **Every.to intelligence brief** — reviews the latest articles from every.to through the lens of Tomek's setup, team, active projects, and OKRs, and proposes concrete improvements to one or more of those areas.

Runs after sprint-reporting (Phase 1) so it can read the sprint data without re-querying Jira.

## Configuration
```yaml
workspace: . (the workspace you run /morning from)
sprint_report: sprint-reports-[latest-timestamp].md  # read from workspace root
meeting_notes: 10-meeting-notes/                     # read files from last 7 days
output_file: ops-update-[YYYYMMDD].md               # workspace root
```

## Cadence
Bi-weekly — run at the end of each sprint alongside the end-of-sprint workflow. The Every.to brief runs each time the skill runs (it fetches live content, so it is always current).

---

## Workflow

### Step 1: Load Inputs

**Pre-flight check — run before anything else:**
Scan the sprint report for unfilled `[REQUIRES PO INPUT]` markers, specifically in the `## 🚨 Risks & Blockers` section and `## 📝 Key Decisions Made` section. If any are found, stop and tell the user: "The sprint report has unfilled placeholders — please fill in [list them] before I generate the ops update, or confirm I should skip them." Do not generate Confluence-paste output with raw `[REQUIRES PO INPUT]` strings.

1. Find the most recent `sprint-reports-*.md` in the workspace root — this is the primary data source
2. Read it to extract: Done tickets, In Progress tickets, blockers already identified
3. Read meeting notes from `10-meeting-notes/` for files dated within the last 7 days — scan for:
   - Any blockers or impediments raised in ceremonies or 1:1s
   - Any issues escalated or flagged by team members
   - Any decisions that are still pending and blocking work
4. Check the sprint report's `## 🚨 Risks & Blockers` section — this is the primary blocker source

### Step 2: Build the Achievements List

Extract what the team actually delivered over the last two weeks. Source: Done tickets from the sprint report.

**Framing rules:**
- Write outcomes, not ticket summaries. Not "KM-12345 moved to Done" — write "Launched X so that users can Y"
- Group related tickets into a single achievement bullet where they form one coherent delivery
- Lead with the most impactful achievement (OKR-linked items first)
- Keep each bullet to one line — concrete and specific
- Do not include tickets that are still In Progress or in review — only Done
- **If Done = 0:** Write "No tickets completed this sprint — work was in-flight at report time." Then list the active In Progress items as context (e.g. "In flight: [ticket summaries]") but do NOT frame them as achievements.
- If a ticket was done but has no clear user-facing outcome (e.g. a refactor, a config change), still include it but frame as an enabling step: "Completed infrastructure work to unblock X"
- Maximum 8 bullets — if more Done tickets exist, group the smaller ones

**Format:**
```
**What we achieved (last 2 weeks)**
• [Outcome-framed achievement]
• [Outcome-framed achievement]
...
```

### Step 3: Build the Issues and Blockers List

Extract what is currently stopping the team or slowing delivery. Sources (in priority order):
1. Sprint report `Risks & Blockers` section
2. Meeting notes from last 7 days — any impediment raised in standups, 1:1s, or planning
3. In Progress tickets that have been stuck for >5 days without movement (flag as stale)
4. Any `[REQUIRES PO INPUT]` markers in the sprint report that point to unresolved dependencies

**Framing rules:**
- Write each blocker as: what is blocked + what help is needed + from whom (if known)
- Be specific about what "help" means — a decision, a resource, access, a dependency resolved, etc.
- Do not include issues the team can resolve internally — only things that need external input or escalation
- If an issue has an owner who can unblock it, name them (e.g. "Awaiting legal sign-off from [Legal team]")
- If there are no external blockers, say so explicitly: "No external blockers this sprint"

**Format:**
```
**Issues / blockers we need help with**
• [What's blocked — what help is needed — from whom]
• [What's blocked — what help is needed — from whom]
...
```

### Step 4: Add Context Header

Add a one-line header above the two sections:

```
**Sprint [N] Update — [ECRM squad] — [date range]**
```

### Step 5: Save Output

Save to:
```
02-stakeholder-comms/updates/ops-update-[YYYYMMDD].md
```

Overwrite if a file for the same date exists. Do not accumulate old ops updates in the same file.

---

## Output Format

The complete output (copy-paste ready for Confluence):

```markdown
**Sprint [N] Update — ECRM squad — [start date] – [end date]**

**What we achieved (last 2 weeks)**
• [Achievement 1 — outcome framing, OKR-linked items first]
• [Achievement 2]
• [Achievement 3]
...

**Issues / blockers we need help with**
• [Blocker 1 — what's blocked, what help is needed, from whom]
• [Blocker 2]
...
(or: No external blockers this sprint)
```

No markdown headers, no tables, no REVIEW flags — this is for direct Confluence paste.

---

## Quality Checks

Before saving:
- [ ] All achievements are outcome-framed, not ticket summaries
- [ ] No In Progress or Review tickets included in achievements
- [ ] Every blocker names what help is needed and from whom (if known)
- [ ] No internal issues that the squad can resolve themselves
- [ ] Header includes sprint number and correct date range
- [ ] Output is plain bullet points — no extra markdown formatting
- [ ] If no external blockers exist, that is stated explicitly (not just an empty section)

## Common Mistakes to Avoid

- ❌ Listing ticket IDs or Jira keys in achievements — write outcomes
- ❌ Including "In Progress" work as achievements — only Done counts
- ❌ Vague blockers like "we're waiting on some things" — name the specific dependency
- ❌ Including squad-internal issues as blockers — only things that need outside help
- ❌ Fabricating metrics or outcomes not in the sprint report
- ❌ Writing more than 8 achievement bullets — group minor items

---

## Phase 2: Every.to Intelligence Brief

Runs immediately after the ops update is saved. Fetches the latest articles from every.to, selects the most relevant ones, reads them in full, and produces a brief that connects the content to Tomek's specific situation — setup, team, active projects, and OKRs.

This section is **for Tomek only** — it is appended to the ops-update file after a clear separator and is never included in Confluence output.

---

### Step 6: Discover Latest Articles

Use the every.to sitemap to find the most recently published content:

1. Fetch `https://every.to/sitemap.xml` — this returns a sitemap index
2. Fetch `https://every.to/sitemaps/posts-1.xml` — this contains the most recent posts with `<lastmod>` dates
3. Sort by `lastmod` descending and extract the **10 most recent article URLs**
4. Note titles are not in the sitemap — URLs alone are enough to infer topic from the slug

**Do not guess or fabricate URLs.** Only use URLs returned by the sitemap.

---

### Step 7: Select Articles to Read

From the 10 most recent URLs, select the **3–5 most relevant** based on slug keywords. Relevance scoring — prioritise articles whose slugs suggest topics in this list (in priority order):

1. AI for product managers, POs, or non-engineers
2. AI workflow automation, agentic work, delegation vs. collaboration
3. AI-native team culture, AI adoption, change management
4. Specific tools Tomek uses: Claude, Claude Code, Amplitude, Jira, Notion, Figma
5. Product strategy, user research, experiment design
6. Any other AI/LLM topic with plausible application to product work

Skip articles that are clearly outside scope: biotech, finance, creative writing for its own sake, model benchmarks with no workflow angle.

---

### Step 8: Read Selected Articles

For each selected article, fetch the full URL and extract:
- The central argument or thesis
- Any specific techniques, workflows, or commands described
- Concrete recommendations or examples
- Any limitations or failure modes noted

Fetch all selected articles in parallel for speed.

---

### Step 9: Analyse Through Tomek's Lens

For each article (or group of related articles), identify what is applicable to Tomek's specific situation. Use this context to filter and frame:

**Tomek's setup:**
- Claude Code as primary tool; po-workspace with custom skills (sprint-reporting, ops-update, data-analysis, okr-tracker, stakeholder-comms)
- Jira MCP, Amplitude MCP, Granola meeting notes, Confluence for documentation
- Automation scripts in `05-automation/sprint-sync/`
- Sprint cadence: 2-week sprints, ceremonies (planning, refinement, review, retro, standup)

**Tomek's team (ECRM squad at Kaufmich):**
- Mathieu (design), Xitong (backend), Andres (frontend/full-stack), Chris (bizops/announcements), Maria (scrum master), David (full-stack), Liah (user research), Rainer (QA/ops)
- Team is in early stages of AI-native adoption — Tomek is AI champion

**Tomek's active projects (read from memory index at session start if available):**
- AI assistant for escorts (reply suggestions, internal testing upcoming)
- AI assistant for clients ("Sia" / Ask Sia — wizard-of-oz profile info in messenger)
- Sian Messenger app launch (Android live, iOS pending App Store)
- ECRM escort interviews (6 done, synthesis in progress)
- Client & escort onboarding checklist experiments
- Client screening improvements

**Tomek's OKRs:**
- O1: AI-native team transformation (KR 1.1–1.4 — squad AI adoption evidence)
- O2: AI assistant for escorts + Sian WAU + hypothesis validation + dev-ready backlog

**Framing rules for analysis:**
- Be specific — "you could apply this to X project by doing Y" beats "this is interesting"
- Prefer short-term actions (this sprint or next) over long-term vision
- If an idea requires significant new infrastructure, note the effort honestly
- Connect to a named project or OKR where possible
- If an article has nothing applicable, say so in one sentence and move on — do not pad

---

### Step 10: Write the Intelligence Brief

Format:

```
---
## Every.to Intelligence Brief — [date]
*Not for Confluence — PO reading only*

### Articles reviewed
- [Article title] — [author] — [URL]
- ...

### What's applicable to your situation

**[Theme or article title]**
[2–4 sentences: what the article argues + how it connects to a specific project, tool, team dynamic, or OKR. End with a concrete suggestion: what to try, build, or change.]

**[Next theme]**
[Same structure]

...(repeat for each applicable article or cluster)

### Suggested next action
[Single most impactful thing to do based on this reading — one sentence, specific and actionable.]
```

Maximum 5 "applicable" bullets. If fewer than 3 articles are relevant, still write the brief — quality over coverage.

---

### Step 11: Append to Ops Update File

Append the intelligence brief to the same file saved in Step 5:

```
02-stakeholder-comms/updates/ops-update-[YYYYMMDD].md
```

Append after a clear separator — do not overwrite the Confluence section:

```markdown


---
<!-- EVERY.TO BRIEF — NOT FOR CONFLUENCE -->
[intelligence brief content]
```

---

### Phase 2 Quality Checks

Before finishing:
- [ ] URLs came from the sitemap — none were guessed or fabricated
- [ ] Articles were read in full, not summarised from slug alone
- [ ] Every "applicable" bullet names a specific project, tool, or OKR
- [ ] Suggested next action is one concrete sentence, not a list
- [ ] The brief is clearly separated from the Confluence section in the file

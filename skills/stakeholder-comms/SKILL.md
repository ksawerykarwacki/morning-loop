---
name: stakeholder-comms
description: Turn a report, brief, incident, or announcement into channel-appropriate updates for each audience that needs it. Use on "draft comms from this", "tailor this for stakeholders", "who needs to know about this and how", "turn this into channel updates". Respects the three-channel structure: GC Confluence page, Escort CRM, KM Growth.
---

# Stakeholder Comms Skill

## Trigger Phrases
- "Generate stakeholder updates from this"
- "Tailor this for stakeholders"
- "Draft comms from this [report/brief/incident/announcement]"
- "Who needs to know about this and how"
- "Transform this into channel updates"
- "Prepare comms for this decision/launch/experiment/finding"
- "Write up stakeholder updates"

## Description
Transforms any source document — sprint report, decision brief, incident summary, feature announcement, experiment result, research finding — into channel-appropriate stakeholder communications. Reads the communication matrix for stakeholder preferences and produces ready-to-send outputs for the right channels, with a checklist and human-review flags.

## Configuration
```yaml
workspace: /Users/tomek/Projects/po-workspace
communication_matrix: 02-stakeholder-comms/communication-matrix.md
context_file: 00-core/CLAUDE.md
output_file: stakeholder-updates-batch.md   # overwritten on each run
```

## Channels (always apply this model)

| Channel | Audience | When to use | Language |
|---------|----------|-------------|----------|
| Growth Circle Confluence page | Christoph, Andre, Julius, Ying, Baohua, Arame, Iren | Sprint progress, OKR impact, roadmap, blockers, dependency asks, discussion items — weekly Thursday meeting | English |
| Growth Circle Mattermost | Same as above | Async flags between meetings — dependency alerts, decisions, time-sensitive signals. For launches: goes out FIRST, before briefing the team | English |
| Escort CRM channel | Squad + Maria, Mathieu, Liah, Chris, supporters + interested observers | Team announcements, decisions, anything the team needs to act on | English |
| Supporter channel | Daniel, Reiner, Jasmin, Sascha | Pre-launch briefings — context of what's launching, FAQ link, what questions to expect. Always requires ✅ read confirmation reaction. Send before escorts receive any communication | Bilingual (German + English, German first) |
| KM Growth channel | All Kaufmich employees | Launches, experiment learnings, research discoveries, open asks for help. Covers all audiences — no need to duplicate | English |
| Figma / specific tools | Mathieu (design) | Design-specific feedback, context for design tasks | English |
| 1:1 DMs | Julius (ad-hoc), Andre (specific asks), Maria (urgent coordination) | Rare exceptions only — not a default output | English |

**Language rule:** All Mattermost channel communication is in English, except the Supporter channel which is always bilingual (German first, then English in the same message).

## Workflow

### Step 1: Load Inputs

**Minimum input check — run before anything else:**
If the source input is fewer than 50 words, or is ambiguous (a single URL with no context, a one-word description, an image file), stop and ask: "What should I base these updates on? I need at least: what happened, any relevant dates, and the business impact." Do not generate channel drafts from insufficient input — the output would be fabricated context with no factual basis.

1. Read the source document (provided by user — any format)
2. Read `02-stakeholder-comms/communication-matrix.md` for stakeholder preferences
3. Read `00-core/CLAUDE.md` for OKR context, decision log, and product principles

### Step 2: Classify the Source Document

Identify document type — this determines channel routing:

| Document Type | GC Confluence | GC Mattermost | Escort CRM | Supporter channel | KM Growth | 1:1 DM |
|---------------|:---:|:---:|:---:|:---:|:---:|:---:|
| Sprint report | ✅ (full update) | ✅ if >2 days to meeting | ✅ | — | Only if something launched | Rare |
| Decision brief | ✅ (discussion item) | ✅ if urgent | ✅ (team context) | — | — | If exec sign-off needed |
| Incident/outage | — | ✅ (urgent flag) | ✅ (team action) | ✅ if affects support queries | ✅ if company-wide | — |
| Feature announcement | — | ✅ (first — inform stakeholders) | ✅ (then team) | ✅ (before escort comms go out) | ✅ (once launch is underway) | — |
| Experiment result | ✅ (OKR section) | If significant/urgent | ✅ | — | ✅ if major learning | — |
| Research finding | ✅ | — | ✅ | — | ✅ if actionable for wider team | — |
| Roadmap update | ✅ | Only if urgent | ✅ | — | — | — |

**Key rules:**
- For **feature announcements**, the order is always: GC Mattermost → Escort CRM → Supporter channel → KM Growth. Stakeholders first, then team, then company — never the reverse.
- If in doubt whether KM Growth is warranted, ask: is this relevant to someone outside the squad and Growth Circle? If yes, use it. If no, skip it and say why.
- Supporter channel is needed for any launch that changes what escorts see or how they interact with the platform — anything that will generate support queries.

### Step 3: Extract Stakeholder-Relevant Content

For each channel output, apply the relevant stakeholder filters from `communication-matrix.md`:

**Growth Circle audience — what each person needs:**
- **Christoph:** Roadmap progress or risk, directional trend data, is delivery on track
- **Andre:** Hypothesis → data → conclusion structure; any claim needs data backing
- **Julius:** Top-line impact on escorts (DAU, safety, AI adoption); frame as "here's what we're seeing — your read?"
- **Ying:** OKR progress, process compliance, honest gaps
- **Baohua / Arame:** Cross-squad dependencies or capacity implications only
- **Iren:** Raw metric data, not just conclusions; link to underlying data if available

**Escort CRM audience — what to include:**
- What's happening and why
- What the team needs to do or know
- The "why" behind decisions, not just the what
- Tone: casual, transparent, honest about problems

**KM Growth audience — what to include:**
- The outcome/learning/launch in plain language
- What it means for the wider team (why they care)
- Any open ask — specific, untagged, open to whoever has capacity
- Tone: slightly more formal than Escort CRM, still direct

### Step 4: Draft Each Output

For each channel that applies, write a complete draft:
- Use the format that matches the channel (Confluence template for GC, Mattermost-formatted text for channels)
- Apply individual stakeholder considerations within GC outputs (Christoph gets risk framing, Andre gets evidence structure, etc.)
- Mark items that need human input with `[REVIEW: reason]`

**Growth Circle Confluence page** — follow the template from `06-skills/skills/growth-circle-update.md`:
```
## 📊 Roadmap Status
## 🎯 Next Milestone
## ✅ Progress This Week
## 📈 OKR Impact
## 🤝 Dependencies & Collaboration
## 🚨 Blockers & Help Needed
## 💬 Discussion Items
## 🎯 Next Week's Focus
```

**GC Mattermost** — short, punchy, max 5 lines. Include what you're flagging, why it's async (not waiting for Thursday), and what (if anything) you need from them.

**Escort CRM channel** — conversational Mattermost format. Lead with what happened, then what the team needs to know or do. Include Chris/Maria/Mathieu-relevant context inline if it applies to them specifically.

**KM Growth channel** — announcement format. Lead with the result or learning. If it's an open ask, include exactly what you need and how to respond.

**Figma comment** — context-first format: explain the user problem and the "why" before any design direction.

**1:1 DM** — use sparingly. Flag with `[REVIEW: confirm whether this warrants a DM]` unless the context makes it obvious.

### Step 5: Apply [REVIEW] Markers

Flag any of the following with `[REVIEW: reason]`:

| Situation | Marker example |
|-----------|----------------|
| Metric that should be verified before sending | `[REVIEW: confirm DAU figure against Amplitude before posting]` |
| Claim that could be sensitive or premature | `[REVIEW: check with Christoph before putting this in writing]` |
| Sequencing dependency | `[REVIEW: Escort CRM must go out before KM Growth — confirm team is aligned]` |
| Ask that requires exec sign-off | `[REVIEW: does this ask need Andre's approval first?]` |
| Content that could misrepresent team performance | `[REVIEW: confirm this characterisation with Maria]` |
| Anything where you don't have enough information | `[REVIEW: PO to fill in — [what's missing] not determinable from source doc]` |

### Step 6: Generate Ready-to-Send Checklist

At the top of the output file, produce a checklist table:

```markdown
## Ready to Send

| Output | Channel | Action | Dependency |
|--------|---------|--------|------------|
| [name] | [channel] | ☐ Send / ☐ Post / ☐ Update | [any prerequisite] |
| ...    | ...     | — Not warranted ([reason]) | — |
```

For outputs not being generated, always explain why (e.g., "KM Growth — not warranted: no launch or company-wide learning in source doc").

### Step 7: Save Output

Save to `stakeholder-updates-batch.md` in the workspace root. Overwrite if it exists.

Structure:
```markdown
# Stakeholder Updates — [Source Doc Type]: [Brief Title]
*Generated: [date] | Source: [filename or description]*

---

## Ready to Send
[checklist table]

---

## Output 1: Growth Circle Confluence Page
[full GC update or N/A with reason]

---

## Output 2: Growth Circle Mattermost
[short async message or N/A with reason]

---

## Output 3: Escort CRM Channel
[team post or N/A with reason]

---

## Output 4: KM Growth Channel
[company-wide post or N/A with reason]

---

## Output 5: [Tool-specific — Figma, etc.]
[only if applicable]

---

## Output 6: 1:1 DMs
[only if genuinely warranted — each flagged with REVIEW marker]
```

## Mattermost Posting

**Current status:** No Mattermost MCP connection is available in this workspace. All Mattermost outputs must be posted manually — copy the text from the relevant output section and paste into the channel.

**If a Mattermost MCP becomes available in future:**
- Check for it by calling the MCP's list or authenticate tool at skill start
- If available, offer to post directly after human review of the draft
- Always show the draft and get confirmation before posting — Mattermost posts are visible immediately and cannot be easily retracted
- Never post to KM Growth automatically — it reaches all employees and always requires human review first

**Formatting notes for Mattermost:**
- Bold: `**text**`
- Bullet points: `•` or `-`
- Code blocks: backtick-fenced
- No markdown headers (H1/H2) — they don't render in Mattermost; use bold text instead
- Keep posts under ~300 words for channels; shorter for DMs

## Confluence Posting

Use `mcp__claude_ai_Atlassian__updateConfluencePage` or `mcp__claude_ai_Atlassian__createConfluencePage` if the MCP is authenticated.

For Growth Circle updates, the page lives in the **Escort CRM & Companion AI** Confluence space. The page is updated weekly — find the current week's GC page and update it, rather than creating a new one each time.

## Quality Checks

Before finalising output:

- [ ] Every metric cited is traceable to the source document or flagged [REVIEW: verify]
- [ ] No fabricated metrics — use `[REQUIRES PO INPUT]` for gaps
- [ ] All [REVIEW] markers have a specific reason, not just "check this"
- [ ] GC Confluence content follows the growth-circle-update.md template structure
- [ ] Escort CRM post does not contain confidential stakeholder dynamics (that's for GC)
- [ ] KM Growth post is self-contained — readers outside the squad have full context
- [ ] Sequencing noted in checklist where Escort CRM must precede KM Growth
- [ ] 1:1 DMs are rare and each one is justified with a clear reason
- [ ] N/A outputs include a reason, not just silence

## Common Mistakes to Avoid

- ❌ Generating one update per stakeholder sent as individual DMs — use channels, not DMs
- ❌ Posting the same content to all channels — each channel gets a different angle
- ❌ KM Growth for routine sprint progress — it's for launches, learnings, and open asks only
- ❌ For feature announcements: briefing the team before informing the Growth Circle — GC Mattermost goes first
- ❌ Andre-style evidence structure in the Escort CRM channel — that's for GC, not the team
- ❌ Leaving [REVIEW] items unmarked because "the PO probably knows" — always flag explicitly
- ❌ Assuming the source document has all the data needed — flag gaps clearly
- ❌ Generating user-facing content (DMs to escorts, forum posts, app store listings) — that belongs in Chris's brief, not in stakeholder comms outputs. Skill output covers internal channel communications only.
- ❌ Writing internal channel posts in German — all Mattermost channels are in English, except the Supporter channel which is always bilingual (German first, then English)
- ❌ Omitting links in launch posts — always include the relevant link (app, experiment report, research doc) and FAQ link in every channel post for launches

## Example Usage

```
User: "Generate stakeholder updates from this experiment result brief"
→ Reads brief + communication matrix
→ Classifies as: experiment result
→ Generates: GC Confluence (OKR impact section) + KM Growth (significant learning) + Escort CRM (team context)
→ Skips: GC Mattermost (meeting is Thursday, experiment result can wait), 1:1 DMs
→ Flags: [REVIEW: confirm statistical significance before posting to KM Growth]

User: "Transform this incident report for stakeholders"
→ Reads report + communication matrix
→ Classifies as: incident/outage
→ Generates: GC Mattermost (urgent async flag) + Escort CRM (team action required) + KM Growth (if user-facing)
→ Skips: GC Confluence (incident details don't belong in weekly update template)
→ Flags: [REVIEW: confirm incident is fully resolved before KM Growth post]

User: "Draft comms for the Android app launch"
→ Reads launch brief + communication matrix
→ Classifies as: feature announcement
→ Generates: GC Mattermost (first — inform stakeholders) + Escort CRM (team alignment) + Supporter channel (bilingual DE+EN, ✅ confirmation, before escorts receive comms) + KM Growth (once launch is underway)
→ Skips: GC Confluence (not a weekly update item — add to Thursday's page instead), user-facing DM/forum templates (those belong in Chris's brief)
→ Flags: [REVIEW: confirm UTM-tracked app link and FAQ link before any post goes out]
→ All posts in English except Supporter channel (German + English)
```

---
name: growth-circle-update
description: Draft Tomek's weekly Growth Circle section in the Squad Leader Forum format: the terse written fields plus row-level deltas to the experiment pipeline table. Use on "growth circle update", "GC update", "prepare my update for Thursday", "weekly stakeholder update". Reads the previous week's update as the shape to match.
---

# Growth Circle Weekly Update Skill

## Overview
Automated weekly stakeholder update generation that aggregates sprint progress, experiment results, and OKR impact for Thursday Growth Circle meetings. Transforms scattered data sources into a concise, stakeholder-ready update in Tomek's voice.

## Format: the new Squad Leader Forum format (current, from Jul 2026)
The GC meeting moved to a **Squad Leader Forum** format. Tomek's section is short and signal-dense, not the old long bullet dump. It is a **Loom recording plus a few punchy written fields plus deltas to the experiment pipeline table**:

```
🔵 ECRM — Tomek
Loom: [link]
Experiments live + hypothesis documented: ✅ / ❌ / ⚠️ partial
Early signal:
Delivered/worked on this week (not experiments):
OKR update:
What's not working + why:
What I need from this room:

| Milestone | Month | Status | Blocker |
|---|---|---|---|
| M1 ... | | | |
| M2 ... | | | |
| M3 ... | | | |
```

The written fields carry the facts; the **Loom carries the narrative and the color** (so the writing stays terse). The full template lives at the GC space page for the week (e.g. `.../GC/pages/.../2026-07-02+GC+Meeting+Squad+Leader+Forum`). The **legacy plain-text format** (Next milestone / What shipped / Impact on OKR / Dependencies / Blockers / Next week) is preserved further down for reference and for any stakeholder who still wants the long form, but the Squad Leader Forum format is now primary.

## Tomek's voice (match this — it is the point of the update)
Learned from ~7 weeks of his actual updates. Preserve these in every format:
1. **Radically honest about misses.** Every update names what did not work, plainly ("missed support brief / FAQ / German translation on Quick Check"; "onboarding checklist treatment performed worse than control"; "validated 1 of 3 hypotheses"). Never bury bad news. This is the signature move.
2. **Constructive framing of misses.** A miss is paired with the fix ("turning the gap into a launch-readiness checklist that gates every future experiment"; "regrouping with Mathieu and Iren on the next iteration"). Honest, not self-flagellating.
3. **Every claim is quantified.** Real numbers, always: "4,200 survey responses", "156 WAU", "224 downloads", "270x faster", "75% would be disappointed", "6 escorts", "O2 KR2 at 66%". No "progressing well".
4. **Named ownership.** People are named against their work (Iren, Mathieu, Anna, Liah, Maria, Xitong, David, Andres, Dan Z, Baohua, Arame, Chris). Asks are addressed to a named person.
5. **OKR-tied.** Progress is mapped to O1/O2/O3 and specific KRs, with % where known.
6. **Linked to artifacts.** Confluence pages, prototypes, dashboards, worklogs are linked, not described.
7. **Precise experiment status.** "live" vs "in review" vs "in staging test env" vs "launching tomorrow" — never blur these.
8. **Legal is a standing blocker line.** Nearly every update carries a specific legal ask with the named blocker and who is waiting.
9. **First person, plain, direct.** "I", "we"; no corporate hedging; bad news stated flatly.
10. **Numeric OKR targets are always "needs Iren input"** until she confirms (per the analyst rule).

## Triggers
- **Scheduled**: Every Thursday morning before Growth Circle meeting
- **Manual**: "Prepare Growth Circle update", "Generate stakeholder update", "Weekly progress report"

## Key Capabilities
1. **Commitment Accountability**: Reviews previous week's promises and tracks delivery status
2. **Sprint Progress Analysis**: Identifies tickets moved to Done/Ready for Release since last Thursday
3. **Experiment & KPI Tracking**: Fetches latest Amplitude data for active experiments and OKR metrics
4. **Roadmap Alignment Check**: Compares current progress against seasonal milestones
5. **Dependency Resolution Tracking**: Monitors previously blocked items and their current status
6. **Next Week Planning**: Generates focused priorities with realistic scope based on track record

## Required Files & Data Sources
- **Previous Update**: Last week's Growth Circle Confluence page (baseline comparison)
- **Jira API**: Board 1847 for sprint progress (check both active and recent sprints)
- **Amplitude API**: Active experiments (search for ECRM/escort-related experiments)
- **Team Context**: Current sprint goals, team capacity, holidays/absences
- **Output Location**: `02-stakeholder-comms/updates/growth-circle-update-[YYYY-MM-DD].md`

## Two Growth Circle Communication Modes

**1. Confluence page (primary):** The structured weekly update using the template below. Filled out before Thursday's Growth Circle meeting and presented live alongside other POs. This is the main artifact.

**2. Growth Circle Mattermost channel (async companion):** Used between meetings to flag dependencies, ask for decisions, or share urgent signals that can't wait until Thursday. Not a substitute for the Confluence page — use it sparingly for things that are genuinely time-sensitive. A short channel message pointing to the Confluence page is also appropriate after posting the update, if the meeting is more than 2 days away.

## Process Flow

### 1. Data Collection Phase
- Check for active sprints (may be in "future" state if between sprints)
- Fetch tickets changed since last Thursday
- Get experiment status from Amplitude (especially AI Assistant, Client Screening)
- Identify resolved vs new blockers

### 2. Reality Check Phase
- Verify actual progress vs claims (don't assume interviews happened)
- Check if dependencies are truly resolved or just "in progress"
- Validate experiment status (running vs paused vs not started)

### 3. Synthesis Phase
- Use [REQUIRES PO CONTEXT] for unknowns
- Focus on deliverables, not activities
- Translate technical work to business impact

## Output Format — Squad Leader Forum (primary)

Fill each field terse and factual; push narrative into the Loom. Use the status emoji the template uses (✅ / ❌ / ⚠️).

```
🔵 ECRM — Tomek
Loom: [link, recorded by Tomek after the section is written]

Experiments live + hypothesis documented: [✅ / ❌ / ⚠️ partial — then one line: what is live, what is imminent, are hypotheses documented]

Early signal:
- [the 2-4 realest signals this week, quantified + linked; wins and metric reads]

Delivered/worked on this week (not experiments):
- [work that is not an experiment but is worth the room knowing; action points owed from last week's GC go here]

OKR update:
- [KR x.y] ([the metric, baseline to target]): **[on track | thin | at risk | mixed]**. [the one-line reason, with the current number]
- [KRs you did not assess this week, named explicitly rather than silently omitted]

What's not working + why:
- [the honest misses, each with the cause and the fix in flight — Tomek's signature section]

What I need from this room:
- [named ask]: [specific thing, why now]
```

### The OKR update field is now standard, and it is per-KR

Added 2026-08-20 from the live page: Tomek added an `OKR update` bullet to his section himself, and Meta Search carries a full per-objective OKR table. It is no longer optional.

Write **one line per KR you own**, each with:
- the KR number and its metric, baseline to target
- a **verdict word**: `on track`, `thin`, `at risk`, or `mixed`
- the **current number**, and the single reason for the verdict

Then **name the KRs you did not assess this week explicitly**. "KR 1.3, 2.1, 2.3, 2.4: not assessed this week" is honest and takes one line. Silently omitting them reads as coverage you do not have, and it is the thing a steering read catches.

Do not write a milestone-style table here unless the destination page has one for your squad. Meta Search uses tables because their section is built that way; the ECRM section is bullets. Mirror your own section, not theirs.

### The experiment pipeline table: emit DELTAS, never a table

**There is no milestone table in the ECRM section.** Verified live on the destination page 2026-08-19: milestone status arrives through Ying's Pulse excerpt, not from you. Do not write one. (This skill described one for months and it was never used.)

What the ECRM section does carry is an **experiment pipeline table that already exists on the page and persists week to week**:

```
| Experiment | KPI | Expected lift | Launch status | Signal window |
```

**Do not draft this table.** Two consecutive draft-vs-posted pairs (2026-08-06, 2026-08-20) show the drafted table being discarded both times. In the first the schema was invented and wrong. In the second the schema was correct, mirrored from the live page, and it was *still* discarded, because Tomek edits the existing table in place. A rendered table is a replacement; a table on a live page is an amendment. Handing over seven fresh rows makes him reconcile them by hand against the eight already there.

**So fetch the live table and output only what changes**, in this shape:

```
### Pipeline table: 5 changes

CHANGE  Reactivation campaign     Launch status: `LIVE` -> `ROLLING OUT`
CHANGE  Refiner Surveys           Launch status: `Development in progress` -> `DONE`
CHANGE  Intent Driven Signup      Launch status: `Development started` -> `LIVE`
CHANGE  First Message Helper      Launch status: `In Refinement` -> `DEVELOPMENT IN PROGRESS`
ADD     New & Hot Escorts near you | Profile visits per client | TBD | IN RESEARCH |
NO CHANGE  Tags, Quick Check, Sian iOS App Launch
```

Rules for the deltas:
- **Quote the current cell value before the arrow.** If you cannot read the live page, say so and emit nothing for this table rather than guessing what it currently says.
- **List the unchanged rows explicitly** under NO CHANGE. Silence reads as "not checked", and a row nobody updates for three weeks is itself a finding.
- **Never blank a populated cell.** Writing "Not re-verified this week" over existing content destroys information the page already had. If you could not verify it, it is NO CHANGE.
- An ADD needs all five columns filled or an honest `TBD`.

### The Loom is not yours to draft
Tomek records the Loom **last**, after his written section is assembled, and he speaks it in his own
words from what is already on the page. Do not produce talking points, a script, or a suggested arc
for it. Drafting them wastes the run and gets discarded every time.

What helps instead: make the written fields sharp enough that the Loom is easy to speak from, and
name the single signal worth leading with. That is all the input the recording needs.

## Output Format — legacy plain-text (reference only)

Prior format, kept for reference. No emojis, no markdown headers, no tables. Plain section labels, bullet points. "Next milestone" always comes first. Sections separated by a blank line.

```markdown
Next milestone:
[One specific deliverable, not an activity — what the squad is driving toward right now]

What shipped/Progress last week
- [Concrete thing that is done or meaningfully advanced — include numbers where available]
- [Another shipped item or notable progress update]
- [Research/discovery: state actual output, e.g. "spoke to 6 escorts" not "interviews ongoing"]
- [AI/team progress: e.g. "individual learning journeys in progress for 6 team members"]

Impact on OKR
- [OKR connection: hypothesis validated, metric moved, workflow adopted — be specific]
- [Raw metric if available: e.g. "169 downloads of Sian on Android"]
- [Prototype or experiment status: what exists, where to see it]

Dependencies/Collaboration work needed
- [Team or person]: [specific ask or action, with timing if relevant]

Blockers? Help Needed?
[Team or owner if known] — [blocker description]:
- [Specific thing that is blocked]
- [Specific thing that is blocked]
- [What is needed to unblock]

Next week's focus
- [Specific deliverable or action — who does what]
- [Specific deliverable or action]
- [Specific deliverable or action]
- [Specific deliverable or action]
```

## Usage Examples
```bash
# Generate full Growth Circle update
claude "Generate Growth Circle update for this week"

# Quick status check
claude "Am I on track for Growth Circle? Any red flags?"

# Focus on specific aspect
claude "What's our OKR impact this week for Growth Circle?"

# Validate before meeting
claude "Review my Growth Circle update - anything missing?"
```

## Quality Checks
1. **Accuracy over Optimism**: Don't claim progress that hasn't happened
2. **Specifics over Generics**: "1 escort responded" not "recruitment ongoing"
3. **Dependencies Reality**: "Resolved" means actually working, not promised
4. **Blocker Clarity**: Each blocker needs owner and specific ask
5. **Next Week Feasibility**: Don't overcommit given capacity

## Common Mistakes to Avoid
- ❌ Don't write the Squad Leader Forum fields as long bullet dumps — they are terse; the narrative goes in the Loom
- ❌ Don't write a milestone table. The ECRM section has none; milestone status comes via Ying's Pulse excerpt
- ❌ Don't hand over a rebuilt experiment pipeline table. Emit row-level deltas against the live one, and never blank a populated cell
- ❌ Don't skip the "What's not working + why" section — the honest miss is Tomek's signature; an update with no miss reads as spin
- ❌ Don't assume interviews/launches happened without checking
- ❌ Don't report "3 escorts confirmed" when it's "1 responded"
- ❌ Don't mark dependencies resolved until actually working
- ❌ Don't use vague language like "progressing well" or "ongoing" — quantify or state status precisely
- ❌ Don't report on experiments without checking Amplitude for actual numbers
- ❌ Don't put a numeric OKR target in as fact — mark it "needs Iren input" until confirmed
- ❌ Don't use em dashes in the output (house rule) — this update gets shared
- (Legacy plain-text format only: no emojis/tables/headers — does not apply to the Squad Leader Forum format above)

## Real-World Example Issues
```
# WRONG: Over-formatted
## ✅ Progress This Week
### Shipped/Ready for Release
**Sian launch**: Communicated to escorts

# RIGHT: Plain format
What shipped/Progress last week
- Sian communicated to 1,000 most active escorts on Android; forum post published, FAQ shared with support team

# WRONG: Assuming progress
"3 escorts confirmed for interviews"  # When actually 1 responded

# RIGHT: Accurate status
"1 escort responded (Easter week impact), continuing outreach"

# WRONG: Optimistic dependency
"AI Squad dependency resolved"  # When just promised

# RIGHT: Precise status
"AI Squad: staging access granted, deployment in progress"
```

## Integration Notes
- **Jira Quirks**: Check "future" sprints if no "active" sprint found
- **Amplitude**: Search for experiments by KM ticket number (e.g., "KM-10720")
- **Holiday Awareness**: Account for reduced responses during holidays
- **Team Capacity**: Note when team is at partial capacity (e.g., ANT learning)

## Data Source Priority
1. **Primary**: Live Jira API data for sprint progress
2. **Secondary**: Amplitude for experiments and metrics
3. **Tertiary**: Team communication (Mattermost, standups)
4. **Fallback**: Previous updates for context continuity

## Stakeholder-Specific Considerations

### For Andre (CPO)
- Lead with business impact and strategic alignment
- Quantify everything possible
- Prepare data backup for any claims
- Focus on OKR progression

### For Growth Circle
- Balance technical progress with business outcomes
- Highlight cross-squad dependencies clearly
- Be realistic about next week's commitments
- Flag risks early and explicitly

### For Team
- Share draft before meeting for input
- Highlight their achievements
- Protect from overcommitment
- Translate stakeholder feedback clearly

## Automation Opportunities
1. **Data Aggregation**: Script to pull Jira + Amplitude data
2. **Template Population**: Auto-fill standard sections
3. **Change Detection**: Highlight what's different from last week
4. **Validation Checks**: Flag missing sections or suspicious data
5. **Distribution**: Auto-post to Confluence and Mattermost

## Success Metrics
- **On-Time Delivery**: Update ready 1 hour before meeting
- **Accuracy Rate**: <5% corrections needed post-meeting
- **Completeness**: All template sections filled
- **Stakeholder Satisfaction**: Positive feedback or no questions
- **Team Alignment**: Team agrees with characterization

## Escalation Triggers
- Sprint goal <50% complete by Thursday
- Critical dependency not resolved
- Major experiment showing negative results
- Team capacity severely impacted
- Roadmap milestone at risk

## Post-Meeting Actions
1. Extract action items from discussion
2. Update tickets with decisions made
3. Communicate changes to team
4. Schedule follow-ups on blockers
5. Document any strategy pivots
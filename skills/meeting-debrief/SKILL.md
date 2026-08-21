---
name: meeting-debrief
description: Turn a meeting transcript or notes into decisions, action items, open questions, and draft Jira tickets, calibrated for PO operations. Use on "debrief this meeting", "what came out of this", "extract action items", "turn this into tickets", or whenever a transcript is pasted in or a Granola meeting is referenced.
---

# Meeting Debrief

## Description
Transforms meeting transcripts or notes into structured, actionable output specifically calibrated for PO operations: decisions with stakeholder implications, action items with sprint integration, open questions with escalation paths, and draft Jira tickets aligned with current workflow. Cross-references with previous debriefs, decision logs, and stakeholder communications to surface patterns and unresolved items. Maintains institutional memory integrated with existing PO documentation structure.

## Triggers
Use this skill whenever the user wants to debrief a meeting or process meeting outcomes:

**Direct Debrief Requests:**
- 'debrief this meeting', 'process my meeting', 'what came out of this meeting'
- 'extract action items', 'meeting notes', 'turn this into tickets'
- 'what should I do next' (with recent meeting transcripts available)

**PO-Specific Processing:**
- 'sprint planning debrief', 'stakeholder meeting outcomes', 'Growth Circle decisions'
- 'retrospective action items', 'refinement outcomes', 'incident debrief'

**Integration Requests:**
- 'add to decision log', 'create tickets from this', 'track these decisions'
- 'update stakeholders on outcomes', 'sprint backlog updates'

**File-Based Processing:**
- Any mention of meeting transcript or recording files
- Providing transcript files for structured output
- Batch processing of multiple meeting files

The debrief is the bridge between meetings and execution — turning discussions into trackable, actionable outcomes.

## Role
You are a sharp, PO-calibrated meeting assistant who transforms discussions into execution. Not a meeting summarizer, but a strategic processor who understands stakeholder dynamics, regulatory constraints, sprint operations, and escalation requirements. Your job is to extract what matters for product execution: decisions with their stakeholder implications, actions with their sprint impact, and questions with their escalation paths.

You understand the PO's specific environment: Growth Circle decision authority, Andre's data requirements, Julius's business focus, regulatory compliance needs, and team capacity constraints.

## Enhanced Input Handling

The user will provide one of:
- **A transcript pasted straight into the prompt.** This is how transcripts actually arrive, in
  every observed case: a block starting `Meeting Title: ... Date: ... Transcript:`. Process it in
  place. Do not ask for a file path and do not go looking in Granola for something already pasted.
- Meeting transcript file (Granola, Zoom, etc.)
- Meeting notes in markdown or text
- File path or folder containing transcripts
- Reference to existing meeting documentation

**Context Integration Before Processing:**
1. Check current sprint status and capacity
2. Review recent decision logs for related topics
3. Reference stakeholder communication patterns
4. Check regulatory compliance implications
5. Identify Growth Circle escalation requirements

**Batch Processing:**
If provided a folder, process each transcript and create:
- Individual debriefs for each meeting
- Cross-meeting pattern analysis
- Consolidated action item list with sprint implications

## Workflow

### Step 1: Enhanced Context Analysis

**Read and Parse with PO Context:**
- **Meeting metadata:** Date, time, participants, meeting type
- **Stakeholder identification:** Andre, Julius, Growth Circle members, team members
- **Meeting classification:** Sprint ceremony, stakeholder update, Growth Circle review, incident response, technical planning
- **Regulatory context:** Any compliance-related discussions
- **Sprint context:** Relation to current sprint goals and capacity

**Enhanced Meeting Type Detection:**
- **Sprint Ceremonies:** Standup, planning, review, retrospective, refinement
- **Stakeholder Meetings:** Growth Circle, executive updates, cross-functional alignment
- **Operational:** Incident response, technical planning, user research
- **Strategic:** Product strategy, roadmap planning, competitive analysis

### Step 2: PO-Enhanced Decision Extraction

**Decision Categories:**
1. **Product Decisions:** Feature scope, user experience, technical approach
2. **Strategic Decisions:** Roadmap priorities, competitive positioning, business model
3. **Operational Decisions:** Process changes, team structure, tool adoption
4. **Escalation Decisions:** Items requiring Growth Circle approval or stakeholder sign-off

**Enhanced Decision Capture:**
```markdown
**Decision:** {Clear, one-sentence decision}
**Owner:** {Decision maker - with stakeholder role context}
**Category:** {Product/Strategic/Operational/Escalation}
**Context:** {Why decided, trade-offs considered}
**Stakeholder Impact:** {Andre/Julius/Growth Circle implications}
**Confidence:** {Firm/Tentative/Needs Validation}
**Implementation:** {Sprint impact, resource requirements}
**Regulatory:** {Compliance implications if any}
```

**Stakeholder-Specific Decision Flags:**
- 🔴 **Growth Circle Required:** Decisions exceeding PO authority
- 📊 **Andre Input Needed:** Technical architecture or data implications
- 💼 **Julius Approval Required:** Business model or resource allocation impact
- ⚖️ **Legal Review:** Regulatory compliance implications

### Step 3: Sprint-Integrated Action Item Extraction

**Enhanced Action Item Categories:**
1. **Immediate (Today/Tomorrow):** Critical blockers, stakeholder communications
2. **Current Sprint:** Work fitting in current capacity
3. **Next Sprint:** Items for upcoming planning
4. **Backlog:** Longer-term items requiring estimation

**Action Item Structure:**
```markdown
**Action:** {Specific task starting with verb}
**Owner:** {Responsible person with role context}
**Category:** {Immediate/Current Sprint/Next Sprint/Backlog}
**Deadline:** {Explicit or sprint-relative}
**Sprint Impact:** {Capacity, dependencies, priorities}
**Stakeholder Dependency:** {Approvals or input needed}
**Source:** {Meeting context that triggered this}
**Estimated Effort:** {T-shirt sizing if evident}
```

**PO-Specific Action Types:**
- **Sprint Management:** Backlog updates, story creation, acceptance criteria
- **Stakeholder Communication:** Updates, approvals, escalations
- **User Research:** Interview planning, synthesis, insights
- **Technical Coordination:** Architecture decisions, technical debt, performance
- **Compliance:** Legal reviews, regulatory updates, documentation

### Step 4: Enhanced Open Questions Processing

**Question Categories:**
1. **Blocking:** Prevents sprint progress
2. **Strategic:** Affects roadmap or product direction
3. **Technical:** Architecture or implementation approach
4. **Regulatory:** Compliance or legal implications
5. **Stakeholder:** Requires external input or approval

**Open Question Structure:**
```markdown
**Question:** {Clear question statement}
**Impact:** {What's blocked or at risk}
**Category:** {Blocking/Strategic/Technical/Regulatory/Stakeholder}
**Escalation Path:** {Who can resolve this}
**Timeline:** {When resolution is needed}
**Sprint Impact:** {Effect on current/next sprint}
**Suggested Next Step:** {Specific action to resolve}
```

### Step 5: Advanced Cross-Referencing

**Integration with Existing Documentation:**
1. **Decision Logs:** Check `02-stakeholder-comms/decisions/` for related decisions
2. **Sprint Operations:** Reference `01-sprint-operations/current/` for capacity context
3. **Stakeholder Communications:** Review recent patterns and commitments
4. **Feature Documentation:** Connect to existing feature specs in `04-features/`

**Enhanced Pattern Detection:**
- **🔄 Recurring Unresolved:** Items appearing across multiple debriefs without resolution
- **📈 Escalating Priority:** Topics gaining urgency across meetings
- **⚠️ Stakeholder Misalignment:** Conflicting expectations between stakeholders
- **🚨 Compliance Risk:** Regulatory topics without clear resolution
- **⏰ Timeline Pressure:** Decisions being rushed without proper validation

**Cross-Reference Analysis:**
```markdown
### Cross-Meeting Patterns
**Recurring Items:** {Items from previous debriefs still unresolved}
**Decision Contradictions:** {New decisions conflicting with previous ones}
**Stakeholder Pattern:** {Trends in Andre/Julius/Growth Circle involvement}
**Sprint Pattern:** {How decisions affect sprint velocity and capacity}
**Escalation Pattern:** {Items consistently requiring higher-level input}
```

### Step 6: Enhanced Jira Ticket Suggestions

**Ticket Categories with PO Context:**
- **FE:** Frontend user experience improvements
- **BE:** Backend functionality and technical requirements
- **RESEARCH:** User research and validation
- **COMPLIANCE:** Regulatory and legal requirements
- **SPIKE:** Technical investigation or proof of concept
- **EPIC:** Large features requiring breakdown

**Enhanced Ticket Structure:**
```markdown
### [PREFIX] {Descriptive title}

**User Story:** As a [user type], when I [context/state], I want [goal], so that [outcome].

**What:** {2-4 sentences on scope and deliverables}

**Why:** {Business/user justification from meeting context}
- **Meeting Source:** {Date and decision/action that triggered this}
- **Stakeholder Priority:** {Andre/Julius/Growth Circle priority level}
- **Sprint Timing:** {Current/Next/Backlog recommendation}

**Acceptance Criteria:**
- {Outcome-focused, testable criteria}
- {Include compliance requirements if applicable}
- {Specify stakeholder approval points}

**Implementation Notes:**
- **Dependencies:** {Technical, design, or stakeholder dependencies}
- **Regulatory:** {Compliance considerations}
- **Performance:** {Scalability or performance requirements}
- **Analytics:** {Tracking and measurement requirements}

**Stakeholder Sign-off Required:** {Andre/Julius/Growth Circle checkboxes if applicable}
```

**Ticket Validation:**
- ✅ **Ready for Creation:** Clear scope, strong why, defined acceptance criteria
- ⚠️ **Needs Clarification:** Missing details, weak justification
- 🔴 **Blocked:** Dependencies or approvals required first

### Step 7: Enhanced Decision Log Integration

**File Location Integration:**
- Primary decision log: `02-stakeholder-comms/decisions/decision-log-{YYYY}.md`
- Feature-specific decisions: `04-features/{feature}/decisions/`
- Sprint operation decisions: `01-sprint-operations/decisions/`

**Enhanced Decision Log Format:**
```markdown
## {YYYY-MM-DD} — {Meeting Type}: {Topic}
**Participants:** {List with roles}
**Sprint Context:** {Current sprint, capacity implications}

### Decisions Made
1. **{Decision}**
   - **Owner:** {Name and role}
   - **Category:** {Product/Strategic/Operational/Escalation}
   - **Stakeholder Impact:** {Andre/Julius/Growth Circle implications}
   - **Implementation:** {Sprint/timeline impact}
   - **Source Quote:** "{Direct quote if significant}"

### Escalations Required
- **Growth Circle:** {Decisions requiring formal approval}
- **Legal Review:** {Compliance-related decisions}
- **Technical Architecture:** {Andre's domain decisions}

### Sprint Implications
- **Capacity Impact:** {How decisions affect current sprint}
- **Backlog Changes:** {New priorities or scope changes}
- **Dependencies Created:** {Cross-team or external dependencies}
```

### Step 8: Stakeholder Communication Integration

**Auto-Generate Stakeholder Updates:**
Based on decisions and actions, suggest stakeholder communications:

**For Andre (Technical Focus):**
- Technical decisions and their implications
- Performance or scalability impacts
- Data and analytics requirements

**For Julius (Business Focus):**
- Business impact of product decisions
- Resource allocation changes
- Competitive or market implications

**For Growth Circle (Strategic Oversight):**
- Decisions requiring formal approval
- Strategic direction changes
- Resource or timeline escalations

**Template Generation:**
```markdown
## Stakeholder Update: {Meeting Outcomes}
**Date:** {Meeting date}
**Next Actions Required:** {Approvals or input needed}

### Key Decisions for Your Awareness
{Stakeholder-relevant decisions with business context}

### Action Items Requiring Your Input
{Items where stakeholder involvement is needed}

### Growth Circle Escalations
{Formal decisions requiring Growth Circle approval}
```

### Step 9: Sprint Integration and Automation

**Current Sprint Integration:**
- Check current sprint capacity before suggesting work
- Flag items that can't fit in current sprint
- Identify dependencies that might affect sprint goals

**Automation Integration:**
- Connect to existing sprint sync workflows
- Generate backlog update suggestions
- Create refinement agenda items for complex decisions

**Sprint Impact Analysis:**
```markdown
### Sprint Implications
**Current Sprint Changes:**
- {Immediate capacity impacts}
- {New blockers or dependencies}
- {Scope adjustments needed}

**Next Sprint Planning:**
- {Items for upcoming sprint planning}
- {Capacity requirements}
- {Stakeholder input needed before planning}

**Backlog Updates:**
- {New items to add}
- {Priority changes}
- {Items to remove or defer}
```

### Step 10: Enhanced Reporting

**Debrief Summary for User:**
1. **Immediate Actions Required (Today/Tomorrow):**
   - Stakeholder communications needed
   - Blockers to address
   - Urgent decisions to implement

2. **Sprint Impact:**
   - Capacity changes
   - New dependencies
   - Backlog adjustments

3. **Stakeholder Escalations:**
   - Growth Circle approvals needed
   - Andre/Julius input required
   - Legal or compliance reviews

4. **Pattern Insights:**
   - Recurring unresolved items
   - Decision contradictions
   - Process improvement opportunities

5. **Documentation Updated:**
   - Decision logs
   - Action item tracking
   - Stakeholder communication queue

## Advanced Features

### **Regulatory Compliance Tracking**
- Automatically flag compliance-related decisions
- Track regulatory requirement fulfillment
- Generate compliance review action items

### **Stakeholder Sentiment Analysis**
- Track stakeholder engagement and concerns
- Identify misalignment early
- Suggest proactive communication

### **Meeting ROI Assessment**
- Evaluate decision quality vs. meeting time investment
- Identify recurring topics without resolution
- Suggest process improvements

### **Cross-Team Dependency Mapping**
- Track dependencies created in meetings
- Identify potential bottlenecks
- Suggest coordination meetings

### **Sprint Velocity Impact Prediction**
- Estimate how decisions affect sprint capacity
- Flag potential velocity impacts early
- Suggest scope adjustments

## Integration Points

**With Existing PO Workflow:**
- Sprint planning and backlog management
- Stakeholder communication patterns
- Decision documentation standards
- Regulatory compliance processes

**With Team Operations:**
- Current sprint status and capacity
- Team member availability and skills
- Technical debt and constraint awareness
- Performance and scalability considerations

**With Stakeholder Management:**
- Growth Circle decision authority boundaries
- Andre's technical input requirements
- Julius's business approval needs
- Cross-functional coordination requirements

This enhanced skill provides comprehensive meeting processing specifically calibrated for your PO environment, integrating seamlessly with your existing workflow, stakeholder dynamics, and regulatory requirements.
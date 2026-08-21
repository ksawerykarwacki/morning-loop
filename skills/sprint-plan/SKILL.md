---
name: sprint-plan
description: Build a sprint plan from real capacity: carryover, dependencies, risks, and an achievable sprint goal. Use on "plan the sprint", "sprint planning prep", "what should go in the next sprint", "do we have capacity for this", or before the boundary-Monday planning session.
---

# Sprint Planning Generator
*For ECRM Squad - Escort Platform Sprint Planning*

## Purpose
Generate comprehensive sprint plans that account for real capacity, manage dependencies, identify risks, and ensure achievable sprint goals while handling carryover work effectively.

## Sprint Planning Framework

### 1. Pre-Planning Analysis (Before Sprint Planning Meeting)

#### Sprint Metrics Review
```markdown
## Previous Sprint Analysis
- **Velocity**: [X] story points completed / [Y] planned
- **Completion Rate**: [X]%
- **Carryover Work**: [X] hours / [Y] story points
- **Blockers Encountered**: [List main blockers]
- **Team Feedback**: [Key retrospective points]
```

#### Capacity Calculation Template
```markdown
## Sprint Capacity Calculation
**Sprint Duration**: [Start Date] - [End Date] ([X] working days)

### Developer Availability
| Developer | Available Days | PTO/Holidays | Meetings | Focus Time | Capacity (hours) |
|-----------|---------------|--------------|----------|------------|------------------|
| Andres Cagua | [X] | [X] | [X]h | [X]h | [X]h |
| Daniel Zhu | [X] | [X] | [X]h | [X]h | [X]h |
| Xitong Deng | [X] | [X] | [X]h | [X]h | [X]h |
| David Predusel | [X] | [X] | [X]h | [X]h | [X]h |
| **TOTAL** | | | | | **[X]h** |

### Capacity Adjustments
- **Buffer for Unknowns**: 20% (industry standard)
- **Support/Bug Fix Reserve**: 15%
- **Code Review Time**: 10%
- **Adjusted Capacity**: [X]h × 0.55 = **[Y]h**
```

### 2. Sprint Goal Definition

#### Goal Setting Template
```markdown
## Sprint Goal
**Theme**: [e.g., "Launch Messenger App and drive adoption"]
**Success Criteria**:
1. [Specific measurable outcome]
2. [Specific measurable outcome]
3. [Specific measurable outcome]

**Key Results**:
- [ ] [Deliverable 1]
- [ ] [Deliverable 2]
- [ ] [Deliverable 3]

**Dependencies**:
- [ ] [External team/system dependency]
- [ ] [Stakeholder approval needed]
- [ ] [Technical prerequisite]
```

### 3. Backlog Prioritization Matrix

#### Priority Scoring Framework
```markdown
## Priority Matrix
| Ticket | Business Value (1-5) | Effort (Hours) | Risk (1-5) | Dependencies | Priority Score | Include? |
|--------|---------------------|----------------|------------|--------------|----------------|----------|
| [KM-XXX] | | | | | | |

**Scoring Formula**: (Business Value × 2) - (Risk) - (Has Dependencies ? 2 : 0)
**Inclusion Criteria**: Priority Score > 5 AND fits in capacity
```

### 4. Sprint Backlog Composition

#### Recommended Sprint Mix
```markdown
## Sprint Composition
- **Sprint Goal Items**: 40-50% of capacity
- **Technical Debt/Improvements**: 20%
- **Bug Fixes**: 15%
- **Innovation/Experiments**: 10%
- **Buffer/Emergent Work**: 15%

## Selected Items
### Sprint Goal Work ([X]h)
- [ ] KM-XXX: [Title] ([X]h) - [Assignee]
- [ ] KM-XXX: [Title] ([X]h) - [Assignee]

### Carryover from Previous Sprint ([X]h)
- [ ] KM-XXX: [Title] ([X]h remaining) - [Assignee] - [Reason for carryover]

### Technical Debt ([X]h)
- [ ] KM-XXX: [Title] ([X]h) - [Assignee]

### Bug Fixes ([X]h)
- [ ] KM-XXX: [Title] ([X]h) - [Assignee]
```

### 5. Risk Assessment & Mitigation

#### Risk Identification Template
```markdown
## Sprint Risks
| Risk | Probability | Impact | Mitigation Strategy | Owner |
|------|-------------|--------|---------------------|-------|
| AI Squad dependency delays | High | High | Daily sync with AI Squad, have backup work ready | Tomek |
| App store rejection | Medium | High | Pre-review checklist, legal approval early | Andres |
| User research recruitment fails | Low | Medium | Chris has backup participants | Chris |
| [Risk] | [L/M/H] | [L/M/H] | [Strategy] | [Owner] |
```

### 6. Dependency Management

#### Dependency Tracking
```markdown
## Dependencies Map
### Internal Dependencies
- **AI Squad**:
  - [ ] [Specific deliverable needed] - Due: [Date]
  - [ ] Staging environment access - Due: [Date]
  
### External Dependencies
- **Legal Team**:
  - [ ] Consent form approval - Due: [Date]
  
### Technical Dependencies
- **Infrastructure**:
  - [ ] Database migration - Due: [Date]
  
### Mitigation Plans
- If [dependency] is delayed: [backup plan]
- If [dependency] is blocked: [escalation path]
```

### 7. Sprint Planning Meeting Agenda

#### Meeting Structure (2 hours)
```markdown
## Sprint Planning Meeting Agenda
**Date**: [Date] | **Duration**: 2 hours | **Attendees**: Squad + Stakeholders

### Part 1: Review & Goal Setting (30 min)
- [ ] Previous sprint metrics review (5 min)
- [ ] Sprint goal discussion & alignment (15 min)
- [ ] Capacity confirmation (5 min)
- [ ] Questions & clarifications (5 min)

### Part 2: Backlog Selection (60 min)
- [ ] Review prioritized backlog (10 min)
- [ ] Size estimation for new items (20 min)
- [ ] Dependency identification (10 min)
- [ ] Final selection & commitment (20 min)

### Part 3: Planning & Assignment (30 min)
- [ ] Task breakdown for complex stories (15 min)
- [ ] Assignment based on expertise (10 min)
- [ ] Risk review & mitigation (5 min)

### Wrap-up (10 min)
- [ ] Confirm sprint goal & success criteria
- [ ] Schedule key ceremonies
- [ ] Action items & follow-ups
```

## ECRM Squad Specific Templates

### Escort Platform Sprint Planning
```markdown
## Sprint: [Name] ([Start] - [End])
**Goal**: Launch and drive adoption of [Feature]

### Capacity Analysis
- **Total Days**: [X] working days
- **Team Size**: 4 developers + support
- **Raw Capacity**: 4 × [X] days × 6h = [Y]h
- **Adjusted for Reality**: [Y]h × 0.55 = [Z]h

### Current Context
- **Carryover Work**: 98h (from previous sprint)
- **AI Squad Dependencies**: [List specific items]
- **Messenger App Status**: [Current state]
- **User Research Status**: [Recruitment/interview progress]

### Priority Items
1. **KM-12134**: Submit Mobile App to Stores (CRITICAL PATH)
2. **KM-12139**: App Launch Content Package
3. **User Research**: [X] escort interviews scheduled
4. **AI Assistant**: Staging testing continuation

### Risk Mitigations
- **App Store Delay**: Have web-based backup ready
- **Low Adoption**: Prepare escort incentives
- **AI Blocking**: Descope AI features if needed
```

### Capacity Planning with Dependencies
```markdown
## Dependency-Aware Planning
### Week 1
**Available**: 4 devs × 5 days × 6h = 120h
**Allocated**:
- Messenger app work (no dependencies): 40h
- User research support: 10h
- Bug fixes: 15h
- Code reviews: 10h
**Buffer**: 45h

### Week 2
**Available**: 4 devs × 5 days × 6h = 120h
**Allocated**:
- AI Assistant work (BLOCKED until Day 3): 30h
- Messenger launch activities: 25h
- Technical debt: 20h
- Testing & deployment: 15h
**Buffer**: 30h

**Total Sprint Capacity**: 240h
**Total Allocated**: 165h
**Total Buffer**: 75h (31% - healthy)
```

## Quick Planning Checklist

### Before Planning
- [ ] Review previous sprint metrics
- [ ] Gather team availability/PTO
- [ ] Check dependency status with other squads
- [ ] Pre-groom top 20 backlog items
- [ ] Prepare sprint goal options
- [ ] Calculate realistic capacity

### During Planning
- [ ] Confirm sprint goal with team buy-in
- [ ] Size all selected items
- [ ] Identify all dependencies
- [ ] Assign owners to each item
- [ ] Document risks and mitigations
- [ ] Leave 20-30% buffer

### After Planning
- [ ] Share sprint plan with stakeholders
- [ ] Update Jira with sprint items
- [ ] Schedule dependency check-ins
- [ ] Communicate risks to Growth Circle
- [ ] Set up sprint monitoring dashboard

## Common Planning Pitfalls to Avoid

### Overcommitment
❌ **Bad**: "We can do 240h of work in a 240h sprint"
✅ **Good**: "We plan 165h of work in a 240h sprint (31% buffer)"

### Ignoring Dependencies
❌ **Bad**: "AI Squad said it'll be ready, so we'll plan for it"
✅ **Good**: "AI work goes in Week 2 with backup plan if delayed"

### Vague Sprint Goals
❌ **Bad**: "Improve the platform"
✅ **Good**: "Launch messenger app and achieve 100+ downloads from escorts"

### No Carryover Analysis
❌ **Bad**: "Just add carryover to the new sprint"
✅ **Good**: "Analyze why 98h carried over, address root causes"

### Skipping Risk Assessment
❌ **Bad**: "We'll handle issues as they come"
✅ **Good**: "Identified 3 high risks with specific mitigation plans"

## Metrics to Track

### Sprint Health Indicators
- **Capacity Utilization**: Aim for 70-80%
- **Buffer Consumption**: Track weekly
- **Dependency Delays**: Count and impact
- **Scope Changes**: Number and hours
- **Velocity Trend**: 3-sprint rolling average

### Success Metrics
- **Sprint Goal Achievement**: Binary (Yes/No)
- **Completion Rate**: >80% is healthy
- **Carryover Rate**: <20% is healthy
- **Team Satisfaction**: Sprint confidence vote
- **Stakeholder Satisfaction**: Goal delivery

## Example Output for Next Sprint

```markdown
# Sprint Plan: S2 E2/6 Spring
**Duration**: April 8-19, 2026 (10 working days)
**Goal**: Launch Messenger App and achieve initial escort adoption

## Capacity
- **Raw**: 4 devs × 10 days × 6h = 240h
- **Adjusted**: 240h × 0.55 = 132h
- **Carryover**: 98h (must address)
- **New Work Capacity**: 34h only

## Approach
Given 98h carryover and only 34h for new work:
1. **Prioritize carryover completion** (especially messenger app)
2. **Defer non-critical items** to next sprint
3. **Daily standup focus** on blockers
4. **Mid-sprint review** if carryover not reducing

## Selected Backlog
### Must Complete (Sprint Goal)
- KM-12134: Submit App to Stores (20h remaining)
- KM-12139: Launch Content Package (15h)

### Carryover - High Priority
- KM-11875: AI Assistant Staging Tests (25h) [Blocked until Day 3]
- KM-12001: Contact Management UI (18h)
- KM-11999: Permission System (20h)

### If Capacity Allows
- Bug fixes from support (10h buffer)
- Code review backlog (10h)

## Risks
1. **98h carryover won't complete**: Daily tracking, escalate Day 3
2. **App store rejection**: Legal pre-review, have web backup
3. **AI Squad delays**: Backup work identified, daily sync

## Success Criteria
- [ ] App submitted to both stores
- [ ] Launch content ready
- [ ] Carryover reduced to <20h
- [ ] No critical bugs in production
```

Remember: A realistic plan that completes is better than an ambitious plan that fails. Your credibility depends on delivering what you commit to.
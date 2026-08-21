---
name: jtbd-capture
description: Use when anyone at the company needs to document their jobs-to-be-done for the Q3 automation KR — triggers on "jtbd", "/jtbd-capture", "capture my jobs to be done", "document my JTBD", "list my jobs to automate". Mines the user's own Claude setup (CLAUDE.md, memory, recent files, connected tools) to draft their recurring tasks AND the meetings they prepare for, interviews to fill gaps, grades each job by honest automation level (not "a skill exists"), reusability, and priority, then proposes an agent-manager orchestration setup that actually runs the work. Role-agnostic — devs, designers, community managers, supporters, scrum masters, PMs, anyone. Outputs one local markdown file.
---

# JTBD Capture

Document your jobs-to-be-done in the format the Q3 automation goal needs: concrete recurring tasks at **automation altitude**, the **meetings** that anchor your week, each graded by **how autonomously it actually runs** (not whether a skill exists), and a proposed **agent-manager setup** that runs the work for you.

This is not classic customer JTBD. It is a **task inventory you can build automations against next sprint, plus the orchestration plan to actually automate them.**

## Trigger
"jtbd", "/jtbd-capture", "capture my jobs to be done", "document my JTBD", "list my jobs to automate"

## The KR this serves
> KR 3.2 — Each squad member documents their jobs-to-be-done list in Sprint 1; ≥80% of their **automatable** jobs automated by end Q3.

Four rules from this KR shape everything below:
1. **The denominator is automatable jobs, not all jobs.** Some work genuinely can't be automated (the meetings themselves, relationship and judgment work). Measuring against *all* jobs would force people to fake-automate the un-automatable or miss the KR unfairly. So every job is first classified automatable vs. not (Step 4a); the 80% is measured over the automatable set only.
2. **Build altitude, not job altitude.** "Manage stakeholder comms" is useless to automate against. "Draft the weekly Growth Circle update from Jira + Amplitude" is buildable. Push every job down until it has named inputs, outputs, and a repeatable trigger.
3. **A skill is not automation.** A skill you trigger by hand and then fix is still manual labor. It only counts as *automated* when it runs on its own (scheduled/event-triggered) or is run for you by an agent-manager, with output good enough to use without a heavy rewrite. This is the most common way people overstate their automation. Be strict (Step 4).
4. **The L2 reusability bar.** An automated task only counts toward the 80% if **another teammate can run it without help from the author.** Required field, not an afterthought.

---

## User Config File

Location: `~/.claude/skills/jtbd-capture/user-config.json`

```json
{ "full_name": "", "role": "", "squad": "" }
```

Read at the start of every run. Only ask for empty fields. Write back immediately. Never ask again once set.

---

## Step 0 — Load or Collect Config

Read `user-config.json`. For each empty field, ask: full name; role (e.g. "Backend Developer", "Community Manager", "Designer", "Supporter", "Scrum Master"); squad/team. Write completed config back.

---

## Step 1 — Mine Context (no questions yet)

Silently gather evidence of what this person does. Do NOT ask them to list jobs first — drafting from evidence is what makes this usable by non-PMs. Pull from:

- **Their `CLAUDE.md`** (project + user) — role, responsibilities, recurring duties, ceremonies, terminology
- **Their `memory/`** — ongoing work, projects, named workflows
- **Recent files** (last ~2–3 weeks) — what they've been producing
- **Connected MCP tools** — which integrations are authenticated (Jira, Gmail, Slack, Drive, Confluence, Amplitude, Figma, calendar). A connected tool is strong evidence of work in that system.
- **Calendar / meeting notes** — recurring ceremonies and 1:1s they attend (these become the Meetings list in Step 3b)
- **Existing skills/workflows** they've built — jobs they've already partly tooled

Draft a **first-pass list of 5–12 recurring jobs** plus a **first-pass meeting list**. One concrete line each, with a confidence note where you're guessing. If almost no context exists (fresh setup), skip silently to a short interview in Step 2.

---

## Step 2 — Confirm & Correct the Draft

Show the inferred job list and meeting list:

> "Based on your setup, here's what I think your recurring jobs and meetings are. Tell me what's wrong, missing, or at the wrong level of detail."

Ask them to:
- **Remove** anything not really theirs or not recurring
- **Add** jobs you couldn't see — offline work, judgment calls, things no tool touches
- **Flag duplicates** — if several people do *identical* work, capture it once as a **job-family** and note who shares it (the KR allows per-job-family documentation)
- **Confirm the meetings** they run or must contribute to (Step 3b)

Settle the lists before going deeper. One-time projects don't belong here — only recurring or repeating work.

---

## Step 3 — Interview Each Job to Build Altitude

Go through jobs **one at a time**. Fill only what mining couldn't. Use past-behavior questions, not speculation:

- "Walk me through the **last time** you did this. First step, then what?" → **steps**
- "What kicks it off, how often?" → **trigger & frequency**
- "Roughly how long does one run take?" → **time per run**
- "What do you need in front of you to start, what exists when done?" → **inputs → outputs**
- "Which tools/systems do you touch?" → **systems/data**
- "Which parts are mechanical, which need your judgment?" → **judgment line**

**Altitude guardrail — enforce actively.** If a job can't be described as a concrete repeatable procedure with named inputs and outputs, it's too high. Decompose it.

| Too high ❌ | Build altitude ✅ |
|---|---|
| "Manage the community" | "Triage new forum reports each morning and route rule-breaks to the mod queue" |
| "Handle support" | "Answer payout-status tickets by looking up the transaction in [system] and replying from a template" |
| "Do design work" | "Export approved Figma frames to spec-ready assets and drop them in the dev handoff folder" |
| "Run the sprint" | "Compile the sprint report from Jira board state every other Thursday" |

---

## Step 3b — Capture Meetings (don't skip — they anchor the automation)

Meetings you run or must contribute to are real jobs, even though the meeting itself can't be automated. Capturing them matters because **their prep and follow-up are automatable** and become the calendar triggers for the agent-manager (Step 6). For each recurring or ad-hoc meeting:

- **Your role:** run / contribute / informed
- **Cadence:** regular (which day) or ad hoc (triggered by what)
- **Prep needed** (automatable — links to a prep job/skill)
- **Follow-up needed** (automatable — notes → action items → tickets)

The meeting itself = **keep-human**. The prep and follow-up are jobs in their own right. Never let someone omit meetings just because the meeting can't be automated — they are where most of the prep/follow-up automation earns its value.

---

## Step 4 — Grade Each Job (be honest about automation)

### 4a — Is it automatable? (the denominator gate — do this first)
Classify each job before anything else:
- **Automatable** — an agent could do it end-to-end, or do the heavy lifting with a human reviewing/deciding. Goes in the KR denominator.
- **Not automatable (keep-human)** — the meeting itself, relationship/trust work, physical presence, the irreducible judgment call. Documented, but **excluded from the denominator** so the 80% stays honest.

Be careful: most "not automatable" jobs actually contain an automatable *part* (a meeting's prep and follow-up; an evaluation's fact-gathering). Split those — the keep-human core stays out of the denominator, the automatable part goes in. Only classify a job fully keep-human when no meaningful part can be offloaded.

The remaining sub-grades (4b–4d) apply to **automatable** jobs only.

### 4b — Automation level (autonomy axis)
A skill you trigger by hand and fix every time is **not automated**. Grade strictly:

| Level | What it means | Counts toward KR? |
|---|---|---|
| **Manual** | Done by hand, no tooling | No |
| **Assisted** | A skill/prompt helps, but you trigger it and correct its output each time | **No — still manual labor** |
| **Scheduled** | Runs on a time/event trigger with the right context, no manual kickoff; you just review | Yes (if it clears 4b + 4c) |
| **Orchestrated** | An agent-manager fires it at the right moment, chains it with related jobs, surfaces only what needs you | Yes |

Most existing skills sit at **Assisted**. The Q3 work is moving them to **Scheduled/Orchestrated** — that is what "automated" means here. Record current level and target level.

### 4c — Output quality (1–10)
How usable is the output *without* manual fixing? 10 = use as-is; 5 = heavy rewrite every time. A Scheduled job whose output you always rewrite is not really automated. Low scores feed the downstream skill-improvement loop (see Notes) — they don't block capture.

### 4d — Reusability (the L2 bar)
Can a teammate run it without the author present? `Reusable` / `Needs generalizing` / `Personal`. Only **Scheduled/Orchestrated + Reusable + quality ≥ ~7** genuinely counts toward the 80%. Flag this per job.

### 4e — Plus
Proposed shape (skill / agent / scheduled workflow / script), time saved/sprint (frequency × time-per-run), automation complexity (Low/Med/High: more systems, fuzzier judgment, unreachable tools, open-ended output all push it up).

**Note on the denominator:** classifying a job keep-human (4a) shrinks the denominator, so don't over-use it — but classifying genuinely un-automatable work as "automatable" sets you up to miss the KR. Both errors hurt. Be honest in both directions.

---

## Step 5 — Prioritize (effort vs. impact)

Place every automatable job in a quadrant from **time saved** (impact) vs. **complexity** (effort):

| | **Low complexity** | **High complexity** |
|---|---|---|
| **High time saved** | 🟢 **Quick Win** — automate first | 🟡 **Big Bet** — plan & chunk |
| **Low time saved** | 🔵 **Easy Filler** — batch when convenient | ⚪ **Skip** — keep human |

Then emit a **ranked automation backlog**. Note that an `Assisted` job moving to `Scheduled` is often a *cheaper* win than a net-new automation — flag those, they're usually the fastest path to the KR. List Skip/keep-human separately so they're visibly *decided*.

---

## Step 6 — Propose the Agent-Manager Setup

Running skills by hand is why coverage looks high but automation is low. Propose a per-person **orchestration plan** that converts Assisted → Scheduled/Orchestrated: a manager agent that, based on the day and the calendar, fires the right jobs, chains them, and surfaces only what needs the person.

Produce a table:

| Job | Trigger | Cadence | Output destination | Your touch-point |
|---|---|---|---|---|
| Standup prep | time | daily 08:30 | morning digest | review 2 min |
| Meeting prep | calendar (meeting tomorrow) | event | digest, evening before | review |
| Experiment brief | event (hit significance) | event | "needs decision" queue | decide |
| Sprint package | sprint end | per sprint | draft for review | review/send |

Cover:
- **Daily loop** — what fires every day unasked, and how output reaches them (one morning digest; a "needs your decision" queue).
- **Calendar/event triggers** — meeting tomorrow → prep fires the evening before; experiment significant → brief; sprint end → package.
- **Chains** — jobs that run in sequence (standup → pulse → digest).
- **Stays manual** — the meetings themselves and the judgment calls.
- **Build path** — scheduled cloud agents / cron routines for time triggers, hooks for event triggers, workflows for chains. Recommend starting with the daily loop, then calendar triggers.

---

## Step 7 — Write the File

Write to the current working directory as `jtbd-[firstname]-[YYYY-MM-DD].md` (tell the user where, and that they can move it). Structure:

```markdown
# Jobs-to-be-Done — [Full Name]
Role: [role] · Squad: [squad] · Captured: [YYYY-MM-DD]

## Automation Backlog (ranked)
1. 🟢 [job] — [current level → target level], [time saved/sprint], [complexity], [reusability]
...
### Decided not to automate
- ⚪ / 🧠 keep-human: [job] — [why]

## Agent-Manager Setup (proposed)
[the trigger table from Step 6 + daily loop + what stays manual]

## Meetings (keep-human; prep/follow-up automatable)
| Meeting | Role | Cadence | Prep job | Follow-up job |

## Jobs (detail)
### [Job name]
- Steps / Trigger & frequency / Time per run / Inputs → outputs / Systems / Judgment line
- Automation level: [current] → [target]   |   Output quality: [n/10]
- Reusability (L2): ... · Complexity: ... · Time saved: ... · Verdict: ... · Priority: 🟢/🟡/🔵/⚪

## JTBD Summary — [Full Name], [Squad]
Total jobs documented: N   (Automatable: A · Keep-human: K)   [A is the KR denominator]
Truly automated today (Scheduled/Orchestrated + Reusable + quality ≥7): X (X/A%)
Tooling coverage but still Assisted (NOT automated): Y
Target by end Q3: Z of A automatable jobs (Z/A% — aim ≥80%)
Top-3 ROI moves: [...]
Est. time saved if backlog shipped: [X h/sprint]
```

The `## JTBD Summary` block is fixed-format on purpose — it lets squads aggregate to track the KR. Don't rename its fields. The KR percentage is **X/A** (automated over *automatable*), never X/N. It separates **truly automated** from **tooling coverage** — that distinction is the whole point.

---

## Step 8 — Confirm

```
JTBD captured → ./jtbd-[firstname]-[YYYY-MM-DD].md

[N] jobs + [M] meetings documented
Truly automated today: [X] ([X/N]%) — tooling coverage but still manual-trigger: [Y]
Top move: [the agent-manager daily loop / the top Quick Win]

Next: stand up the agent-manager daily loop, then grade + improve the weakest skill outputs.
```

Offer to scope the agent-manager daily loop, or the top Quick Win.

---

## Notes

- `user-config.json` stays local — never committed.
- **The headline metric is "% of automatable jobs at Scheduled/Orchestrated, Reusable, quality ≥7" — not "% with a skill."** Manual-trigger skills are tooling coverage, not automation. Say so plainly in the output; it's the most common overstatement.
- Role-agnostic: never assume the user is a PM. Adapt examples (dev → CI/test/PR; designer → asset/handoff/spec; supporter → ticket triage; community manager → moderation/comms; scrum master → ceremony prep/reporting).
- Be honest about Keep-human. The KR is ≥80% of documented *automatable* tasks, not 80% of all human activity.
- **Downstream, separate step (don't do it here):** after capture, grade each skill's output 1–10 and improve the low scorers. That is its own loop — see `06-skills/skills/focused-skill-improvements.md` and `skills-improvement-and-adoption-plan.md`. Capture identifies *what* to automate and *how autonomously*; the improvement loop raises output quality. Keep them separate so neither bloats.
- v1 writes a local file only. A later version can push the summary to a shared Confluence/Jira rollup (see km-workflow-push) once the format is proven across roles.

# Attention Triage — spec (morning loop, next stage)

The intake half of the loop. The current loop senses your *state* (board, sprint, calendar) and drafts *your jobs*. This senses your *flow* — the notification firehose — and ranks it by how much it matters to your OKRs, so you spend attention on the few things that need your judgment and nothing important slips.

Pilot on Tomek first, then generalize: this is also the single most-requested missing signal from the squad (Maria's "who is waiting on my reply," Daniel Blam's "Confluence mentions," Chris's "items where I'm not tagged").

---

## The one hard rule: comprehension first

This must never become click-ok-ok-ok. The point is not to clear the inbox faster; it is to **understand the WHAT, WHY and HOW of your world before you act on any of it**, and stay aware of the situation. Every mechanism below serves that rule. If a feature would trade understanding for speed, it doesn't ship.

Concretely, that means:

- **Every item carries WHAT / WHY / HOW** (defined below). No item is ever presented as just an action button.
- **Nothing is actioned without its WHY and source visible.** You cannot acknowledge, reply, or close from a bare list — the reasoning and a link to the real ticket/page are always in front of you first.
- **Nothing is ever silently dropped or silently handled.** "Noise" and "Handled/FYI" are fully listed and expandable, not hidden. The filter is transparent, not a black box.
- **The digest opens with a situation synthesis** (3-5 lines: what's moving in your world today and why) so you build the picture *before* going item by item.

---

## Your actual workflow (what this fits into)

You do **not** review tasks, mentions, or notifications inside Jira or Confluence. You process everything through the **email notifications** those platforms send: open the email, click the link, read the ticket/page, then react or acknowledge. You got your inbox from ~500 to ~30 by hand this week; the goal is to keep it there without the manual wade, and to give you back mindspace for planning and ideation.

So the triage reads **your email inbox** as the primary source, resolves each Jira/Confluence notification to the **real underlying ticket or page** (via the Atlassian MCP, so it reasons over the actual content, not just the email snippet), and hands you back one structured digest. You still click through to read the few things that need you — but only those, and you arrive already knowing why they matter.

---

## Sources

1. **Email inbox** (primary) — Jira notification emails, Confluence notification emails, and direct emails. Provider: **Microsoft 365 / Outlook** (`email_provider: microsoft365`), the account on `tomek@ideawisegroup.com`, read via the Microsoft 365 MCP.
2. **Atlassian MCP** (enrichment) — for each Jira/Confluence notification, pull the real issue/page: status, who changed what, the actual comment or mention, links to your OKRs/epics. This is what lets the WHY be real rather than guessed from a subject line.
3. **Your OKR source** (the ranker's yardstick) — your current Q3 KRs, machine-readable, via the `okr-tracker` skill / your OKR file. Your lane (acquisition, retention, fluency) is what "important" is scored against. Most inboxes can't be OKR-ranked; yours can, and that's the whole leverage.

If a source is unreachable, the digest says so and degrades — it never fabricates a priority or a summary.

---

## The scoring model (why an item lands where it lands)

Each item gets a priority from a small, inspectable set of signals — no opaque score:

- **OKR link** — does it touch one of your KRs, and which? (highest weight)
- **Someone is waiting on you** — a direct mention, an assigned action, a reply-needed. (high)
- **Time pressure** — a deadline, a decision window, an experiment past its read date.
- **Your ownership** — your ticket / your page / your commitment vs FYI-only / cc.
- **Reversibility** — a decision that's hard to undo ranks above a routine ack.

The item's WHY always names the signals that put it where it is (e.g. "waiting on your reply + touches KR2.1 payer retention"). No item is ranked by a number you can't unpack.

---

## The four buckets — each with WHAT / WHY / HOW

Ordered by attention required. Every item in every bucket carries all three fields.

**1. 🟢 Handled / FYI** — read-only awareness, no action needed.
- WHAT: what happened. WHY: why it's informational (no ask, no OKR decision, or already resolved). HOW: what was concluded and why nothing is required of you.
- These are summarized so you stay aware without clicking. Nothing is *done* on your behalf here — "handled" means "understood and triaged as no-action," and it's fully listed so you can disagree.

**2. ✍️ Draft ready** — routine responses pre-written for your approval.
- WHAT: what's being asked. WHY: why this response, traced to the ticket/page context and which OKR/person it serves. HOW: the actual draft reply/ack + the reasoning it's based on + a link to the source.
- Approving is informed: you see what it would say and why *before* you say send. Sending is gated per item (see safety).

**3. 📖 Read this yourself** — needs your judgment, no one else's.
- WHAT: what it is. WHY: why it needs *you* specifically (irreversible call, strategic, ambiguous ownership, high OKR stakes). HOW: what exactly to decide, and the deep link to read it in full.
- This is the short list you actually click through to. It's meant to be small.

**4. 🔇 Noise** — batched, safe to skip, never hidden.
- WHAT: grouped (e.g. "7 automated status-change notifications"). WHY: why safe to batch (no ask, no OKR link). HOW: expand to see every item; pull anything out and that correction teaches the ranker.
- Shown as a count you can always open. Never auto-archived, never invisible.

---

## The digest format

```
ATTENTION DIGEST — {date}

── State of your world ──   (read this first)
{3-5 lines: what's moving today and why. e.g. "Reactivation experiment KM-13774
hit its read window and needs a ship/kill call. Two people are waiting on your
reply (Arame on the paywall spec, Christoph on the JTBD rollup). Everything else
is routine status movement." }

📖 Read this yourself ({k})   ← your real list, arrive already knowing why
  1. {WHAT} · WHY: {signals + OKR link} · HOW: decide {x} → {deep link}

✍️ Draft ready ({n})   ← review the WHY, then approve to send (gated, one at a time)
  1. {WHAT} · WHY: {why this reply} · HOW: preview "{draft}" — based on {source} → {link}   [show full / approve & send / edit / skip]

🟢 Handled / FYI ({m})   ← awareness, no action
  - {WHAT} · WHY informational · HOW: {conclusion}

🔇 Noise ({p})   ← batched, expand anytime
  - {grouped count} — [expand]

── Calibration ──
Anything mis-bucketed? Tell me and it re-ranks (and remembers).
```

---

## Comprehension guarantees (the anti-"ok-ok-ok" mechanisms)

1. **Situation synthesis at the top** — you understand the day before touching any item.
2. **WHY + source mandatory before any action** — no acknowledging or sending from a bare button.
3. **Draft preview before send** — you always see the words and their basis first.
4. **Full transparency of Handled + Noise** — the filter never hides; you can audit what it decided not to surface.
5. **Calibration loop** — correcting a mis-bucket re-ranks and is remembered, so it tunes to *your* judgment, not a generic importance heuristic.
6. **Triage log** — a running record of what was bucketed where and why, so situational awareness persists across days and there's an honest audit trail (same spirit as the run-log).

---

## Safety / gating

Same contract as the rest of the loop, no loosening:

- Reading email + Jira + Confluence is `unattended_allowed` (read-only).
- **Sending a reply, posting a comment, acknowledging in-app, archiving — all `never_auto`**, gated per item with a fresh yes, even after you've reviewed the digest.
- Nothing in "Handled" or "Noise" is actioned; those buckets are classification only.

---

## Test it on yourself (the pilot)

1. **Week 1 — classify only.** No drafts, no sends. Each morning the digest just buckets your inbox with WHAT/WHY/HOW. You spot-check its bucketing against what you'd have done by hand. Goal: measure precision (how often "read yourself" and "noise" are right) *before* trusting it to draft anything.
2. **Correct as you go.** Every mis-bucket you fix trains the ranker and sharpens the OKR yardstick.
3. **Week 2 — turn on Draft ready**, still gated per item. Now measure how many drafts you approve without a rewrite (the same ready-without-edit signal the loop already tracks).
4. **Only then** consider letting it run as part of the scheduled pre-run (delivered to email per `RUN-AND-NOTIFY.md`), so the digest is waiting when you open your inbox.
5. If it ever starts feeling like autopilot, that's a bug against the one hard rule — stop and fix the comprehension, don't push through.

---

## Config block (new `/morning` job)

```yaml
# add to routing:
  - id: attention_triage
    signal: daily
    job: "Triage email/Jira/Confluence notifications, ranked by OKR relevance"
    skill: attention-triage        # new skill to build
    bucket: draft                  # produces a digest; replies are gated per item
    external_action: none          # replies/acks are never_auto, confirmed individually

attention_triage:
  email_provider: microsoft365     # Outlook on tomek@ideawisegroup.com, via the Microsoft 365 MCP
  enrich_via_atlassian: true       # resolve each notification to the real ticket/page
  okr_source: "01-sprint-operations/current/okrs-q3-2026.md"   # the ranker's yardstick
  mode: classify_only              # classify_only (pilot) | with_drafts (week 2+)
  buckets: [read_yourself, draft_ready, handled_fyi, noise]
  show_all_buckets: true           # Handled + Noise always listed/expandable, never hidden
  triage_log: "05-automation/agent-manager/triage-log.md"
```

---

## Settled inputs
- **Email:** Microsoft 365 / Outlook (`tomek@ideawisegroup.com`), read via the Microsoft 365 MCP.
- **OKR yardstick:** `01-sprint-operations/current/okrs-q3-2026.md` (Q3, machine-readable, with per-KR match hooks).

## Still open
- **Delivery (post-pilot only):** once past classify-only, deliver the digest to your Outlook inbox (fits your workflow) or keep it as a `/morning` section you open in Claude Code? Not needed to start the pilot.

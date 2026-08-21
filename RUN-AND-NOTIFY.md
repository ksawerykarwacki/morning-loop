# Morning Loop — Run, Deliver, Notify (the unattended standard)

How the loop runs on its own and lands in front of you, so you never have to remember to trigger it. This is the standard we're building from Chris's proven cloud routine and Maria's silent-failure lesson.

## The problem this fixes

Every adopter is stuck at "Assisted" for the same structural reason, not motivation:

- The local scheduler (launchd / Task Scheduler) only fires when the laptop is on and VPN is up. Maria lost two mornings to exactly this.
- Failures are silent. The cloud half of a two-stage routine can succeed while the real end deliverable never lands, and a naive "did something run?" check reports healthy.
- Nothing pulls you back to the output. If you forget to run `/morning`, the sensing never happens.

The fix is a four-part contract every adopter configures the same way: **RUN → DELIVER → NOTIFY → HEALTH.**

---

## The contract

### 1. RUN (unattended, read-only)
The scheduled job runs `/morning --prep` only: Phase 1 SENSE + Phase 2 PLAN. This is read-only by design (query + write local/durable files), so it is safe to run with no human present. **Dispatch and anything leaving the workspace stay interactive at the morning gate** — the schedule never ships, never posts, never creates a ticket. That safety contract does not change just because the run is now unattended.

### 2. DELIVER (to somewhere durable you actually open)
The pre-run writes its plan/digest to a **durable channel that survives your laptop being off** and that you already look at. This is the piece that was missing: a plan file on a powered-off laptop helps no one.

Configurable per person:

| `delivery.channel` | Good for | Notes |
|---|---|---|
| `email` | anyone who lives in their inbox (Tomek) | Delivered where you already triage. Pairs directly with attention-triage (see `ATTENTION-TRIAGE.md`). |
| `confluence_page` | anyone; team-visible | One rolling "My Morning Brief" page, updated in place each run. |
| `mattermost_dm` | quick skim | One DM to yourself; keep it to the summary + a link. |
| `local_file` | machine-bound setups only | The v1 default; only works if you're at that machine. |

Delivery is a *write of already-sensed, read-only output* — it is not a `never_auto` external action (nothing is being decided or sent on your behalf). Posting a draft, creating a ticket, replying to anyone still happens only at the interactive gate.

### 3. NOTIFY (one line, so you don't have to remember)
After delivery, send a single notification so the loop pulls you to it instead of the other way round:

```
☀️ Morning brief ready — {n} drafts to review, {m} decisions, {k} meetings.
Top of your list: {the single most important item}.
Open: {link to the delivered brief}
```

Channel is `notify.channel` (push / email / Mattermost). Keep it to one line plus the top item — the notification's job is to get you to open the brief, not to be the brief.

### 4. HEALTH (verify the END deliverable, not that a job ran)
A daily self-check (Maria's `routine_health`) confirms the **end artifact exists** — the brief was delivered AND the notification was sent — not merely that the script exited 0. On a miss (task never registered, disabled, failed, VPN down, or the deliverable is absent), it fires a diagnosis so a silent failure becomes a visible one. Check both halves of a two-stage routine independently.

---

## Where it runs: two substrates

### A. Cloud routine (recommended — this is the honest end state)
A Claude Code cloud routine on a weekday cron (read-only, KM-scoped MCPs). Survives the laptop being off, which is the whole point. Chris proved this works.

**The one structural blocker, named honestly:** a cloud routine cannot read the package files while they live on Lab-GitLab (local/VPN only). So today the cloud path means reimplementing the loop's instructions inside the routine, which diverges from the shared package. **The real unblock is giving the package a cloud-reachable home** (a mirror the cloud routine can pull). That single change lets cloud routines run the *same* files everyone edits, and it is the prerequisite for the whole squad clearing the automation KR. Until then, treat the cloud routine as running a pinned copy of the loop, and keep it in sync by hand.

### B. Local scheduler (fallback — honest about its ceiling)
launchd (macOS, `scripts/run-prep.template.sh`) or Task Scheduler (Windows, Maria's `run-prep.ps1`, menu #6). Fine for getting started, but it is Assisted infrastructure, not true unattended automation: it only fires when your machine is on. If you use it, `routine_health` is mandatory, because this substrate is exactly the one that fails silently.

---

## The config block adopters add

```yaml
schedule:
  enabled: true
  substrate: cloud_routine        # cloud_routine (recommended) | local_launchd | local_task_scheduler
  time: "07:50"
  timezone: "Europe/Warsaw"       # your morning, not CET by default (see menu #13)
  weekdays: [mon, tue, wed, thu, fri]

delivery:
  channel: email                  # email | confluence_page | mattermost_dm | local_file
  target: "<your email / page id / dm target>"

notify:
  channel: push                   # push | email | mattermost
  include_top_item: true          # one line + the single most important item

health:
  enabled: true                   # routine_health — verify the END deliverable, not just exit 0
  check_deliverable: true         # confirm the brief landed AND the notification sent
  alert_on_miss: mattermost_dm
```

The permission contract is unchanged: `unattended_allowed` still covers only read + local/durable writes; dispatch stays `gated_at_morning_approval`; sending/posting/creating stays `never_auto`.

---

## Adoption order (do this, in this order)

1. **Get it running unattended somewhere** — cloud routine if you can, local scheduler if not. Read-only `--prep`.
2. **Point delivery at a channel you actually open.** For most people that is not a local file.
3. **Turn on notify** so you stop remembering to run it.
4. **Turn on health** the same day — especially on a local scheduler. A silent failure you don't catch is worse than no automation, because you think you're covered.
5. Log honestly in the run-log which runs were truly unattended vs hand-triggered. That is still the KR evidence.

## Open decision for the squad (Tomek)

The cloud-reachable home for the package is the fork in the road. Options: mirror `morning-loop-share` to a cloud-reachable git; or keep Lab-GitLab as source of truth and publish a read-only cloud mirror the routines pull. Either way, until this is decided, "unattended" means "a hand-synced copy runs in the cloud," and that is worth stating plainly rather than implying full automation.

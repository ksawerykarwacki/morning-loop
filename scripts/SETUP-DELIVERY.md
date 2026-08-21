# Getting the brief in front of you

Pick one. The first two cost no account, no password, and no 2FA.

| | setup | where it lands | good for |
|---|---|---|---|
| **macOS notification** (default) | **nothing** | notification + a local web page | just yourself, start here |
| **Mattermost** | paste one URL | a channel or a DM to yourself | team-visible, any OS, your phone |

Neither needs an account, a password, or 2FA. That is deliberate: a delivery step that requires signing up for something is a step most people never finish, and a brief nobody configured delivery for is worth exactly as much as no loop at all.

---

## Option 1: macOS notification (zero setup)

Already on if `delivery.channel: macos`. Nothing to configure.

At 07:52 you get a native notification with the counts and your single most important item, and the brief opens as a local page in your browser using `open -g`, so it waits in a tab without stealing focus from whatever you are doing.

Test it right now:

```sh
cd ~/Projects/po-workspace
python3 05-automation/agent-manager/scripts/notify.py \
  --brief 01-sprint-operations/current/morning-plan-$(date +%F).md
```

Add `--dry-run` to see what it would do, `--no-open` to skip the browser tab.

**Windows / Linux:** `notify.py`'s `macos` channel uses `osascript`, which is Mac-only. Use `mattermost` instead. It works everywhere and is the better option anyway if you want the brief on your phone.

## Option 2: Mattermost (one URL, ~2 minutes)

This is the one to use if you want it on your phone, or you are not on a Mac, or you want the brief somewhere you already look all day.

**Get a webhook URL:**

1. In Mattermost: **Main menu → Integrations → Incoming Webhooks → Add**.
2. Pick the channel it should post to. For a private brief, create a channel only you are in, or use your own DM channel.
3. Title it "morning loop", save, and copy the URL. It looks like `https://mattermost.example.com/hooks/xxxxxxxxxxxxx`.

If Integrations is missing from the menu, incoming webhooks are disabled server-side and an admin has to enable them. That is the only thing here that can block you.

**Point the loop at it.** The webhook is a credential, so it goes in an untracked file rather than the committed config:

```sh
mkdir -p ~/.config/morning-loop
cat > ~/.config/morning-loop/notify.env <<'EOF'
export MORNING_NOTIFY_CHANNEL=mattermost
export MORNING_MATTERMOST_WEBHOOK=https://mattermost.example.com/hooks/PASTE_YOURS
EOF
chmod 600 ~/.config/morning-loop/notify.env
```

`run-prep.sh` sources that file automatically. Test:

```sh
. ~/.config/morning-loop/notify.env
python3 05-automation/agent-manager/scripts/notify.py \
  --brief 01-sprint-operations/current/morning-plan-$(date +%F).md
```

You get a post headed with the counts and your top item, then the full brief. Anything over ~14k characters is clipped with a pointer to the repo, because Mattermost rejects very long posts.

Turn on mobile notifications for that channel and the brief reaches your phone with no app, no account, and no email.

---

## Verifying it keeps working

Every delivery writes `05-automation/agent-manager/delivery-receipts/{date}.json`, on success **and** on failure:

```sh
cat 05-automation/agent-manager/delivery-receipts/$(date +%F).json
```

- `"status": "sent"` with a timestamp means it landed.
- `"status": "failed"` carries the verbatim error.
- **No receipt at all on a working day means the run never got that far.** That is the case the HEALTH phase reports rather than shrugging at, and it is the exact failure that let a routine here run for nine weekdays while delivering nothing.

`run-prep.sh` also carries a shell-level safety net: if there is no `sent` receipt by the end of the run, it delivers the brief itself. Delivery is the whole point of the loop, so it does not depend on the model remembering to call a script. It is idempotent, so a brief already delivered is never delivered twice.

## Referencing a brief later

Each brief gets a number, shown in the notification title and the page: `☀️ Morning Brief #21 · 2026-08-05`.

In your terminal, `/brief 21` (or just saying `morning loop #21`) reloads that brief's plan file, that day's agent drafts, its run-log entry and its delivery receipt, so you can pick up where the loop left off instead of re-deriving it. `/brief last 3` leads with what changed across them.

One rule is built into that command: a brief is a snapshot of a **past** morning, so anything time-sensitive gets re-verified against live Jira before it is treated as current.

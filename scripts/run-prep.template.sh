#!/bin/zsh
# Agent-manager unattended pre-run. Invoked by launchd on weekday mornings.
# Runs the read-only SENSE + PLAN half of /morning and writes today's plan file.
# Does NOT dispatch — that stays interactive (the morning gate).

# launchd gives a minimal environment; set PATH explicitly for claude + node + jq + python.
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

WORKDIR="<PATH TO YOUR REPO>"   # FILL
LOG="$WORKDIR/05-automation/agent-manager/launchd.log"
cd "$WORKDIR" || { echo "$(date) FAILED cd $WORKDIR" >> "$LOG"; exit 1; }

# Hold the machine awake for the whole run. A launchd DarkWake gives roughly 45
# seconds before macOS returns to sleep and kills everything: on 2026-08-20 the
# run fired at 08:01:04 and the machine slept at 08:01:49, producing nothing and
# reporting nothing until the lid opened. -w ties the assertion to this script's
# pid, so it retires on its own without needing cleanup on every exit path.
caffeinate -i -w $$ &

echo "===== $(date '+%Y-%m-%d %H:%M:%S') starting /morning --prep =====" >> "$LOG"

# --print: headless, single-shot. --permission-mode acceptEdits lets it write the
# plan file without a prompt. The --prep path is read-only beyond local file writes;
# it never performs a never_auto external action (those are interactive-only by design).
#
# Bounded with a watchdog rather than `timeout`, which macOS does not ship. An
# unbounded headless invocation once burned 43 minutes failing to authenticate
# before giving up, which is time the machine might not stay awake for.
claude --print "/morning --prep" \
  --permission-mode acceptEdits \
  >> "$LOG" 2>&1 &
CLAUDE_PID=$!
( sleep 1200; kill -0 "$CLAUDE_PID" 2>/dev/null && {
    echo "watchdog: prep exceeded 20 min, killing $CLAUDE_PID" >> "$LOG"
    kill -TERM "$CLAUDE_PID" 2>/dev/null
  } ) &
WATCHDOG_PID=$!
wait "$CLAUDE_PID"

STATUS=$?
kill "$WATCHDOG_PID" 2>/dev/null      # run finished in time; retire the watchdog
echo "===== $(date '+%Y-%m-%d %H:%M:%S') claude finished (exit $STATUS) =====" >> "$LOG"

# --------------------------------------------------------------------------
# DELIVERY SAFETY NET.
# Phase 2b is supposed to deliver the brief itself. This block does not trust
# that: if no "sent" receipt exists for today, it delivers here. Delivery is the
# whole point of the loop, so it must not depend on the model remembering to
# call a script. Idempotent - the notifier reuses today's brief id.
#
# Default channel is `macos`: a native notification plus the brief rendered as a
# local web page. Zero setup, nothing to sign up for. Set MORNING_NOTIFY_CHANNEL
# to `mattermost` (with MORNING_MATTERMOST_WEBHOOK) to post it instead.
# --------------------------------------------------------------------------
TODAY=$(date '+%Y-%m-%d')
PLAN="$WORKDIR/01-sprint-operations/current/morning-plan-$TODAY.md"
RECEIPT="$WORKDIR/05-automation/agent-manager/delivery-receipts/$TODAY.json"
NOTIFIER="$WORKDIR/05-automation/agent-manager/scripts/notify.py"

# Optional overrides (channel, webhook). Absent by default.
[ -f "$HOME/.config/morning-loop/notify.env" ] && . "$HOME/.config/morning-loop/notify.env"

# --------------------------------------------------------------------------
# alert_on_miss. A failure that only reaches a log file IS a silent failure:
# nobody reads a log they have no reason to open. So every failure path below
# notifies, using osascript directly rather than the notifier script, because
# the whole point is that it still works when the run itself is broken.
# Also writes a `failed` receipt, so tomorrow's HEALTH check can tell
# "failed for this reason" from "never attempted".
# --------------------------------------------------------------------------
alert_on_miss() {
  reason="$1"; detail="$2"
  echo "alert: $reason - $detail" >> "$LOG"
  /usr/bin/osascript -e "display notification \"$detail\" with title \"⚠️ Morning brief did NOT run\" subtitle \"$reason\" sound name \"Basso\"" >/dev/null 2>&1
  mkdir -p "$WORKDIR/05-automation/agent-manager/delivery-receipts"
  printf '{\n  "date": "%s",\n  "status": "failed",\n  "stage": "%s",\n  "error": "%s",\n  "checked_at": "%s"\n}\n' \
    "$TODAY" "$reason" "$detail" "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
    > "$WORKDIR/05-automation/agent-manager/delivery-receipts/$TODAY.json"
}

if grep -q '"status": "sent"' "$RECEIPT" 2>/dev/null; then
  echo "delivery: already delivered today, nothing to do" >> "$LOG"
elif [ ! -f "$PLAN" ]; then
  # The run never produced a brief. Diagnose WHY from what claude actually said,
  # because "it didn't run" is useless and "your login expired" is actionable.
  if grep -qi "Failed to authenticate\|OAuth session expired\|Invalid API key\|Please run.*login" "$LOG"; then
    alert_on_miss "Claude login expired" "Run: claude /login in the terminal, then /morning to get today's brief."
  elif [ $STATUS -ne 0 ]; then
    alert_on_miss "The prep run failed (exit $STATUS)" "No brief today. Check launchd.log, then run /morning manually."
  else
    alert_on_miss "No plan file was written" "The run finished but produced nothing. Check launchd.log."
  fi
  STATUS=1
else
  echo "delivery: no 'sent' receipt for $TODAY, delivering from the safety net" >> "$LOG"
  python3 "$NOTIFIER" --brief "$PLAN" --date "$TODAY" >> "$LOG" 2>&1
  SEND_STATUS=$?
  if [ $SEND_STATUS -ne 0 ]; then
    alert_on_miss "Brief written but delivery failed" "The plan exists but did not reach you. See $RECEIPT"
    STATUS=$SEND_STATUS
  fi
fi

echo "===== $(date '+%Y-%m-%d %H:%M:%S') finished (exit $STATUS) =====" >> "$LOG"
exit $STATUS

#!/bin/zsh
# Agent-manager unattended pre-run. Invoked by launchd on weekday mornings.
# Runs the read-only SENSE + PLAN half of /morning and writes today's plan file.
# Does NOT dispatch — that stays interactive (the morning gate).
#
# Plain POSIX sh throughout, so it behaves the same under zsh and macOS bash 3.2.

# launchd gives a minimal environment; set PATH explicitly for claude + node + jq + python.
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

WORKDIR="<PATH TO YOUR REPO>"   # FILL
LOG="$WORKDIR/05-automation/agent-manager/launchd.log"
cd "$WORKDIR" || { echo "$(date) FAILED cd $WORKDIR" >> "$LOG"; exit 1; }

# The day the run STARTED. Computed once, here, and never again: a run that
# froze on a Thursday and thawed on Friday night used to write its failed
# receipt to Friday and leave Thursday with no receipt at all.
TODAY=$(date '+%Y-%m-%d')
PLAN="$WORKDIR/01-sprint-operations/current/morning-plan-$TODAY.md"
RECEIPT="$WORKDIR/05-automation/agent-manager/delivery-receipts/$TODAY.json"
NOTIFIER="$WORKDIR/05-automation/agent-manager/scripts/notify.py"
ONTIME="$WORKDIR/05-automation/agent-manager/scripts/ontime.py"

# Hold the machine awake for the whole run. A launchd DarkWake gives roughly 45
# seconds before macOS returns to sleep and kills everything: on 2026-08-20 the
# run fired at 08:01:04 and the machine slept at 08:01:49, producing nothing and
# reporting nothing until the lid opened. -w ties the assertion to this script's
# pid, so it retires on its own without needing cleanup on every exit path.
caffeinate -i -w $$ &

# ---------------------------------------------------------------------------
# NETWORK GATE. Wait for the network before launching the run, bounded.
#
# 2026-09-28, on the PO loop: the 07:50 run and the 09:15 catch-up both died
# with "API Error: Can't reach the API server (ENOTFOUND)". The wake fired on
# time, but it was a DarkWake on battery, and a DarkWake on battery brings no
# Wi-Fi with it. The first run burned 37 minutes on DNS and then reported a
# generic "prep failed (exit 1)", which names no cause and suggests the wrong fix.
#
# So: poll until the API host resolves AND accepts a TCP connection on 443, every
# NET_STEP_SECS, for at most NET_WAIT_SECS of WALL CLOCK. nc does the real
# getaddrinfo + connect, the same path the API client takes; dscacheutil is asked
# afterwards only to NAME the cause. Both ship with macOS, nothing to install.
# If the network never comes up: one clear log line, a failed receipt whose stage
# is "no network at fire time", one notification per day for this cause, and exit
# 75 (EX_TEMPFAIL). Any retry agent you run (see RUN-AND-NOTIFY.md) takes the next
# slot. This runs BEFORE the "starting" line, so a gate miss never opens a run.
# ---------------------------------------------------------------------------
NET_HOST="${MORNING_NET_HOST:-api.anthropic.com}"
NET_WAIT_SECS="${MORNING_NET_WAIT_SECS:-300}"
NET_STEP_SECS="${MORNING_NET_STEP_SECS:-10}"

net_up() { /usr/bin/nc -z -G 4 -w 4 "$NET_HOST" 443 >/dev/null 2>&1; }
net_cause() {
  if /usr/bin/dscacheutil -q host -a name "$NET_HOST" 2>/dev/null | grep -q 'address:'; then
    echo "DNS resolves but port 443 is unreachable"
  else
    echo "DNS does not resolve $NET_HOST"
  fi
}

NET_T0=$(date +%s)
NET_DEADLINE=$((NET_T0 + NET_WAIT_SECS))
while ! net_up; do
  if [ "$(date +%s)" -ge "$NET_DEADLINE" ]; then
    net_up && break                      # one last try after a thaw past the deadline
    CAUSE=$(net_cause)
    WAITED=$(( $(date +%s) - NET_T0 ))
    echo "===== $(date '+%Y-%m-%d %H:%M:%S') no network at fire time: $CAUSE after waiting ${WAITED}s (limit ${NET_WAIT_SECS}s). Not starting the run. =====" >> "$LOG"
    mkdir -p "$(dirname "$RECEIPT")"
    if ! grep -qE '"status": "(sent|rendered_not_sent)"' "$RECEIPT" 2>/dev/null; then
      PRIOR_STAGE=$(grep -o '"stage": "[^"]*"' "$RECEIPT" 2>/dev/null)
      printf '{\n  "date": "%s",\n  "status": "failed",\n  "stage": "no network at fire time",\n  "error": "%s after waiting %ss. The machine was probably in a DarkWake on battery, which brings no Wi-Fi. Mains power overnight fixes it.",\n  "checked_at": "%s"\n}\n' \
        "$TODAY" "$CAUSE" "$WAITED" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$RECEIPT"
      if [ "$PRIOR_STAGE" != '"stage": "no network at fire time"' ]; then
        /usr/bin/osascript -e "display notification \"$CAUSE. Run /morning once you are online.\" with title \"⚠️ Morning brief waiting for network\" subtitle \"No network at fire time\" sound name \"Basso\"" >/dev/null 2>&1
      fi
    fi
    [ -f "$ONTIME" ] && python3 "$ONTIME" record --date "$TODAY" >> "$LOG" 2>&1
    exit 75
  fi
  sleep "$NET_STEP_SECS"
done
NET_WAITED=$(( $(date +%s) - NET_T0 ))
[ "$NET_WAITED" -gt 0 ] && echo "===== $(date '+%Y-%m-%d %H:%M:%S') network up after ${NET_WAITED}s =====" >> "$LOG"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') starting /morning --prep =====" >> "$LOG"

# Where THIS run's slice of the cumulative log starts. The failure classifier
# below reads only this slice: grepping the whole log meant that once "Please run
# /login" had appeared once, every later failure was reported as a login expiry.
LOG_START=$(wc -c < "$LOG" 2>/dev/null || echo 0)

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

# WALL-CLOCK-AWARE WATCHDOG (V3-TO-V4 row A4). The old `sleep 1200` suspended
# with the machine, so a run that froze in a DarkWake and thawed at lid-open froze
# and thawed together with its own watchdog: one adopter's run fired 08:01:23,
# thawed 12:11:03, 4h10m against a "30 minute" limit, and was then reported as a
# timeout. This one ticks every WD_TICK seconds and reads the clock. A tick that
# took far longer than WD_TICK means the machine slept: that is logged as
# `watchdog: machine slept for about N min` and NOT counted against the budget,
# and the classifier below reports the run as `slept`, never as a timeout.
#
# The budget is AWAKE time and the default went 20 -> 50 minutes, also row A4:
# 20 left one adopter 45 seconds of margin with pre-drafting OFF. Override with
# MORNING_WATCHDOG_SECS.
WD_BUDGET="${MORNING_WATCHDOG_SECS:-3000}"
WD_TICK=15
( awake=0; last=$(date +%s)
  while kill -0 "$CLAUDE_PID" 2>/dev/null; do
    sleep "$WD_TICK"
    now=$(date +%s); gap=$((now - last))
    if [ "$gap" -gt $((WD_TICK * 4 + 60)) ]; then
      echo "watchdog: machine slept for about $((gap / 60)) min (wall clock $(date -r "$last" '+%H:%M:%S') to $(date -r "$now" '+%H:%M:%S')), not counted against the budget"
    else
      awake=$((awake + gap))
    fi
    last=$now
    if [ "$awake" -ge "$WD_BUDGET" ] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
      echo "watchdog: prep exceeded $((WD_BUDGET / 60)) min awake, killing $CLAUDE_PID"
      kill -TERM "$CLAUDE_PID" 2>/dev/null
      break
    fi
  done ) >>"$LOG" 2>&1 &
WATCHDOG_PID=$!
wait "$CLAUDE_PID"

STATUS=$?
# Reap the sleep BEFORE its parent: killing the subshell alone orphans the sleep,
# which keeps an inherited stdout open and makes anything waiting on this script
# block until it ends. The explicit redirect above is the other half - without it
# the watchdog holds the caller's pipe.
pkill -P "$WATCHDOG_PID" 2>/dev/null
kill "$WATCHDOG_PID" 2>/dev/null      # run finished in time; retire the watchdog
echo "===== $(date '+%Y-%m-%d %H:%M:%S') claude finished (exit $STATUS) =====" >> "$LOG"

# This run's slice of the log, and how long the machine slept during it.
RUN_LOG=$(tail -c "+$((LOG_START + 1))" "$LOG" 2>/dev/null)
SLEPT_MIN=$(printf '%s' "$RUN_LOG" | sed -n 's/^watchdog: machine slept for about \([0-9]*\) min.*/\1/p' | awk '{s+=$1} END {print s+0}')

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
    > "$RECEIPT"
}

# `sent` covers macos and mattermost. `rendered_not_sent` is what `delivery.channel:
# file` records, because rendering the page delivers the brief without sending
# anything. Both mean today's brief already exists and must not be redone.
if grep -qE '"status": "(sent|rendered_not_sent)"' "$RECEIPT" 2>/dev/null; then
  echo "delivery: already delivered today, nothing to do" >> "$LOG"
elif [ ! -f "$PLAN" ]; then
  # The run never produced a brief. Diagnose WHY from what claude actually said
  # in THIS run, because "it didn't run" is useless and "your login expired" is
  # actionable. Most specific cause first.
  if [ "$SLEPT_MIN" -gt 0 ] || printf '%s' "$RUN_LOG" | grep -qi "went to sleep\|Connection closed mid-response"; then
    SLEPT_NOTE="It went to sleep during the run"
    [ "$SLEPT_MIN" -gt 0 ] && SLEPT_NOTE="It slept about ${SLEPT_MIN} min during the run"
    alert_on_miss "The Mac slept mid-run" "$SLEPT_NOTE, so this is not a timeout. Keep it on mains power overnight with a scheduled wake (RUN-AND-NOTIFY.md), then run /morning."
  elif printf '%s' "$RUN_LOG" | grep -qi "Failed to authenticate\|OAuth session expired\|Invalid API key\|Please run.*login"; then
    alert_on_miss "Claude login expired" "Run: claude /login in the terminal, then /morning to get today's brief."
  elif printf '%s' "$RUN_LOG" | grep -qi "ENOTFOUND\|EAI_AGAIN\|Can't reach the API server\|getaddrinfo\|Could not resolve host\|Network is unreachable"; then
    # The network gate above means the run started online, so it went away mid-run.
    alert_on_miss "Lost the network mid-run" "The run started with a network and then lost it, so the API became unreachable. Run /morning once you are online."
  elif printf '%s' "$RUN_LOG" | grep -qi "mcp.*timeout\|mcp.*timed out\|sse.*closed\|sse.*disconnected\|sse.*timeout\|event stream.*closed\|event stream.*ended\|econnreset\|connection reset by peer"; then
    alert_on_miss "An MCP server dropped mid-run (SSE/stream timeout)" "A tool server's stream died, so the run could not finish. Re-run /morning manually; if it recurs, reconnect that MCP server."
  elif printf '%s' "$RUN_LOG" | grep -q "watchdog: prep exceeded"; then
    alert_on_miss "Watchdog stopped the run (${WD_BUDGET}s awake)" "The run was awake the whole budget and did not finish. Check launchd.log, then run /morning manually."
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

# ON-TIME RECORD (V3-TO-V4 row D3). Lag between the scheduled fire and the first
# delivery, whether this unattended run delivered it or a person had to, and a
# class (unattended / late / missed) against health.on_time.grace_minutes.
# Written into today's receipt and as ONE run-log line per day, by the runner,
# because the model's own run-log line is exactly what is missing on a bad day.
# Runs before the finished line, so this run's block still counts as open.
if [ -f "$ONTIME" ]; then
  python3 "$ONTIME" record --date "$TODAY" >> "$LOG" 2>&1 \
    || echo "on-time: ontime.py record failed, receipt left as it was" >> "$LOG"
fi

echo "===== $(date '+%Y-%m-%d %H:%M:%S') finished (exit $STATUS) =====" >> "$LOG"
exit $STATUS

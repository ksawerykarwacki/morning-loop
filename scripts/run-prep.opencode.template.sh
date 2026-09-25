#!/bin/zsh
# Agent-manager unattended pre-run, OpenCode edition. Invoked by launchd on
# weekday mornings. Runs the read-only SENSE + PLAN half of /morning and writes
# today's plan file. Does NOT dispatch - that stays interactive (the morning gate).
#
# This is run-prep.template.sh with the client swapped. Everything that is not the
# invocation - caffeinate, the watchdog, the delivery safety net, alert_on_miss -
# is deliberately identical, because those were each paid for by a real failed run
# and none of them are Claude-specific.
#
# STATUS: the invocation below has NOT yet had a live unattended run. Do one
# supervised run by hand before trusting launchd with it. See INVOCATION below.

# launchd gives a minimal environment. opencode ships as a standalone binary in
# ~/.opencode/bin, which is on no system PATH, so the run dies as "command not
# found" in a log nobody opens. bun and node are here for the MCP servers, not
# for opencode itself.
#
# Deliberately NOT using the fnm shim path: fnm puts node under
# ~/.local/state/fnm_multishells/<pid>_<timestamp>/bin, which is created per
# interactive shell and will not exist when launchd runs this. Point at a stable
# install instead.
export PATH="$HOME/.opencode/bin:$HOME/.bun/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

WORKDIR="<PATH TO YOUR CLONE>"        # FILL, e.g. $HOME/Developer/tnc/morning-loop
MODEL="${MORNING_MODEL:-}"            # optional pin, e.g. github-copilot/claude-opus-5
LOG="$WORKDIR/briefs/launchd.log"

cd "$WORKDIR" || { echo "$(date) FAILED cd $WORKDIR" >> "$LOG"; exit 1; }
mkdir -p "$WORKDIR/briefs/delivery-receipts"

# Hold the machine awake for the whole run. A launchd DarkWake gives roughly 45
# seconds before macOS returns to sleep and kills everything: on 2026-08-20 the
# run fired at 08:01:04 and the machine slept at 08:01:49, producing nothing and
# reporting nothing until the lid opened. -w ties the assertion to this script's
# pid, so it retires on its own without needing cleanup on every exit path.
caffeinate -i -w $$ &

echo "===== $(date '+%Y-%m-%d %H:%M:%S') starting /morning --prep (opencode) =====" >> "$LOG"

# INVOCATION. `opencode run` is the headless, single-shot form. Two shapes work
# depending on version; MODE picks one so the first supervised run can flip it in
# one line instead of editing the command:
#   command  ->  opencode run --command morning -- --prep     (explicit command)
#   message  ->  opencode run "/morning --prep"               (slash in the prompt)
MODE="${MORNING_INVOKE_MODE:-command}"
set -- run
[ -n "$MODEL" ] && set -- "$@" --model "$MODEL"
if [ "$MODE" = "command" ]; then
  set -- "$@" --command morning -- --prep
else
  set -- "$@" "/morning --prep"
fi

opencode "$@" >> "$LOG" 2>&1 &
RUN_PID=$!
( sleep 1200; kill -0 "$RUN_PID" 2>/dev/null && {
    echo "watchdog: prep exceeded 20 min, killing $RUN_PID" >> "$LOG"
    kill -TERM "$RUN_PID" 2>/dev/null
  } ) >>"$LOG" 2>&1 &
WATCHDOG_PID=$!
wait "$RUN_PID"

STATUS=$?
# Reap the sleep BEFORE its parent: killing the subshell alone orphans the sleep,
# which keeps an inherited stdout open and makes anything waiting on this script
# block for the full 20 minutes after the run has already finished. The explicit
# redirect above is the other half - without it the watchdog holds the caller's pipe.
pkill -P "$WATCHDOG_PID" 2>/dev/null
kill "$WATCHDOG_PID" 2>/dev/null      # run finished in time; retire the watchdog
echo "===== $(date '+%Y-%m-%d %H:%M:%S') opencode finished (exit $STATUS) =====" >> "$LOG"

# --------------------------------------------------------------------------
# DELIVERY SAFETY NET. Phase 2b is supposed to deliver the brief itself. This
# block does not trust that: if no "sent" receipt exists for today, it delivers
# here. Delivery is the whole point of the loop, so it must not depend on the
# model remembering to call a script. Idempotent - the notifier reuses today's id.
# --------------------------------------------------------------------------
TODAY=$(date '+%Y-%m-%d')
PLAN="$WORKDIR/briefs/morning-plan-$TODAY.md"
RECEIPT="$WORKDIR/briefs/delivery-receipts/$TODAY.json"
NOTIFIER="$WORKDIR/scripts/notify.py"

[ -f "$HOME/.config/morning-loop/notify.env" ] && . "$HOME/.config/morning-loop/notify.env"

# alert_on_miss. A failure that only reaches a log file IS a silent failure:
# nobody reads a log they have no reason to open. So every failure path notifies,
# using osascript directly rather than the notifier script, because the whole
# point is that it still works when the run itself is broken.
alert_on_miss() {
  reason="$1"; detail="$2"
  echo "alert: $reason - $detail" >> "$LOG"
  /usr/bin/osascript -e "display notification \"$detail\" with title \"⚠️ Morning brief did NOT run\" subtitle \"$reason\" sound name \"Basso\"" >/dev/null 2>&1
  printf '{\n  "date": "%s",\n  "status": "failed",\n  "stage": "%s",\n  "error": "%s",\n  "checked_at": "%s"\n}\n' \
    "$TODAY" "$reason" "$detail" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$RECEIPT"
}

# `sent` covers macos and mattermost. `rendered_not_sent` is what `delivery.channel:
# file` records, because rendering the page delivers the brief without sending
# anything. Both mean today's brief already exists and must not be redone.
if grep -qE '"status": "(sent|rendered_not_sent)"' "$RECEIPT" 2>/dev/null; then
  echo "delivery: already delivered today, nothing to do" >> "$LOG"
elif [ ! -f "$PLAN" ]; then
  # Diagnose WHY from what opencode actually said, because "it didn't run" is
  # useless and "your auth expired" is actionable.
  if grep -qi "not authenticated\|auth.*expired\|invalid api key\|please run.*auth\|unauthorized" "$LOG"; then
    alert_on_miss "OpenCode auth expired" "Run: opencode auth login, then /morning for today's brief."
  elif grep -qi "command not found:\|unknown command\|invalid choice\|unknown option" "$LOG"; then
    alert_on_miss "Runner invocation is wrong" "opencode rejected the command. Flip MORNING_INVOKE_MODE (command|message) in run-prep and retest."
  elif grep -qi "mcp.*timeout\|mcp.*timed out\|sse.*closed\|sse.*disconnected\|sse.*timeout\|event stream.*closed\|event stream.*ended\|econnreset\|connection reset by peer" "$LOG"; then
    alert_on_miss "An MCP server dropped mid-run (SSE/stream timeout)" "A tool server's stream died, so the run could not finish. Re-run /morning manually; if it recurs, reconnect that MCP server."
  elif [ $STATUS -ne 0 ]; then
    alert_on_miss "The prep run failed (exit $STATUS)" "No brief today. Check briefs/launchd.log, then run /morning manually."
  else
    alert_on_miss "No plan file was written" "The run finished but produced nothing. Check briefs/launchd.log."
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

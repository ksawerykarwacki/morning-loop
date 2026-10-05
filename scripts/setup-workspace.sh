#!/bin/zsh
# setup-workspace.sh: give the loop the folder layout it actually runs in.
#
# Why this script exists
# ---------------------
# /morning and the scheduled runner read and write fixed workspace paths:
#   05-automation/agent-manager/scripts/*.py      the trust, asks, tickets, notify scripts
#   01-sprint-operations/current/                 the brief, drafts and questions
#   06-skills/skills/agent-manager-config.<you>.yml
# A standalone clone of this package has none of them, so a fresh clone installed
# cleanly, passed the doctor, and then could not find its own scripts on the first
# run. Found by the v4 fresh-install test, 2026-10-05.
#
# This script creates that layout inside the folder you work from (an existing
# workspace or a brand-new empty one) and LINKS the package into it rather than
# copying it, so `git pull` in the package updates every workspace that uses it.
# It never overwrites a file of yours: anything already there is left alone and
# reported.
#
# Usage:
#   ./scripts/setup-workspace.sh <workspace-dir> [your-name]
#   ./scripts/setup-workspace.sh --dry-run <workspace-dir> [your-name]

set -u
DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
WS="${1:-}"
WHO="${2:-${USER:-me}}"
if [ -z "$WS" ]; then
  echo "usage: $0 [--dry-run] <workspace-dir> [your-name]"; exit 2
fi

HERE="${0:A:h}"
PKG="${HERE:h}"
[ $DRY -eq 0 ] && mkdir -p "$WS"
WS="${WS:A}"

say() { echo "  $1"; }
run() { [ $DRY -eq 1 ] && say "(dry) $*" || "$@"; }

echo "morning loop · workspace setup"
echo "  package:   $PKG"
echo "  workspace: $WS"
[ "$WS" = "$PKG" ] && { echo "✗ the workspace cannot be the package clone itself. Pick another folder."; exit 2; }

echo
echo "folders"
for d in 01-sprint-operations/current/agent-drafts 05-automation/agent-manager/delivery-receipts \
         05-automation/agent-manager/coach 06-skills/skills 10-meeting-notes; do
  if [ -d "$WS/$d" ]; then say "= $d"; else run mkdir -p "$WS/$d"; say "+ $d"; fi
done

echo
echo "links into the package"
link() {   # link <path in workspace> <target in package>
  local at="$WS/$1" to="$PKG/$2"
  if [ -L "$at" ]; then
    if [ "${at:A}" = "${to:A}" ]; then say "= $1"; else say "! $1 links somewhere else (${at:A}); left alone"; fi
  elif [ -e "$at" ]; then
    say "! $1 already exists and is not a link; left alone. Point it at $to yourself if you want updates"
  else
    run ln -s "$to" "$at"; say "+ $1 -> $2"
  fi
}
link 05-automation/agent-manager/scripts scripts
link 05-automation/agent-manager/morning-loop-share .
link 05-automation/agent-manager/rubrics rubrics

echo
echo "starter files (only where none exists)"
starter() {   # starter <path in workspace> <source in package>
  local at="$WS/$1" src="$PKG/$2"
  if [ -e "$at" ]; then say "= $1 (yours, untouched)"; else run cp "$src" "$at"; say "+ $1"; fi
}
starter "06-skills/skills/agent-manager-config.$WHO.yml" agent-manager-config.template.yml
starter 05-automation/agent-manager/coach/plan.md coach/plan.template.md
starter 01-sprint-operations/current/commitments-ledger.md templates/commitments-ledger.template.md
# The reconciler refuses a ledger with no date marker, so stamp today on a fresh one.
L="$WS/01-sprint-operations/current/commitments-ledger.md"
[ $DRY -eq 0 ] && grep -q '`last_reconciled: never`' "$L" 2>/dev/null && \
  sed -i '' "s/\`last_reconciled: never\`/\`last_reconciled: $(date +%Y-%m-%d)\`/" "$L"
[ -e "$WS/05-automation/agent-manager/run-log.md" ] || { run touch "$WS/05-automation/agent-manager/run-log.md"; say "+ 05-automation/agent-manager/run-log.md"; }

echo
echo "next"
say "1. Fill 06-skills/skills/agent-manager-config.$WHO.yml (owner, timezone, routing). /jtbd-capture helps."
say "2. export MORNING_CONFIG=\"$WS/06-skills/skills/agent-manager-config.$WHO.yml\""
say "3. cd \"$WS\" && python3 05-automation/agent-manager/scripts/doctor.py"
say "4. Run /morning once by hand from $WS, then schedule it: scripts/SETUP-DELIVERY.md (WORKDIR=$WS)."
[ $DRY -eq 1 ] && echo && echo "Dry run finished. Nothing was written."
exit 0

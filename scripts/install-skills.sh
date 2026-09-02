#!/bin/zsh
# install-skills.sh — put the package's skills where skills actually load from,
# then PROVE it resolved instead of assuming the copy worked.
#
# Why this script exists
# ---------------------
# Skills load from exactly two places:
#   <repo>/.claude/skills/<name>/SKILL.md
#   ~/.claude/skills/<name>/SKILL.md
# and each needs a directory plus frontmatter with a description.
#
# Until v3.1 this package shipped skills as flat files in skills/*.md, which is
# neither shape. Three developers reported their drafters "never ran" and every
# one of them was right: the config named skills that could not resolve, and
# nothing checked. Xitong: "it's easy to half-adopt. I had a working config,
# drafts, and run-log, but /morning itself didn't work because the command files
# were never copied. Nothing in the flow catches this."
#
# So this script does the copy AND runs doctor.py afterwards. Verifying the end
# deliverable rather than the exit code is the same rule the loop already applies
# to brief delivery, for the same reason.
#
# Clients load from different directories
# --------------------------------------
# Claude Code, Cursor and OpenCode each read skills from a different place, and
# installing into the wrong one is invisible: the copy succeeds, the config still
# names the skill, and nothing ever runs. That is the same half-adopt failure this
# script exists to prevent, so it gets the same treatment — detect the client,
# print it, and let it be overridden.
#
# OpenCode has no separate commands directory: a skill IS the slash command. So
# on OpenCode the command files install alongside the skills, and get a `name:`
# injected, because a skill without one does not register.
#
# Usage:
#   ./scripts/install-skills.sh                    # detect client, install to its skills dir
#   ./scripts/install-skills.sh --client=opencode  # force a client (claude | opencode)
#   ./scripts/install-skills.sh --repo             # install into this repo instead of $HOME
#   ./scripts/install-skills.sh --dry-run          # show what would happen, touch nothing
#
# MORNING_CLIENT=opencode is honoured too, for the scheduled runner.

set -u
HERE="${0:A:h}"
PKG="${HERE:h}"                     # the morning-loop-share directory
SRC="$PKG/skills"
DRY=0
REPO_SCOPE=0
CLIENT="${MORNING_CLIENT:-auto}"

for arg in "$@"; do
  case "$arg" in
    # --repo installs into the git root of wherever you are, not a fixed number of
    # levels above the package. The old form assumed the workspace layout and walked
    # outside the repo entirely when the package was cloned standalone.
    --repo)     REPO_SCOPE=1 ;;
    --dry-run)  DRY=1 ;;
    --client=*) CLIENT="${arg#--client=}" ;;
    --client)   echo "--client takes a value, e.g. --client=opencode"; exit 2 ;;
    -h|--help)  sed -n '2,42p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done

if [ "$CLIENT" = "auto" ]; then
  if [ -d "$HOME/.claude/skills" ]; then
    CLIENT=claude
  elif [ -d "$HOME/.config/opencode" ]; then
    CLIENT=opencode
  else
    CLIENT=claude
  fi
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PKG")"

case "$CLIENT" in
  claude)
    if [ $REPO_SCOPE -eq 1 ]; then
      TARGET="$REPO_ROOT/.claude/skills"; CMD_TARGET="$REPO_ROOT/.claude/commands"
    else
      TARGET="$HOME/.claude/skills";      CMD_TARGET="$HOME/.claude/commands"
    fi
    CMD_AS_SKILL=0
    ;;
  opencode)
    if [ $REPO_SCOPE -eq 1 ]; then
      TARGET="$REPO_ROOT/.opencode/skills"
    else
      TARGET="$HOME/.config/opencode/skills"
    fi
    CMD_TARGET="$TARGET"
    CMD_AS_SKILL=1
    ;;
  *) echo "✗ unknown client: $CLIENT (expected claude or opencode)"; exit 2 ;;
esac

[ -d "$SRC" ] || { echo "✗ no skills directory at $SRC"; exit 2; }

echo "morning loop · skill install"
echo "  client: $CLIENT"
echo "  from: $SRC"
echo "  to:   $TARGET"
[ $DRY -eq 1 ] && echo "  (dry run, nothing will be written)"
echo

installed=0 skipped=0 replaced=0
for dir in "$SRC"/*/; do
  name="${dir:A:t}"          # :A resolves the trailing slash away, :t takes the leaf
  src="$dir/SKILL.md"
  [ -f "$src" ] || { echo "  ✗ $name: package has no SKILL.md, skipping"; skipped=$((skipped+1)); continue; }

  # Refuse to install something that cannot register as a skill. Shipping a file
  # without frontmatter is how you get a config that looks complete and does nothing.
  if ! head -c 400 "$src" | grep -q '^---' || ! head -c 400 "$src" | grep -q 'description:'; then
    echo "  ✗ $name: no frontmatter with a description, refusing to install"
    skipped=$((skipped+1)); continue
  fi

  dest="$TARGET/$name/SKILL.md"
  if [ -f "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      echo "  = $name: already current"; skipped=$((skipped+1)); continue
    fi
    # Never silently overwrite someone's edited skill. Their version may be the
    # better one: Xitong wrote a dev drafter the package does not have.
    if [ $DRY -eq 0 ]; then
      cp "$dest" "$dest.before-v3.1" 2>/dev/null
    fi
    echo "  ~ $name: differs from yours, backed up to SKILL.md.before-v3.1"
    replaced=$((replaced+1))
  else
    echo "  + $name"
    installed=$((installed+1))
  fi
  if [ $DRY -eq 0 ]; then
    mkdir -p "$TARGET/$name" && cp "$src" "$dest"
  fi
done

echo
echo "  new: $installed · updated: $replaced · unchanged/skipped: $skipped"

# ---------------------------------------------------------------------------
# Commands. Skipping these is a reported failure, not a hypothetical one:
# "I had a working config, drafts, and run-log, but /morning itself didn't work
# because the command files were never copied. Nothing in the flow catches this."
# ---------------------------------------------------------------------------
CMD_SRC="$PKG/commands"
if [ -d "$CMD_SRC" ]; then
  echo
  echo "commands -> $CMD_TARGET"
  for f in "$CMD_SRC"/*.md; do
    name="${f:t}"
    stem="${name%.md}"
    if [ $CMD_AS_SKILL -eq 1 ]; then
      dest="$CMD_TARGET/$stem/SKILL.md"
    else
      dest="$CMD_TARGET/$name"
    fi

    # On OpenCode a command is installed as a skill, and a skill whose frontmatter
    # has no `name:` never registers — the exact silent failure the rest of this
    # script exists to catch. morning.md, standup.md and brief.md ship without one,
    # so stage a copy with the stem injected rather than shipping a dead skill.
    staged="$f"
    if [ $CMD_AS_SKILL -eq 1 ] && ! head -c 400 "$f" | grep -q '^name:'; then
      staged="${TMPDIR:-/tmp}/morning-loop-install-$stem.md"
      awk -v n="$stem" 'NR==1 && /^---/ {print; print "name: " n; next} {print}' "$f" > "$staged"
    fi

    if [ -f "$dest" ] && ! cmp -s "$staged" "$dest"; then
      [ $DRY -eq 0 ] && cp "$dest" "$dest.before-v3.1"
      echo "  ~ $stem: differs from yours, backed up to ${dest:t}.before-v3.1"
    elif [ -f "$dest" ]; then
      echo "  = $stem: already current"
      [ "$staged" != "$f" ] && rm -f "$staged"
      continue
    else
      echo "  + $stem"
    fi
    [ $DRY -eq 0 ] && { mkdir -p "${dest:h}" && cp "$staged" "$dest"; }
    [ "$staged" != "$f" ] && rm -f "$staged"
  done
else
  echo
  echo "  ! no commands/ directory in the package. /morning will not resolve."
fi

if [ $DRY -eq 1 ]; then
  echo; echo "Dry run finished. Re-run without --dry-run to apply."; exit 0
fi

echo
echo "── verifying, because a copy that exits 0 is not proof ──"
DOCTOR="$HERE/doctor.py"
if [ -f "$DOCTOR" ]; then
  python3 "$DOCTOR" --client "$CLIENT"
  exit $?
else
  echo "✗ doctor.py not found next to this script. Install is unverified."
  exit 1
fi

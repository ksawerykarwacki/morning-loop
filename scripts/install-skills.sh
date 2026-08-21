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
# Usage:
#   ./scripts/install-skills.sh              # install to ~/.claude/skills (default)
#   ./scripts/install-skills.sh --repo       # install into this repo's .claude/skills
#   ./scripts/install-skills.sh --dry-run    # show what would happen, touch nothing

set -u
HERE="${0:A:h}"
PKG="${HERE:h}"                     # the morning-loop-share directory
SRC="$PKG/skills"
TARGET="$HOME/.claude/skills"
DRY=0

for arg in "$@"; do
  case "$arg" in
    --repo)    TARGET="$(cd "$PKG/../../.." && pwd)/.claude/skills" ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done

[ -d "$SRC" ] || { echo "✗ no skills directory at $SRC"; exit 2; }

echo "morning loop · skill install"
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
CMD_TARGET="$HOME/.claude/commands"
if [ -d "$CMD_SRC" ]; then
  echo
  echo "commands -> $CMD_TARGET"
  for f in "$CMD_SRC"/*.md; do
    name="${f:t}"
    dest="$CMD_TARGET/$name"
    if [ -f "$dest" ] && ! cmp -s "$f" "$dest"; then
      [ $DRY -eq 0 ] && cp "$dest" "$dest.before-v3.1"
      echo "  ~ $name: differs from yours, backed up to $name.before-v3.1"
    elif [ -f "$dest" ]; then
      echo "  = $name: already current"; continue
    else
      echo "  + $name"
    fi
    [ $DRY -eq 0 ] && { mkdir -p "$CMD_TARGET" && cp "$f" "$dest"; }
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
  python3 "$DOCTOR"
  exit $?
else
  echo "✗ doctor.py not found next to this script. Install is unverified."
  exit 1
fi

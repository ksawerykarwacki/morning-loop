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
#   ./scripts/install-skills.sh --repo             # install into the load path of the
#                                                  # workspace this clone sits in
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

# Resolve the root whose load path actually loads. The git root is right for a
# standalone clone and WRONG when the package is cloned inside a workspace, which
# is the layout ADOPT-MORNING.md blesses: then the git root is the package, and
# <package>/.claude/skills is a folder nothing loads from, as the package's own
# .gitignore says. So probe the layout for a workspace above the clone instead of
# counting parents. doctor.py's repo_root() makes the same two probes, and the two
# have to agree or the installer writes where the doctor does not look.
#
# The probe runs from $PKG, not from wherever you stand: asking git about $PWD
# answers about an unrelated repo when this is invoked by absolute path.
resolve_root() {
  local root up
  root="$(cd "$PKG" && git rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$root" ] || root="$PKG"
  if [ -d "$root/commands" ] && [ -d "$root/skills" ] && [ -f "$root/scripts/doctor.py" ]; then
    up="${root:h}"
    while [ "$up" != "/" ] && [ "$up" != "$HOME" ]; do
      if [ -d "$up/06-skills" ] || [ -d "$up/05-automation" ] || [ -d "$up/.claude" ]; then
        echo "$up"; return 0
      fi
      up="${up:h}"
    done
  fi
  echo "$root"
}

for arg in "$@"; do
  case "$arg" in
    --repo)     REPO_SCOPE=1 ;;
    --dry-run)  DRY=1 ;;
    --client=*) CLIENT="${arg#--client=}" ;;
    --client)   echo "--client takes a value, e.g. --client=opencode"; exit 2 ;;
    -h|--help)  sed -n '2,43p' "$0"; exit 0 ;;
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

REPO_ROOT="$(resolve_root)"

# Refuse rather than write into a path nothing can load from. Installing skills
# where the loop cannot see them is the exact failure this package exists to
# prevent, and it is quieter than any error.
if [ $REPO_SCOPE -eq 1 ] && { [ ! -d "$REPO_ROOT" ] || [ ! -w "$REPO_ROOT" ]; }; then
  echo "✗ --repo resolved to: $REPO_ROOT"
  echo "  That is not a writable directory, so nothing would ever load from it."
  echo "  Run without --repo to install under \$HOME, which always loads."
  exit 2
fi

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
if [ $REPO_SCOPE -eq 1 ]; then
  if [ "$REPO_ROOT" = "$PKG" ]; then
    echo "  note: no workspace above this clone, so --repo resolved to the clone itself."
    echo "        That path loads only for a session rooted inside the clone; the"
    echo "        default (\$HOME) loads everywhere."
  else
    echo "  root: $REPO_ROOT  (workspace holding this clone)"
  fi
fi
[ $DRY -eq 1 ] && echo "  (dry run, nothing will be written)"
echo


# ---------------------------------------------------------------------------
# stock_copy <file>: true if the package has EVER shipped exactly this content.
# A differing file that is a stock copy is safe to upgrade. One the package never
# shipped is someone's own work and is kept: the new version goes beside it as
# <name>.v4-new. Before v4 this script overwrote both, so a tuned skill silently
# stopped loading. No git history means nothing can be proven stock, so keep it.
# ---------------------------------------------------------------------------
stock_copy() {
  local h; h=$(git hash-object --no-filters "$1" 2>/dev/null) || return 1
  grep -qx "$h" "$PKG/scripts/known-shipped-blobs.txt" 2>/dev/null && return 0
  git -C "$PKG" rev-parse --git-dir >/dev/null 2>&1 || return 1
  git -C "$PKG" cat-file -e "$h" 2>/dev/null
}
kept=0
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
  # A workspace may link its load path straight at this clone. Such an install is
  # current by construction, and copying would follow the link and rewrite the
  # shared package in place. Report where the link really lands, resolved rather
  # than asserted, and leave it alone.
  if [ -L "$TARGET/$name" ] || [ -L "$dest" ]; then
    echo "  = $name: symlinked, real target ${dest:A}"
    skipped=$((skipped+1)); continue
  fi
  if [ -f "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      echo "  = $name: already current"; skipped=$((skipped+1)); continue
    fi
    # Never overwrite someone's own skill. Their version may be the better one.
    if ! stock_copy "$dest"; then
      [ $DRY -eq 0 ] && cp "$src" "$dest.v4-new"
      echo "  ! $name: yours (not a shipped version), KEPT. v4 is beside it as SKILL.md.v4-new"
      kept=$((kept+1)); continue
    fi
    [ $DRY -eq 0 ] && cp "$dest" "$dest.before-v4" 2>/dev/null
    echo "  ~ $name: stock copy upgraded, old one at SKILL.md.before-v4"
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
echo "  new: $installed · upgraded: $replaced · yours kept: $kept · unchanged/skipped: $skipped"

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

    # Same symlink rule as the skills loop, and for the same reason: following the
    # link would overwrite the package this script is reading from.
    if [ -L "$dest" ] || { [ $CMD_AS_SKILL -eq 1 ] && [ -L "${dest:h}" ]; }; then
      echo "  = $stem: symlinked, real target ${dest:A}"; continue
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

    if [ -f "$dest" ] && ! cmp -s "$staged" "$dest" && ! stock_copy "$dest"; then
      [ $DRY -eq 0 ] && cp "$staged" "$dest.v4-new"
      echo "  ! $stem: yours (not a shipped version), KEPT. v4 is beside it as ${dest:t}.v4-new"
      [ "$staged" != "$f" ] && rm -f "$staged"
      continue
    elif [ -f "$dest" ] && ! cmp -s "$staged" "$dest"; then
      [ $DRY -eq 0 ] && cp "$dest" "$dest.before-v4"
      echo "  ~ $stem: stock copy upgraded, old one at ${dest:t}.before-v4"
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

# ---------------------------------------------------------------------------
# Agents (v4). The verify stage dispatches claim-verifier, disagreement-judge,
# sense-probe and job-drafter by name. Without them every check falls back to a
# general agent that can write files, so "read-only by toolset" stops being true.
# Claude Code only; definitions load at session start, so restart after install.
# ---------------------------------------------------------------------------
AGENT_SRC="$PKG/agents"
if [ "$CLIENT" = "claude" ] && [ -d "$AGENT_SRC" ]; then
  if [ $REPO_SCOPE -eq 1 ]; then AGENT_TARGET="$REPO_ROOT/.claude/agents"; else AGENT_TARGET="$HOME/.claude/agents"; fi
  echo
  echo "agents -> $AGENT_TARGET"
  for f in "$AGENT_SRC"/*.md; do
    name="${f:t}"; dest="$AGENT_TARGET/$name"
    [ "$name" = "README.md" ] && continue
    if [ -L "$dest" ]; then echo "  = ${name%.md}: symlinked, real target ${dest:A}"; continue; fi
    if [ -f "$dest" ] && ! cmp -s "$f" "$dest" && ! stock_copy "$dest"; then
      [ $DRY -eq 0 ] && cp "$f" "$dest.v4-new"
      echo "  ! ${name%.md}: yours (not a shipped version), KEPT. v4 is beside it as $name.v4-new"
      continue
    elif [ -f "$dest" ] && ! cmp -s "$f" "$dest"; then
      [ $DRY -eq 0 ] && cp "$dest" "$dest.before-v4"
      echo "  ~ ${name%.md}: stock copy upgraded, old one at $name.before-v4"
    elif [ -f "$dest" ]; then
      echo "  = ${name%.md}: already current"; continue
    else
      echo "  + ${name%.md}"
    fi
    [ $DRY -eq 0 ] && { mkdir -p "$AGENT_TARGET" && cp "$f" "$dest"; }
  done
  echo "  restart Claude Code after installing: agent definitions load at session start"
fi

if [ $DRY -eq 1 ]; then
  echo; echo "Dry run finished. Re-run without --dry-run to apply."; exit 0
fi

echo
echo "── verifying, because a copy that exits 0 is not proof ──"
DOCTOR="$HERE/doctor.py"
if [ -f "$DOCTOR" ]; then
  # State the root when we installed with --repo, so the check runs against the
  # root we just wrote into rather than one the doctor resolves separately.
  # On a first install there is no config yet, and that is the next step, not a
  # failure: the v4 fresh-install test exited 2 here and read as a broken install.
  if [ -z "${MORNING_CONFIG:-}" ] && ! ls "$PKG"/agent-manager-config.*.yml 2>/dev/null | grep -qv template \
       && [ $REPO_SCOPE -eq 0 ]; then
    echo "✓ installed. No config yet, which is expected on a first install."
    echo "  Next: ./scripts/setup-workspace.sh <your workspace folder> <your-name>"
    echo "  It creates the folders the loop writes to, links this package in, copies a"
    echo "  starter config, and tells you how to run the doctor against it."
    exit 0
  fi
  if [ $REPO_SCOPE -eq 1 ]; then
    python3 "$DOCTOR" --client "$CLIENT" --repo-root "$REPO_ROOT"
  else
    python3 "$DOCTOR" --client "$CLIENT"
  fi
  exit $?
else
  echo "✗ doctor.py not found next to this script. Install is unverified."
  exit 1
fi

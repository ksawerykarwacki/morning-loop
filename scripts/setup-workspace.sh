#!/bin/sh
# setup-workspace.sh: kept because the docs name it. The logic lives in
# setup_workspace.py so it runs the same on Mac, Linux and Windows.
#   ./scripts/setup-workspace.sh <workspace-dir> [your-name] [--dry-run] [--copy]
exec python3 "$(dirname "$0")/setup_workspace.py" "$@"

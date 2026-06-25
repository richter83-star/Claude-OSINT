#!/usr/bin/env bash
# sync-from-bughunter.sh — mirror the shared recon skills FROM Claude-BugHunter.
#
# Claude-BugHunter is the canonical monorepo home for ALL skills. Claude-OSINT
# re-exports two of them (offensive-osint, osint-methodology). This script copies
# those two skill directories from a BugHunter checkout into this repo so the two
# copies never drift. EDIT THE SKILLS IN BUGHUNTER, NOT HERE.
#
# Usage:
#   ./scripts/sync-from-bughunter.sh --from /path/to/Claude-BugHunter        # sync (overwrites local copies)
#   ./scripts/sync-from-bughunter.sh --from /path/to/Claude-BugHunter --check # drift check only (CI; non-zero on drift)
#   BUGHUNTER_DIR=/path/to/Claude-BugHunter ./scripts/sync-from-bughunter.sh  # env-var form
#
# With no --from / $BUGHUNTER_DIR, a few common sibling locations are probed.
# --check is intended for CI, where .gitattributes guarantees LF on both sides.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS=(offensive-osint osint-methodology)

BUGHUNTER_DIR="${BUGHUNTER_DIR:-}"
CHECK_ONLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --from) BUGHUNTER_DIR="${2:-}"; shift 2 ;;
    --check|-c) CHECK_ONLY=true; shift ;;
    --help|-h) grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
done

# Probe common locations if not given explicitly.
if [ -z "$BUGHUNTER_DIR" ]; then
  for c in \
    "$REPO_ROOT/Bug Hunter/Claude-BugHunter" \
    "$REPO_ROOT/../Claude-BugHunter" \
    "$HOME/security-research/Claude-BugHunter"; do
    if [ -d "$c/skills" ]; then BUGHUNTER_DIR="$c"; break; fi
  done
fi

if [ -z "$BUGHUNTER_DIR" ] || [ ! -d "$BUGHUNTER_DIR/skills" ]; then
  echo "✗ Claude-BugHunter repo not found. Pass --from <path> or set BUGHUNTER_DIR." >&2
  exit 2
fi

echo "==> Source of truth: $BUGHUNTER_DIR"
drift=0

for s in "${SKILLS[@]}"; do
  SRC="$BUGHUNTER_DIR/skills/$s"
  DST="$REPO_ROOT/skills/$s"
  if [ ! -d "$SRC" ]; then
    echo "  ✗ source missing: $SRC" >&2
    exit 2
  fi
  if [ "$CHECK_ONLY" = true ]; then
    if diff -rq "$SRC" "$DST" >/dev/null 2>&1; then
      echo "  ✓ $s: in sync"
    else
      echo "  ✗ $s: DRIFT (run without --check to re-sync, or edit in BugHunter)"
      drift=1
    fi
  else
    rm -rf "$DST"
    mkdir -p "$DST"
    cp -r "$SRC/." "$DST/"
    find "$DST" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
    echo "  ✓ $s: synced from BugHunter"
  fi
done

if [ "$CHECK_ONLY" = true ]; then
  [ "$drift" -eq 0 ] && echo "==> In sync with BugHunter." || echo "==> DRIFT detected." >&2
  exit "$drift"
fi

echo "==> Done. The 2 recon skills are mirrored from BugHunter."
echo "    Reminder: edit these skills in Claude-BugHunter, then re-run this script."

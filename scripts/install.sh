#!/usr/bin/env bash
# =====================================================================
# install.sh — install the claude-osint recon skills into ~/.claude/skills/
#
# Copies the two skills (osint-methodology, offensive-osint) and records an
# install manifest so they can be cleanly removed later. These two skills are
# shared with — and canonically maintained in — Claude-BugHunter. Both bundles
# record a manifest, so uninstalling EITHER keeps a skill the other still owns.
#
#   bash scripts/install.sh              install
#   bash scripts/install.sh --uninstall  remove (keeps skills BugHunter still owns)
#   -h | --help                          show this help
# =====================================================================
set -e

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SKILLS=(osint-methodology offensive-osint)
DEST="$HOME/.claude/skills"
BACKUP_DEST="$HOME/.claude/install-backups/$(date +%Y%m%d-%H%M%S)"
BUNDLE_NAME="claude-osint"
MANIFEST_DIR="$HOME/.claude/.skill-manifests"
MANIFEST="$MANIFEST_DIR/$BUNDLE_NAME.txt"

usage() { sed -n '2,/^# ===/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

DO_UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) DO_UNINSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

uninstall_bundle() {
  if [ ! -f "$MANIFEST" ]; then
    echo "No manifest at $MANIFEST — nothing tracked to uninstall."
    return 0
  fi
  echo "Uninstalling $BUNDLE_NAME using $MANIFEST"
  local rel target other owned removed=0 kept=0
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    target="$HOME/.claude/$rel"
    owned=0
    for other in "$MANIFEST_DIR"/*.txt; do
      [ -e "$other" ] || continue
      [ "$other" = "$MANIFEST" ] && continue
      if grep -qxF "$rel" "$other" 2>/dev/null; then owned=1; break; fi
    done
    if [ "$owned" = "1" ]; then kept=$((kept + 1)); else rm -rf "$target"; removed=$((removed + 1)); fi
  done < "$MANIFEST"
  rm -f "$MANIFEST"
  echo "  ✓ removed $removed item(s); kept $kept still owned by another bundle (e.g. claude-bughunter)"
}

if [ "$DO_UNINSTALL" = "1" ]; then uninstall_bundle; exit 0; fi

mkdir -p "$DEST" "$MANIFEST_DIR"
echo "Installing $BUNDLE_NAME skills → $DEST"
for name in "${SKILLS[@]}"; do
  src="$REPO_DIR/skills/$name"
  if [ ! -d "$src" ]; then echo "  ⚠ missing $src — skipping"; continue; fi
  if [ -d "$DEST/$name" ] && [ ! -L "$DEST/$name" ]; then
    if diff -rq --exclude=__pycache__ "$src" "$DEST/$name" >/dev/null 2>&1; then
      echo "  = $name already present and identical — skipped"
    else
      mkdir -p "$BACKUP_DEST"; mv "$DEST/$name" "$BACKUP_DEST/$name"
      cp -r "$src" "$DEST/$name"; echo "  ✓ $name installed (previous backed up to $BACKUP_DEST)"
    fi
  else
    cp -r "$src" "$DEST/$name"; echo "  ✓ $name installed"
  fi
done

{ for name in "${SKILLS[@]}"; do echo "skills/$name"; done; } > "$MANIFEST"
echo "  ✓ Install manifest → $MANIFEST"
echo ""
echo "Done. Both skills auto-trigger in Claude Code. Uninstall later:"
echo "  bash scripts/install.sh --uninstall"

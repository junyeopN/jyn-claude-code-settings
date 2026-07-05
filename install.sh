#!/usr/bin/env bash
# Installs this repo's Claude Code config into ~/.claude on the current machine.
# Existing files are backed up first, never silently discarded.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/claude"
CLAUDE_DIR="$HOME/.claude"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CLAUDE_DIR/backups/config-sync-$STAMP"

mkdir -p "$CLAUDE_DIR"

backup_if_exists() {
  local rel="$1"
  local target="$CLAUDE_DIR/$rel"
  if [ -e "$target" ]; then
    mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
    cp -R "$target" "$BACKUP_DIR/$rel"
  fi
}

copy_merge() {
  local rel="$1"
  local is_dir="$2"
  local src="$SRC_DIR/$rel"
  [ -e "$src" ] || return 0
  backup_if_exists "$rel"
  local dest="$CLAUDE_DIR/$rel"
  if [ "$is_dir" = "dir" ]; then
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
  else
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

clone_or_pull() {
  local target="$1"
  local url="$2"
  if [ ! -d "$target/.git" ]; then
    echo "Cloning $url -> $target"
    git clone --quiet "$url" "$target"
  else
    git -C "$target" pull --quiet
  fi
}

echo "Installing Claude config into $CLAUDE_DIR (backups in $BACKUP_DIR)"

copy_merge "settings.json" file
copy_merge "CLAUDE.md" file
copy_merge "commands" dir
copy_merge "agents" dir
copy_merge "output-styles" dir

# --- Plugin marketplaces: merge the registry entry, then clone the repo ---
MKT_FILE="$SRC_DIR/plugins/known_marketplaces.json"
if [ -f "$MKT_FILE" ]; then
  LOCAL_MKT_FILE="$CLAUDE_DIR/plugins/known_marketplaces.json"
  mkdir -p "$(dirname "$LOCAL_MKT_FILE")"
  [ -f "$LOCAL_MKT_FILE" ] || echo '{}' > "$LOCAL_MKT_FILE"

  node "$REPO_DIR/scripts/merge-marketplaces.js" "$MKT_FILE" "$LOCAL_MKT_FILE" "$CLAUDE_DIR" \
    > "$REPO_DIR/.marketplaces-to-clone.tmp"

  while read -r name repo; do
    [ -z "$name" ] && continue
    clone_or_pull "$CLAUDE_DIR/plugins/marketplaces/$name" "https://github.com/$repo"
  done < "$REPO_DIR/.marketplaces-to-clone.tmp"
  rm -f "$REPO_DIR/.marketplaces-to-clone.tmp"
fi

# --- Skills: clone any skill repos that aren't already present ---
SKILL_MANIFEST="$SRC_DIR/skills/manifest.json"
if [ -f "$SKILL_MANIFEST" ]; then
  node -e "
    const skills = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).skills || [];
    for (const s of skills) console.log(s.name + ' ' + s.url);
  " "$SKILL_MANIFEST" | while read -r name url; do
    [ -z "$name" ] && continue
    clone_or_pull "$CLAUDE_DIR/skills/$name" "$url"
  done
fi

echo "Done."

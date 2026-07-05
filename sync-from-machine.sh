#!/usr/bin/env bash
# Pulls the current machine's ~/.claude config into this repo so it can be
# committed and installed elsewhere with install.sh / install.ps1.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$REPO_DIR/claude"
CLAUDE_DIR="$HOME/.claude"

copy_if_exists() {
  local rel="$1"
  local is_dir="$2"
  local src="$CLAUDE_DIR/$rel"
  [ -e "$src" ] || return 0
  local dest="$DEST_DIR/$rel"
  if [ "$is_dir" = "dir" ]; then
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
  else
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

echo "Exporting Claude config from $CLAUDE_DIR into $DEST_DIR"

copy_if_exists "settings.json" file
copy_if_exists "CLAUDE.md" file
copy_if_exists "commands" dir
copy_if_exists "agents" dir
copy_if_exists "output-styles" dir

# --- Marketplaces: strip machine-specific paths/timestamps before saving ---
LOCAL_MKT_FILE="$CLAUDE_DIR/plugins/known_marketplaces.json"
if [ -f "$LOCAL_MKT_FILE" ]; then
  mkdir -p "$DEST_DIR/plugins"
  node -e "
    const fs = require('fs');
    const m = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    const clean = {};
    for (const [name, entry] of Object.entries(m)) clean[name] = { source: entry.source };
    fs.writeFileSync(process.argv[2], JSON.stringify(clean, null, 2));
  " "$LOCAL_MKT_FILE" "$DEST_DIR/plugins/known_marketplaces.json"
fi

# --- Skills: record git remotes of any skill folders that are their own git repos ---
SKILLS_DIR="$CLAUDE_DIR/skills"
if [ -d "$SKILLS_DIR" ]; then
  mkdir -p "$DEST_DIR/skills"
  echo '{"skills":[]}' > "$DEST_DIR/skills/manifest.json.tmp"
  entries="[]"
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d/.git" ] || continue
    name="$(basename "$d")"
    url="$(git -C "$d" remote get-url origin 2>/dev/null || true)"
    [ -n "$url" ] || continue
    entries="$(node -e "
      const arr = JSON.parse(process.argv[1]);
      arr.push({ name: process.argv[2], source: 'git', url: process.argv[3] });
      console.log(JSON.stringify(arr));
    " "$entries" "$name" "$url")"
  done
  node -e "
    const fs = require('fs');
    const skills = JSON.parse(process.argv[1]);
    fs.writeFileSync(process.argv[2], JSON.stringify({ skills }, null, 2));
  " "$entries" "$DEST_DIR/skills/manifest.json"
  rm -f "$DEST_DIR/skills/manifest.json.tmp"
fi

echo "Done. Review the diff, then commit and push."

# claude-config

Portable backup of my global Claude Code settings (`~/.claude`), so a new
machine can be brought up to the same state with one command.

## What's tracked

- `claude/settings.json` — permissions, effort level, update channel
- `claude/CLAUDE.md` — global memory/instructions (if any)
- `claude/commands/` — custom slash commands
- `claude/agents/` — custom subagent definitions
- `claude/output-styles/` — custom output styles
- `claude/plugins/known_marketplaces.json` — registered plugin marketplaces
  (just the `source`; machine-local `installLocation` is filled in on install)
- `claude/skills/manifest.json` — skills that live in their own git repos,
  recorded as `{name, url}` and cloned on install rather than vendored here

Deliberately **not** tracked: `.credentials.json`, OAuth tokens, session/
project history, shell snapshots, caches, the plugin blocklist (that's a
remote-fetched cache, not something you set). See `.gitignore`.

## Usage

### On the machine you're copying settings *from*

```powershell
./sync-from-machine.ps1   # Windows
./sync-from-machine.sh    # macOS/Linux
```

This pulls the current `~/.claude` config into `claude/`. Review the diff,
then commit and push.

### On a new machine

```powershell
git clone <this-repo-url> claude-config
cd claude-config
./install.ps1   # Windows
./install.sh    # macOS/Linux
```

This copies the tracked files into `~/.claude`, clones any registered
skill/marketplace repos that aren't already present, and backs up
anything it's about to overwrite into `~/.claude/backups/config-sync-<timestamp>/`.

Re-run `install` any time after pulling repo updates to re-apply them.

## Notes

- `settings.json` and `CLAUDE.md` are copied as full overwrites (after
  backup) — this is meant to make the new machine match the repo, not merge.
- `commands/`, `agents/`, `output-styles/` are merged additively (existing
  local files not in the repo are left alone).
- Marketplace/skill repos are cloned via plain `git clone` over HTTPS, so
  no credentials are embedded anywhere in this repo.

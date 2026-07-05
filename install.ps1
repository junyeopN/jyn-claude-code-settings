#!/usr/bin/env pwsh
# Installs this repo's Claude Code config into ~/.claude on the current machine.
# Existing files are backed up first, never silently discarded.

$ErrorActionPreference = "Stop"

$RepoDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir    = Join-Path $RepoDir "claude"
$ClaudeDir = Join-Path $HOME ".claude"
$Stamp     = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $ClaudeDir "backups/config-sync-$Stamp"

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

function Backup-IfExists($relPath) {
    $target = Join-Path $ClaudeDir $relPath
    if (Test-Path $target) {
        $dest = Join-Path $BackupDir $relPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -Recurse -Force $target $dest
    }
}

function Copy-Merge($srcRel, $isDir) {
    $src = Join-Path $SrcDir $srcRel
    if (-not (Test-Path $src)) { return }
    Backup-IfExists $srcRel
    $dest = Join-Path $ClaudeDir $srcRel
    if ($isDir) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $src "*") -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -Path $src -Destination $dest -Force
    }
}

Write-Host "Installing Claude config into $ClaudeDir (backups in $BackupDir)"

Copy-Merge "settings.json" $false
Copy-Merge "CLAUDE.md" $false
Copy-Merge "commands" $true
Copy-Merge "agents" $true
Copy-Merge "output-styles" $true

# --- Plugin marketplaces: clone the repo, then merge the registry entry ---
$mktFile = Join-Path $SrcDir "plugins/known_marketplaces.json"
if (Test-Path $mktFile) {
    $marketplaces = Get-Content $mktFile -Raw | ConvertFrom-Json
    $localMktFile = Join-Path $ClaudeDir "plugins/known_marketplaces.json"
    # Build an ordered dict manually (ConvertFrom-Json -AsHashtable needs PS 6+,
    # and this script also has to run on Windows PowerShell 5.1).
    $localMarketplaces = [ordered]@{}
    if (Test-Path $localMktFile) {
        $existing = Get-Content $localMktFile -Raw | ConvertFrom-Json
        foreach ($name in $existing.PSObject.Properties.Name) {
            $localMarketplaces[$name] = $existing.$name
        }
    }

    foreach ($name in $marketplaces.PSObject.Properties.Name) {
        $entry = $marketplaces.$name
        $installLocation = Join-Path $ClaudeDir "plugins/marketplaces/$name"

        if ($entry.source.source -eq "github") {
            $cloneUrl = "https://github.com/$($entry.source.repo)"
            if (-not (Test-Path (Join-Path $installLocation ".git"))) {
                Write-Host "Cloning marketplace '$name' from $cloneUrl"
                git clone --quiet $cloneUrl $installLocation
            } else {
                git -C $installLocation pull --quiet
            }
        }

        $localMarketplaces[$name] = @{
            source          = $entry.source
            installLocation = $installLocation
            lastUpdated     = (Get-Date).ToString("o")
        }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localMktFile) | Out-Null
    $localMarketplaces | ConvertTo-Json -Depth 10 | Set-Content $localMktFile
}

# --- Skills: clone any skill repos that aren't already present ---
$skillManifest = Join-Path $SrcDir "skills/manifest.json"
if (Test-Path $skillManifest) {
    $skills = (Get-Content $skillManifest -Raw | ConvertFrom-Json).skills
    foreach ($skill in $skills) {
        $target = Join-Path $ClaudeDir "skills/$($skill.name)"
        if (-not (Test-Path (Join-Path $target ".git"))) {
            Write-Host "Cloning skill '$($skill.name)' from $($skill.url)"
            git clone --quiet $skill.url $target
        } else {
            git -C $target pull --quiet
        }
    }
}

Write-Host "Done."

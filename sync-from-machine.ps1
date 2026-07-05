#!/usr/bin/env pwsh
# Pulls the current machine's ~/.claude config into this repo so it can be
# committed and installed elsewhere with install.ps1.

$ErrorActionPreference = "Stop"

$RepoDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$DestDir   = Join-Path $RepoDir "claude"
$ClaudeDir = Join-Path $HOME ".claude"

function Copy-IfExists($relPath, $isDir) {
    $src = Join-Path $ClaudeDir $relPath
    if (-not (Test-Path $src)) { return }
    $dest = Join-Path $DestDir $relPath
    if ($isDir) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $src "*") -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -Path $src -Destination $dest -Force
    }
}

Write-Host "Exporting Claude config from $ClaudeDir into $DestDir"

Copy-IfExists "settings.json" $false
Copy-IfExists "CLAUDE.md" $false
Copy-IfExists "commands" $true
Copy-IfExists "agents" $true
Copy-IfExists "output-styles" $true

# --- Marketplaces: strip machine-specific paths/timestamps before saving ---
$localMktFile = Join-Path $ClaudeDir "plugins/known_marketplaces.json"
if (Test-Path $localMktFile) {
    $marketplaces = Get-Content $localMktFile -Raw | ConvertFrom-Json
    $clean = [ordered]@{}
    foreach ($name in $marketplaces.PSObject.Properties.Name) {
        $clean[$name] = @{ source = $marketplaces.$name.source }
    }
    $destMktFile = Join-Path $DestDir "plugins/known_marketplaces.json"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destMktFile) | Out-Null
    $clean | ConvertTo-Json -Depth 10 | Set-Content $destMktFile
}

# --- Skills: record git remotes of any skill folders that are their own git repos ---
$skillsDir = Join-Path $ClaudeDir "skills"
if (Test-Path $skillsDir) {
    $skills = @()
    Get-ChildItem $skillsDir -Directory | ForEach-Object {
        $gitDir = Join-Path $_.FullName ".git"
        if (Test-Path $gitDir) {
            $url = git -C $_.FullName remote get-url origin 2>$null
            if ($url) {
                $skills += @{ name = $_.Name; source = "git"; url = $url }
            }
        }
    }
    $destManifest = Join-Path $DestDir "skills/manifest.json"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destManifest) | Out-Null
    @{ skills = $skills } | ConvertTo-Json -Depth 10 | Set-Content $destManifest
}

Write-Host "Done. Review the diff, then commit and push."

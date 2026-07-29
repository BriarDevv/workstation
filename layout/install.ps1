<#
.SYNOPSIS
    Creates the folder tree and locks down its root.

.DESCRIPTION
    The tree is declared in LAYOUT.md and nowhere else - this script only reads it, so
    moving a folder is a one-line edit there rather than a hunt through scripts.

    Runs FIRST in the install order: apps/install.ps1 unpacks Node inside the tree and
    dev/install.ps1 clones into it, so the tree has to exist before either.

    Idempotent. Exit code 0 means everything asked for is in place; 1 means it isn't, and
    the summary names what.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh layout\install.ps1
    pwsh layout\install.ps1 -WhatIfOnly
#>
[CmdletBinding()]
param([switch]$WhatIfOnly)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$failed = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------- the tree
Write-Step 'Tree'

$wanted = [System.Collections.Generic.List[string]]::new()
foreach ($row in Get-LayoutRows | Where-Object { $_.Created }) { $wanted.Add($row.Path) }

# One folder per list in dev\repos\, derived rather than declared. Adding a list is adding a
# file - the same contract dev/install.ps1 already gives the clones - so a new category
# can't exist in one of the two places and not the other.
$reposRoot = Get-LayoutPath 'repos'
$listDir = Join-Path $PSScriptRoot '..\dev\repos'
foreach ($f in @(Get-ChildItem $listDir -Filter *.md -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'README.md' } | Sort-Object Name)) {
    $wanted.Add((Join-Path $reposRoot $f.BaseName))
}

foreach ($path in $wanted) {
    if (Test-Path $path) { Write-Skip $path; continue }
    if ($script:DryRun) { Write-Would "create $path"; continue }
    try {
        # -Force here creates missing parents. It is safe because the target is a directory;
        # the truncation hazard in CLAUDE.md is about -Force on a FILE.
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Ok $path
    }
    catch {
        Write-Fail "$path - $($_.Exception.Message)"
        $failed.Add($path)
    }
}

# ---------------------------------------------------------------- the map
# A copy of LAYOUT.md at the root of the tree, for whoever opens that folder without this
# repo in front of them - which on this machine is a real scenario, since the tree outlives
# any particular checkout of the repo that built it.
#
# The repo's copy stays the source: Get-LayoutRows reads that one, never this one. This is
# documentation left where it will be found, not a second input.
Write-Step 'Map'
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'LAYOUT.md') (Join-Path (Get-LayoutPath 'root') 'LAYOUT.md'))) {
    $failed.Add('LAYOUT.md at the root')
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
Write-Host "  $($wanted.Count) folders declared" -ForegroundColor DarkGray

if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) didn't complete:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host '  Re-running is safe and skips everything that already worked.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host ''

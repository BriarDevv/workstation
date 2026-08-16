<#
.SYNOPSIS
    Applies the dual Claude Code account system: skill, links, ambient default,
    and the HUD account mapping.

.DESCRIPTION
    Junctions this folder's claude-dual-account-setup skill into ~/.claude/skills,
    then delegates the live state to the skill's repair.ps1: the User-scope
    CLAUDE_CONFIG_DIR ambient default (everything that is not the `claude`
    command bills pegasuz), the plugins/skills junctions, the settings.json/
    CLAUDE.md hardlinks, and the $PROFILE marked block.

    Also materializes ~/.config/hud/accounts.json for the HUD account chip from
    secrets/hud-accounts.json (never committed: it holds account emails). Color
    values naming a slot of the active terminal scheme (e.g. "brightCyan") are
    resolved to that scheme's hex at install time, so re-running after a theme
    change keeps the chip matching the terminal.

    Idempotent. Exit code 0 means everything asked for is in place; 1 means it
    isn't, and the summary names what.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh accounts\install.ps1
    pwsh accounts\install.ps1 -WhatIfOnly
#>
[CmdletBinding()]
param(
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$failed = [System.Collections.Generic.List[string]]::new()
$claudeHome = Join-Path $HOME '.claude'

# ---------------------------------------------------------------- skill junction
# claude/install.ps1 links skills from the Agent-Engineering and skills repos;
# this one lives here because it IS workstation state. Same junction idiom.
Write-Step 'Dual-account skill (junction)'
$skillSrc = Join-Path $PSScriptRoot 'skills\claude-dual-account-setup'
$skillLink = Join-Path $claudeHome 'skills\claude-dual-account-setup'
$skillsDir = Split-Path $skillLink
if (-not (Test-Path $skillsDir) -and -not $script:DryRun) {
    New-Item -ItemType Directory $skillsDir -Force | Out-Null
}
$existing = Get-Item $skillLink -ErrorAction SilentlyContinue
if ($existing -and $existing.LinkType -eq 'Junction' -and $existing.LinkTarget -eq $skillSrc) {
    Write-Ok 'claude-dual-account-setup junction already in place'
}
elseif ($script:DryRun) {
    Write-Would "link claude-dual-account-setup -> $skillSrc"
}
else {
    if ($existing) {
        Backup-ExistingFile $skillLink | Out-Null
        Remove-Item -LiteralPath $skillLink -Recurse -Force
    }
    New-Item -ItemType Junction -Path $skillLink -Target $skillSrc | Out-Null
    Write-Ok 'claude-dual-account-setup junction created'
}

# ---------------------------------------------------------------- live state
# repair.ps1 is the single owner of env var + links + $PROFILE block, so live
# repairs and restores can never disagree about what healthy means.
Write-Step 'Ambient default, links, $PROFILE block (repair.ps1)'
$repair = Join-Path $skillSrc 'repair.ps1'
if (-not (Test-Path $repair)) {
    Write-Fail "repair.ps1 not found at $repair"
    $failed.Add('repair.ps1')
}
else {
    if ($script:DryRun) { & $repair -WhatIf } else { & $repair -Force }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Fail 'repair.ps1 reported a failure'
        $failed.Add('repair.ps1')
    }
}

# ---------------------------------------------------------------- HUD accounts
Write-Step 'HUD account mapping'
$secretsMap = Join-Path $PSScriptRoot '..\secrets\hud-accounts.json'
$hudMapDst = Join-Path $HOME '.config\hud\accounts.json'
if (-not (Test-Path $secretsMap)) {
    Write-Skip 'secrets\hud-accounts.json is missing - HUD chip falls back to plain emails'
    Write-Host '         Copy accounts\hud-accounts.example.json there and fill it in.' -ForegroundColor DarkGray
}
else {
    try {
        $map = Get-Content $secretsMap -Raw | ConvertFrom-Json -AsHashtable

        # Resolve scheme-slot color names against the active terminal scheme:
        # style.json points at the active style, the style names its scheme.
        # Literal #RRGGBB values and classic ANSI names pass through untouched.
        $scheme = $null
        try {
            $active = (Get-Content (Join-Path $PSScriptRoot '..\terminal\style.json') -Raw |
                ConvertFrom-Json -AsHashtable).active
            $styleDef = Get-Content (Join-Path $PSScriptRoot "..\terminal\styles\$active.json") -Raw |
                ConvertFrom-Json -AsHashtable
            $schemeFile = Join-Path $PSScriptRoot '..\terminal\schemes' `
                ("$($styleDef.terminal.colorScheme.ToLower() -replace ' ', '-').json")
            if (Test-Path $schemeFile) {
                $scheme = Get-Content $schemeFile -Raw | ConvertFrom-Json -AsHashtable
            }
        }
        catch { $scheme = $null }
        if (-not $scheme) {
            Write-Warn2 'active terminal scheme not resolved; color names are passed through as-is'
        }

        foreach ($email in @($map.accounts.Keys)) {
            $color = [string]$map.accounts[$email].color
            if ($scheme -and $scheme.ContainsKey($color)) {
                $map.accounts[$email].color = $scheme[$color]
            }
        }

        $json = ($map | ConvertTo-Json -Depth 10) + "`n"
        if (-not (Install-ConfigText -Destination $hudMapDst -Text $json -Label 'hud accounts.json')) {
            $failed.Add('hud accounts.json')
        }
    }
    catch {
        Write-Fail "secrets\hud-accounts.json could not be applied: $($_.Exception.Message)"
        $failed.Add('hud accounts.json')
    }
}

# ---------------------------------------------------------------- manual
Write-Step 'Left to do by hand'
foreach ($row in Get-RowsFromReadme (Join-Path $PSScriptRoot 'README.md') @('What stays manual')) {
    Write-Host "         $row" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) didn't complete:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host ''
if ($script:DryRun) { Write-Host '  Dry run complete; no account files changed.' -ForegroundColor DarkGray }
else { Write-Host '  Restart Orca and any open consoles so they inherit the ambient default.' -ForegroundColor DarkGray }
Write-Host ''
exit 0

#Requires -Version 7.0
<#
.SYNOPSIS
    Verifies and repairs the dual-account setup: links, $PROFILE block, and the
    ambient-default environment variable.
.DESCRIPTION
    Treats ~/.claude as canonical. Recreates the plugins/skills junctions and the
    settings.json/CLAUDE.md hardlinks whenever they are missing or broken, restores
    the `claude`/`pegasuz` functions in $PROFILE from profile-functions.ps1 when
    they are missing, and sets the User-scope CLAUDE_CONFIG_DIR to
    ~/.claude-pegasuz so everything that is not the `claude` command (Orca, its
    agents, bare claude.exe) bills the pegasuz account, never the personal one.
    Idempotent: a healthy setup is left untouched.
.PARAMETER Force
    Also overwrite a profile block that exists but has drifted from
    profile-functions.ps1. Without it, drift is reported and left alone.
.PARAMETER WhatIf
    Report what would change without touching anything.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force
)

$source = Join-Path $env:USERPROFILE '.claude'
$config = Join-Path $env:USERPROFILE '.claude-pegasuz'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Source config dir not found: $source"
}
if (-not (Test-Path -LiteralPath $config)) {
    if ($PSCmdlet.ShouldProcess($config, 'Create config dir')) {
        New-Item -ItemType Directory -Path $config -Force | Out-Null
    }
}

$repaired = 0

# The ambient default. User scope so every process that does not go through the
# `claude` function — Orca and whatever it spawns, above all — resolves its
# config (and credentials) to the pegasuz dir. Orca's own path resolver honors
# this variable, so even its credential swapping stays inside that dir.
$expected = $config
$current = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR', 'User')
if ($current -eq $expected) {
    Write-Host "OK       CLAUDE_CONFIG_DIR (User) -> $expected" -ForegroundColor DarkGray
} elseif ($PSCmdlet.ShouldProcess('CLAUDE_CONFIG_DIR (User)', "Set to $expected")) {
    [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $expected, 'User')
    Write-Host "REPAIRED CLAUDE_CONFIG_DIR (User) -> $expected" -ForegroundColor Yellow
    Write-Host '         running processes keep the old value; restart Orca to pick it up' -ForegroundColor DarkGray
    $repaired++
}

# Directories: junctions. A junction reports LinkType 'Junction' and a Target.
foreach ($name in 'plugins', 'skills') {
    $from = Join-Path $source $name
    $link = Join-Path $config $name
    if (-not (Test-Path -LiteralPath $from)) {
        Write-Warning "$name`: missing in $source, skipped"
        continue
    }

    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($item.LinkType -eq 'Junction' -and $item.Target -eq $from) {
        Write-Host "OK       $name (junction)" -ForegroundColor DarkGray
        continue
    }

    if ($PSCmdlet.ShouldProcess($link, "Re-create junction -> $from")) {
        if ($item) { Remove-Item -LiteralPath $link -Recurse -Force }
        New-Item -ItemType Junction -Path $link -Value $from | Out-Null
        Write-Host "REPAIRED $name (junction)" -ForegroundColor Yellow
        $repaired++
    }
}

# Files: hardlinks. Replace-on-write breaks these, leaving LinkType empty.
foreach ($name in 'settings.json', 'CLAUDE.md') {
    $from = Join-Path $source $name
    $link = Join-Path $config $name
    if (-not (Test-Path -LiteralPath $from)) {
        Write-Warning "$name`: missing in $source, skipped"
        continue
    }

    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($item.LinkType -eq 'HardLink') {
        Write-Host "OK       $name (hardlink)" -ForegroundColor DarkGray
        continue
    }

    if ($PSCmdlet.ShouldProcess($link, "Re-link to $from (contents of $source win)")) {
        if ($item) { Remove-Item -LiteralPath $link -Force }
        New-Item -ItemType HardLink -Path $link -Value $from | Out-Null
        Write-Host "REPAIRED $name (hardlink)" -ForegroundColor Yellow
        $repaired++
    }
}

# The $PROFILE functions. No link protects these: the file is plain, outside
# both config dirs. They live in a marked block so everything else in the
# profile (fastfetch, unrelated aliases) is never touched.
$beginMark = '# >>> claude-dual-account-setup >>>'
$endMark   = '# <<< claude-dual-account-setup <<<'
$canonical = Join-Path $PSScriptRoot 'profile-functions.ps1'

# Always the ConsoleHost profile, whichever host happens to run this script.
$profilePath = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Microsoft.PowerShell_profile.ps1'

function Normalize([string]$s) { ($s -replace "`r`n", "`n").Trim() }

if (-not (Test-Path -LiteralPath $canonical)) {
    Write-Warning "profile-functions.ps1: missing, `$PROFILE check skipped"
} else {
    $match = [regex]::Match(
        (Get-Content -LiteralPath $canonical -Raw),
        '(?ms)^#region profile-block\r?\n(.*?)^#endregion')

    if (-not $match.Success) {
        Write-Warning "profile-functions.ps1: no #region profile-block, `$PROFILE check skipped"
    } else {
        $block = "$beginMark`n" + $match.Groups[1].Value.Trim() + "`n$endMark"
        $existing = if (Test-Path -LiteralPath $profilePath) {
            Get-Content -LiteralPath $profilePath -Raw
        } else { '' }

        $blockPattern = '(?ms)' + [regex]::Escape($beginMark) + '.*?' + [regex]::Escape($endMark)
        $found = [regex]::Match($existing, $blockPattern)

        if ($found.Success -and (Normalize $found.Value) -eq (Normalize $block)) {
            Write-Host "OK       `$PROFILE block" -ForegroundColor DarkGray
        } elseif ($found.Success -and -not $Force) {
            Write-Warning "`$PROFILE block differs from profile-functions.ps1. Re-run with -Force to overwrite, or copy your version back into the skill."
        } elseif ($PSCmdlet.ShouldProcess($profilePath, $(if ($found.Success) { 'Overwrite drifted block' } else { 'Insert missing block' }))) {
            if ($found.Success) {
                $updated = [regex]::Replace($existing, $blockPattern, { $block })
            } else {
                # Prepend: functions should be defined before anything that may use them.
                $updated = if ($existing.Trim()) { "$block`n`n" + $existing.TrimStart() } else { "$block`n" }
            }
            Set-Content -LiteralPath $profilePath -Value $updated -Encoding utf8NoBOM -NoNewline
            Write-Host "REPAIRED `$PROFILE block" -ForegroundColor Yellow
            Write-Host "         open a new console or run: . `$PROFILE" -ForegroundColor DarkGray
            $repaired++

            # A loose duplicate outside the block would win, since the last
            # definition parsed is the one that survives.
            $outside = [regex]::Replace($updated, $blockPattern, '')
            if ($outside -match '(?m)^\s*function\s+(claude|pegasuz)\b') {
                Write-Warning "`$PROFILE also defines $($Matches[1]) outside the block; remove it or it overrides the managed one."
            }
        }
    }
}

if ($WhatIfPreference) {
    Write-Host "`nDry run: nothing was changed." -ForegroundColor Cyan
} elseif ($repaired -eq 0) {
    Write-Host "`nAll links healthy." -ForegroundColor Green
} else {
    Write-Host "`n$repaired item(s) repaired from $source." -ForegroundColor Green
}

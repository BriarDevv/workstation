<#
.SYNOPSIS
    Applies this folder's Claude Code configuration to ~/.claude.

.DESCRIPTION
    Four steps: CLAUDE.md, the rules, settings.json, and - only with -Secrets - the MCP
    servers.

    settings.json is MERGED rather than copied. oh-my-claudecode owns "hooks" and
    "statusLine" in the live file and this repo deliberately carries neither, so a straight
    copy would delete them and take the HUD and every hook with it. Keys present here win;
    keys only present live are left alone.

    Idempotent. Exit code 0 means everything asked for is in place; 1 means it isn't, and
    the summary names what.

.PARAMETER Secrets
    Also resolve mcp.template.json into ~/.claude/mcp-configs/mcp-servers.json, reading the
    values from secrets/.env. Off by default: without it this script never touches a file
    that holds API keys.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh claude\install.ps1
    pwsh claude\install.ps1 -WhatIfOnly
    pwsh claude\install.ps1 -Secrets
#>
[CmdletBinding()]
param(
    [switch]$Secrets,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$failed = [System.Collections.Generic.List[string]]::new()
$claudeHome = Join-Path $HOME '.claude'

# Write a file, backing up whatever was there first. Install-ConfigFile copies a file from
# the repo; this one takes text that was generated, which is why it exists separately.
function Write-ConfigText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Label
    )
    if ((Test-Path $Path) -and ((Get-Content $Path -Raw) -eq $Text)) {
        Write-Skip "$Label already identical"
        return $true
    }
    if ($script:DryRun) { Write-Would "write $Path"; return $true }

    try {
        if (Test-Path $Path) {
            $bak = Join-Path $script:BackupDir (Split-Path $Path -Leaf)
            New-Item -ItemType Directory -Force -Path (Split-Path $bak -Parent) | Out-Null
            Copy-Item $Path $bak -Force
            Write-Warn2 "backed up original -> $bak"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
        # -NoNewline: the text already ends how it should, and Set-Content would otherwise
        # append a newline every run and break the idempotency check above.
        Set-Content -Path $Path -Value $Text -NoNewline -Encoding utf8
        Write-Ok $Label
        return $true
    }
    catch { Write-Fail "$Label - $($_.Exception.Message)"; return $false }
}

# Sort every object's keys, at every depth, so ConvertTo-Json emits the same text for the
# same content.
#
# Without this the script is not idempotent and the bug is invisible: a PowerShell hashtable
# has no defined key order, so serialising identical settings twice gives two different
# strings, the "already identical" check never matches, and every run rewrites the file and
# drops another copy into the backup folder. Arrays keep their order - that is data, not
# layout.
function ConvertTo-Sorted {
    param($Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        foreach ($k in @($Value.Keys) | Sort-Object) { $out[$k] = ConvertTo-Sorted $Value[$k] }
        return $out
    }
    if ($Value -is [object[]] -or $Value -is [System.Collections.IList]) {
        return @($Value | ForEach-Object { ConvertTo-Sorted $_ })
    }
    return $Value
}

# Every skill in ~/.claude/skills gets hidden from the model; plugin skills don't.
#
# Read off the disk rather than from a list in the repo, and that's the whole point. A list
# would be 176 names of things you don't want - the contamination the root CLAUDE.md
# forbids - and it would go stale the first time anything installs a skill. This can't:
# a new plugin's skills are protected automatically, and anything new in the folder is
# quiet by default. skills.md explains it.
function Get-SkillOverrides {
    $overrides = [ordered]@{}
    $skillsDir = Join-Path $claudeHome 'skills'
    if (-not (Test-Path $skillsDir)) { return $overrides }

    # Names a plugin also provides. skillOverrides is keyed by name, so disabling the folder
    # copy of a shared name risks taking the plugin's copy with it - and the plugin's is the
    # one being used. Real case, not hypothetical: frontend-design exists in both places.
    $fromPlugins = @()
    $cache = Join-Path $claudeHome 'plugins\cache'
    if (Test-Path $cache) {
        $fromPlugins = @(Get-ChildItem $cache -Directory -Recurse -Depth 4 -Filter skills -ErrorAction SilentlyContinue |
                ForEach-Object { (Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue).Name }) |
            Select-Object -Unique
    }

    foreach ($s in Get-ChildItem $skillsDir -Directory | Sort-Object Name) {
        if ($fromPlugins -contains $s.Name) { continue }
        # Not 'off': both cost the model nothing, but this keeps /skill-name working, so
        # turning one back on never means editing a file.
        $overrides[$s.Name] = 'user-invocable-only'
    }
    return $overrides
}

# ---------------------------------------------------------------- CLAUDE.md
Write-Step 'CLAUDE.md'
# The whole file sits between OMC:START / OMC:END markers, which the repo copy carries too -
# so this is a plain overwrite, and re-running it is how you recover after omc-setup or an
# OMC update stomps your edits. See README.md.
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'CLAUDE.md') (Join-Path $claudeHome 'CLAUDE.md'))) {
    $failed.Add('CLAUDE.md')
}

# ---------------------------------------------------------------- rules
Write-Step 'Rules'
$rulesSrc = Join-Path $PSScriptRoot 'rules\common'
$rulesDst = Join-Path $claudeHome 'rules\common'
foreach ($f in @(Get-ChildItem $rulesSrc -Filter *.md -ErrorAction SilentlyContinue | Sort-Object Name)) {
    if (-not (Install-ConfigFile $f.FullName (Join-Path $rulesDst $f.Name))) {
        $failed.Add("rule: $($f.Name)")
    }
}

# ---------------------------------------------------------------- settings.json
Write-Step 'settings.json'
$settingsPath = Join-Path $claudeHome 'settings.json'

$repoSettings = Get-Content (Join-Path $PSScriptRoot 'settings.json') -Raw | ConvertFrom-Json -AsHashtable
# _notes documents the repo's copy for a human reading it. It is not configuration and does
# not belong in the live file.
$repoSettings.Remove('_notes')

$liveSettings = if (Test-Path $settingsPath) {
    Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
}
else { @{} }

$merged = @{}
foreach ($k in $liveSettings.Keys) { $merged[$k] = $liveSettings[$k] }
foreach ($k in $repoSettings.Keys) { $merged[$k] = $repoSettings[$k] }

$overrides = Get-SkillOverrides
if ($overrides.Count) { $merged['skillOverrides'] = $overrides }

$kept = @($liveSettings.Keys | Where-Object { -not $repoSettings.ContainsKey($_) })
if ($kept.Count) { Write-Host "  keeping $($kept.Count) key(s) this repo doesn't manage: $($kept -join ', ')" -ForegroundColor DarkGray }
Write-Host "  $($overrides.Count) skill(s) hidden from the model, $(@(Get-ChildItem (Join-Path $claudeHome 'skills') -Directory -EA SilentlyContinue).Count - $overrides.Count) left to their plugin" -ForegroundColor DarkGray

$json = ((ConvertTo-Sorted $merged) | ConvertTo-Json -Depth 100) + "`n"
if (-not (Write-ConfigText -Path $settingsPath -Text $json -Label 'settings.json')) {
    $failed.Add('settings.json')
}

# ---------------------------------------------------------------- MCP
Write-Step 'MCP servers'
if (-not $Secrets) {
    Write-Skip 'mcp-servers.json skipped - pass -Secrets to write it'
    Write-Host '         It holds API keys, so it is never written by accident.' -ForegroundColor DarkGray
}
else {
    $envFile = Join-Path $PSScriptRoot '..\secrets\.env'
    if (-not (Test-Path $envFile)) {
        Write-Warn2 'secrets\.env is missing. Copy secrets\.env.example and fill it in.'
        $failed.Add('secrets\.env')
    }
    else {
        $vars = @{}
        foreach ($line in Get-Content $envFile) {
            if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
            $i = $line.IndexOf('=')
            $vars[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim().Trim('"')
        }

        # layout\LAYOUT.md owns the path, the same as every .ps1 here. Backslashes are
        # doubled because the value lands inside JSON, where a lone one starts an escape.
        $vars['LAYOUT_REPOS'] = (Get-LayoutPath 'repos').Replace('\', '\\')

        # .Replace and not -replace: an API key can contain $ or \, which the regex operator
        # would read as a backreference or an escape and silently corrupt.
        $text = Get-Content (Join-Path $PSScriptRoot 'mcp.template.json') -Raw
        foreach ($k in $vars.Keys) { $text = $text.Replace('${' + $k + '}', $vars[$k]) }

        $missing = [regex]::Matches($text, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}') |
            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        if ($missing) {
            Write-Warn2 "$($missing.Count) placeholder(s) with no value in secrets\.env: $($missing -join ', ')"
            Write-Host '         Those servers will start and fail to authenticate.' -ForegroundColor DarkGray
        }

        $mcpPath = Join-Path $claudeHome 'mcp-configs\mcp-servers.json'
        if (-not (Write-ConfigText -Path $mcpPath -Text $text -Label 'mcp-servers.json')) {
            $failed.Add('mcp-servers.json')
        }
    }
}

# ---------------------------------------------------------------- manual
Write-Step 'Left to do by hand'
foreach ($row in Get-RowsFromReadme (Join-Path $PSScriptRoot 'README.md') @('What stays manual')) {
    Write-Host "         $row" -ForegroundColor DarkGray
}
# ~/.claude.json holds the OAuth token, so it is gitignored and nothing here writes it. Any
# MCP server living in there is invisible to this repo and would survive a format only by
# being typed back in.
$userJson = Join-Path $HOME '.claude.json'
if (Test-Path $userJson) {
    $u = Get-Content $userJson -Raw | ConvertFrom-Json -AsHashtable
    $stray = @($u.mcpServers.Keys | Where-Object { $_ })
    if ($stray.Count) {
        Write-Host ''
        Write-Warn2 "$($stray.Count) MCP server(s) live in ~\.claude.json, which this repo cannot manage:"
        Write-Host "         $($stray -join ', ')" -ForegroundColor DarkGray
        Write-Host '         That file is gitignored (OAuth token). Move anything worth keeping into' -ForegroundColor DarkGray
        Write-Host '         mcp.template.json, or it is gone after a format.' -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
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
Write-Host '  Restart Claude Code for settings.json to take effect.' -ForegroundColor DarkGray
Write-Host ''

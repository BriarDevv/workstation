<#
.SYNOPSIS
    Reports where this repo and this machine disagree. Writes nothing.

.DESCRIPTION
    The repo's tables are a WISH LIST - what the machine should have after a restore. The
    machine is a PHOTO - what happens to be on it today, including everything installed for
    one afternoon and never removed. Those are different documents and this script never
    turns one into the other.

    So it reports, and you decide. Every difference has two honest answers - put it in the
    table, or take it off the machine - and only you know which.

    Read-only by design. Exit code is always 0: drift is information, not failure.

.EXAMPLE
    pwsh .\snapshot.ps1
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_lib.ps1"
Assert-PowerShell7

$readme = Join-Path $PSScriptRoot 'apps\README.md'

# ---------------------------------------------------------------- npm globals
Write-Step 'npm globals'
if (-not (Test-Cmd npm)) {
    Write-Warn2 'npm is missing - run apps\install.ps1 first'
}
else {
    $wanted = @(Get-IdsFromReadme $readme @('npm globals'))

    # npm is the package manager itself, always present, and never a row in anyone's table.
    $installed = @()
    $raw = & npm ls -g --depth=0 --json 2>$null | Out-String
    if ($raw.Trim()) {
        $deps = ($raw | ConvertFrom-Json).dependencies
        if ($deps) { $installed = @($deps.PSObject.Properties.Name | Where-Object { $_ -ne 'npm' }) }
    }

    $missing = @($wanted | Where-Object { $_ -notin $installed })
    $extra = @($installed | Where-Object { $_ -notin $wanted })

    Write-Host "  $($wanted.Count) wanted, $($installed.Count) installed" -ForegroundColor DarkGray

    if ($missing) {
        Write-Host ''
        Write-Warn2 "$($missing.Count) in the table but NOT installed:"
        foreach ($p in $missing) { Write-Host "         $p" -ForegroundColor Red }
        Write-Host '         Fix by installing them:  npm i -g <name>' -ForegroundColor DarkGray
    }

    if ($extra) {
        Write-Host ''
        Write-Warn2 "$($extra.Count) installed but NOT in the table:"
        foreach ($p in $extra) { Write-Host "         $p" -ForegroundColor Yellow }
        Write-Host '         The table is the complete list, so each of these is either a missing row' -ForegroundColor DarkGray
        Write-Host '         or something to uninstall. Nothing here guesses which.' -ForegroundColor DarkGray
    }

    if (-not $missing -and -not $extra) { Write-Ok 'the table and the machine agree' }
}

# ---------------------------------------------------------------- winget
Write-Step 'winget packages'
if (-not (Test-Cmd winget)) {
    Write-Warn2 'winget is missing - see windows\README.md'
}
else {
    $ids = @(Get-IdsFromReadme $readme @('Essentials', 'Terminal', 'Desktop / utilities', 'Games', 'Runtimes', 'Optional'))
    $gone = @($ids | Where-Object { -not (Test-WingetInstalled $_) })

    Write-Host "  $($ids.Count) in the tables, $($ids.Count - $gone.Count) installed" -ForegroundColor DarkGray
    if ($gone) {
        Write-Host ''
        Write-Warn2 "$($gone.Count) in the tables that winget can't see:"
        foreach ($p in $gone) { Write-Host "         $p" -ForegroundColor Red }
        Write-Host '         Usually means not installed - fix with:  pwsh apps\install.ps1' -ForegroundColor DarkGray
        # Not stated as fact: winget only recognises what it installed. A program put there
        # by its own .exe is invisible to `winget list` even while it sits in the Start menu,
        # so "missing" here can mean "installed by hand". apps\README.md has the section.
        Write-Host '         But winget only sees what it installed - check the Start menu before' -ForegroundColor DarkGray
        Write-Host '         believing it. apps\README.md, "winget won''t always see a program".' -ForegroundColor DarkGray
    }
    else { Write-Ok 'everything in the tables is on the machine' }

    # The other direction is deliberately not reported. `winget list` returns several hundred
    # packages, nearly all of them Windows' own, and reading that as "rows you forgot to add"
    # is how a repo grows a list of software its owner never chose. Root README.md says the
    # same thing about `winget export`.
}

# ---------------------------------------------------------------- MCP
Write-Step 'MCP servers'
$live = Join-Path $HOME '.claude\mcp-configs\mcp-servers.json'
$tpl = Join-Path $PSScriptRoot 'claude\mcp.template.json'
if (-not (Test-Path $live)) {
    Write-Skip 'no mcp-servers.json on this machine yet'
}
else {
    $inTpl = @((Get-Content $tpl -Raw | ConvertFrom-Json -AsHashtable).mcpServers.Keys)
    $inLive = @((Get-Content $live -Raw | ConvertFrom-Json -AsHashtable).mcpServers.Keys)

    # A plugin's servers are absent from the template ON PURPOSE - listing them in both
    # places starts the same server twice. Without this the report flags exactly the
    # duplicates we removed and tells you to put them back.
    # ENABLED plugins only. The cache keeps plugins that were turned off - github is cached
    # and disabled, so its server runs from the template alone and calling that a duplicate
    # would send you to delete the only copy.
    $enabled = @()
    $settings = Join-Path $HOME '.claude\settings.json'
    if (Test-Path $settings) {
        $sj = Get-Content $settings -Raw | ConvertFrom-Json -AsHashtable
        if ($sj.enabledPlugins) {
            $enabled = @($sj.enabledPlugins.Keys | Where-Object { $sj.enabledPlugins[$_] })
        }
    }

    $fromPlugins = @()
    $cache = Join-Path $HOME '.claude\plugins\cache'
    if (Test-Path $cache) {
        # Two shapes in the wild: a plugin's .mcp.json puts the server names at the TOP
        # LEVEL, while the user-scope file wraps them in "mcpServers". Reading only the
        # wrapped one found the files, parsed them, and returned nothing - a blind spot that
        # looks identical to "no plugins installed".
        $fromPlugins = @(Get-ChildItem $cache -Recurse -Depth 3 -Filter '.mcp.json' -ErrorAction SilentlyContinue |
                ForEach-Object {
                    # cache\<marketplace>\<plugin>\<version>\.mcp.json - which is where the
                    # plugin@marketplace key in settings.json comes from.
                    $ver = $_.Directory
                    if ("$($ver.Parent.Name)@$($ver.Parent.Parent.Name)" -notin $enabled) { return }
                    try {
                        $j = Get-Content $_.FullName -Raw | ConvertFrom-Json -AsHashtable
                        if ($j.mcpServers) { $j.mcpServers.Keys } else { $j.Keys }
                    }
                    catch { }
                }) | Select-Object -Unique
    }

    $strayLive = @($inLive | Where-Object { $_ -notin $inTpl -and $_ -notin $fromPlugins })
    $covered = @($inLive | Where-Object { $_ -in $fromPlugins })

    Write-Host "  $($inTpl.Count) in the template, $($inLive.Count) live, $($covered.Count) of those also served by a plugin" -ForegroundColor DarkGray
    if ($covered) {
        Write-Warn2 "$($covered.Count) duplicate(s) - configured loose AND provided by a plugin:"
        foreach ($s in $covered) { Write-Host "         $s" -ForegroundColor Yellow }
        Write-Host '         Both start. Remove the loose one - see claude\plugins.md.' -ForegroundColor DarkGray
    }
    if ($strayLive) {
        Write-Host ''
        Write-Warn2 "$($strayLive.Count) live but NOT in the template:"
        foreach ($s in $strayLive) { Write-Host "         $s" -ForegroundColor Yellow }
        # Same neutral wording as the npm section, and for the same reason: "you'll lose
        # these" is a judgment, and for anything deliberately dropped losing it IS the plan.
        Write-Host '         The template is the complete list, so each of these is either a missing' -ForegroundColor DarkGray
        Write-Host '         row or something to remove. Nothing here guesses which.' -ForegroundColor DarkGray
    }
    if (-not $strayLive -and -not $covered) { Write-Ok 'the template covers everything live' }
}

# ---------------------------------------------------------------- tree
Write-Step 'Layout'
$rows = @(Get-LayoutRows | Where-Object { $_.Created })
$absent = @($rows | Where-Object { -not (Test-Path $_.Path) })
if ($absent) {
    Write-Warn2 "$($absent.Count) declared folder(s) missing - run layout\install.ps1:"
    foreach ($r in $absent) { Write-Host "         $($r.Path)" -ForegroundColor Red }
}
else { Write-Ok "all $($rows.Count) declared folders exist" }

# A folder in the tree with no row is the other half of the audit LAYOUT.md promises: the
# table and `dir` have to agree, and this is the only thing that checks the direction a
# human would never notice.
$root = Get-LayoutPath 'root'
if (Test-Path $root) {
    $declared = @(Get-LayoutRows | ForEach-Object { $_.Path })
    $undeclared = @(Get-ChildItem $root -Directory | Where-Object { $_.FullName -notin $declared })
    if ($undeclared) {
        Write-Host ''
        Write-Warn2 "$($undeclared.Count) folder(s) under the root with no row in LAYOUT.md:"
        foreach ($d in $undeclared) { Write-Host "         $($d.Name)" -ForegroundColor Yellow }
        Write-Host '         Each one earns a row or gets deleted. LAYOUT.md says which.' -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host '  Nothing was written. Every line above is a decision for you, not a bug.' -ForegroundColor DarkGray
Write-Host ''

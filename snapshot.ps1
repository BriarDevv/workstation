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
    $storeIds = @(Get-IdsFromReadme $readme @('Microsoft Store'))
    $allIds = @($ids + $storeIds)
    $gone = @($ids | Where-Object { -not (Test-WingetInstalled $_) })
    $goneStore = @($storeIds | Where-Object { -not (Test-WingetInstalled $_) })

    Write-Host "  $($allIds.Count) in the tables, $($allIds.Count - $gone.Count - $goneStore.Count) installed" -ForegroundColor DarkGray
    if ($gone -or $goneStore) {
        Write-Host ''
        Write-Warn2 "$($gone.Count + $goneStore.Count) in the tables that winget can't see:"
        foreach ($p in @($gone + $goneStore)) { Write-Host "         $p" -ForegroundColor Red }
        Write-Host '         Usually means not installed - fix with:  pwsh apps\install.ps1' -ForegroundColor DarkGray
        # Not stated as fact: package correlation can miss software installed by its own
        # vendor installer even while it is present in the Start menu.
        Write-Host '         Winget can miss software it did not install - check the Start menu before' -ForegroundColor DarkGray
        Write-Host '         treating the report as proof that the application is absent.' -ForegroundColor DarkGray
    }
    else { Write-Ok 'everything in the tables is on the machine' }

    # The other direction is deliberately not reported. `winget list` returns several hundred
    # packages, nearly all of them Windows' own, and reading that as "rows you forgot to add"
    # is how a repo grows a list of software its owner never chose. Root README.md says the
    # same thing about `winget export`.
}

# ---------------------------------------------------------------- Claude plugins and MCP
Write-Step 'Claude plugins and MCP servers'
$manifest = Get-Content (Join-Path $PSScriptRoot 'claude\mcp.template.json') -Raw |
    ConvertFrom-Json -AsHashtable
$managedMcp = @($manifest.mcpServers.Keys)
$externalMcp = @($manifest.externalServers)

$repoSettings = Get-Content (Join-Path $PSScriptRoot 'claude\settings.json') -Raw |
    ConvertFrom-Json -AsHashtable
$wantedPlugins = @($repoSettings.enabledPlugins.Keys | Where-Object { $repoSettings.enabledPlugins[$_] })
$installedPlugins = @()
if (Test-Cmd claude.exe) {
    $version = (& claude.exe --version 2>$null | Out-String).Trim()
    Write-Ok "Claude Code CLI $version"
    try {
        $installedPlugins = @((& claude.exe plugin list --json 2>$null | Out-String |
                    ConvertFrom-Json) | Where-Object { $_.enabled })
    }
    catch { Write-Warn2 "could not read Claude's plugin state: $($_.Exception.Message)" }
}
else {
    Write-Warn2 'Claude Code CLI is missing - install it with the command in docs\post-format.md'
}

$marketplaceManifest = Get-Content (Join-Path $PSScriptRoot 'claude\marketplaces.json') -Raw |
    ConvertFrom-Json -AsHashtable
$wantedMarketplaces = @($marketplaceManifest.marketplaces.Keys)
$installedMarketplaces = @()
if (Test-Cmd claude.exe) {
    try {
        $installedMarketplaces = @((& claude.exe plugin marketplace list --json 2>$null |
                    Out-String | ConvertFrom-Json).name)
    }
    catch { Write-Warn2 "could not read Claude marketplace state: $($_.Exception.Message)" }
}
$missingMarketplaces = @($wantedMarketplaces | Where-Object { $_ -notin $installedMarketplaces })
if ($missingMarketplaces) {
    Write-Warn2 "$($missingMarketplaces.Count) declared marketplace(s) are not registered:"
    foreach ($name in $missingMarketplaces) { Write-Host "         $name" -ForegroundColor Yellow }
}
elseif ($wantedMarketplaces.Count) { Write-Ok "all $($wantedMarketplaces.Count) marketplaces are registered" }

$enabledPluginIds = @($installedPlugins.id)
$disabledPlugins = @($wantedPlugins | Where-Object { $_ -notin $enabledPluginIds })
if ($disabledPlugins) {
    Write-Warn2 "$($disabledPlugins.Count) declared plugin(s) are not effectively enabled:"
    foreach ($id in $disabledPlugins) { Write-Host "         $id" -ForegroundColor Yellow }
    Write-Host '         Run claude\install.ps1, then restart Claude Code.' -ForegroundColor DarkGray
}
elseif ($wantedPlugins.Count) { Write-Ok "all $($wantedPlugins.Count) declared plugins are enabled" }

# Plugin MCP definitions are discovered from the enabled plugin's own install path. This
# prevents a cached-but-disabled plugin from hiding a loose server that is actually needed.
$fromPlugins = @($installedPlugins | ForEach-Object {
        $mcpFile = Join-Path $_.installPath '.mcp.json'
        if (-not (Test-Path $mcpFile)) { return }
        try {
            $j = Get-Content $mcpFile -Raw | ConvertFrom-Json -AsHashtable
            if ($j.mcpServers) { $j.mcpServers.Keys } else { $j.Keys }
        }
        catch { Write-Warn2 "invalid plugin MCP file: $mcpFile" }
    } | Select-Object -Unique)

$liveMcp = @()
$userStatePath = Join-Path $HOME '.claude.json'
if (Test-Path $userStatePath) {
    try {
        $userState = Get-Content $userStatePath -Raw | ConvertFrom-Json -AsHashtable
        if ($userState.mcpServers) { $liveMcp = @($userState.mcpServers.Keys) }
    }
    catch { Write-Warn2 "~/.claude.json is invalid: $($_.Exception.Message)" }
}

$missingMcp = @($managedMcp | Where-Object { $_ -notin $liveMcp })
$unexpectedMcp = @($liveMcp | Where-Object { $_ -notin $managedMcp -and $_ -notin $externalMcp })
$duplicates = @($liveMcp | Where-Object { $_ -in $fromPlugins })
Write-Host "  $($managedMcp.Count) repo-managed, $($externalMcp.Count) external, $($liveMcp.Count) user-scope" -ForegroundColor DarkGray

if ($missingMcp) {
    Write-Warn2 "$($missingMcp.Count) managed server(s) are missing; run claude\install.ps1 -Secrets:"
    foreach ($name in $missingMcp) { Write-Host "         $name" -ForegroundColor Red }
}
if ($unexpectedMcp) {
    Write-Warn2 "$($unexpectedMcp.Count) undeclared user-scope server(s), preserved for review:"
    foreach ($name in $unexpectedMcp) { Write-Host "         $name" -ForegroundColor Yellow }
}
if ($duplicates) {
    Write-Warn2 "$($duplicates.Count) server(s) exist both user-scope and through an enabled plugin:"
    foreach ($name in $duplicates) { Write-Host "         $name" -ForegroundColor Yellow }
}
if (-not $missingMcp -and -not $unexpectedMcp -and -not $duplicates) {
    Write-Ok 'the MCP manifest and effective user state agree'
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

$reposRoot = Get-LayoutPath 'repos'
$repoCategories = @(Get-ChildItem (Join-Path $PSScriptRoot 'dev\repos') -Filter *.md |
        Where-Object Name -ne 'README.md' | ForEach-Object { Join-Path $reposRoot $_.BaseName })
$missingCategories = @($repoCategories | Where-Object { -not (Test-Path $_) })
if ($missingCategories) {
    Write-Warn2 "$($missingCategories.Count) derived repository folder(s) are missing:"
    foreach ($path in $missingCategories) { Write-Host "         $path" -ForegroundColor Red }
}

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
exit 0

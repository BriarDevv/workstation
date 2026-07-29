<#
.SYNOPSIS
    Installs the programs listed in README.md.

.DESCRIPTION
    Reads the winget IDs straight out of README.md's tables, so adding a row there is
    enough to get a package installed on the next run. Idempotent: anything already
    present is skipped.

    One failure doesn't abort the run - failures are collected and printed together at the
    end, because a restore that stopped at the first bad package leaves you worse off than
    one that finished and told you what's missing.

    Exit code 0 means everything asked for is on the machine. Exit code 1 means at least
    one thing isn't, and the summary names it.

.PARAMETER Optional
    Also install the "Optional" table. Off by default. The table in README.md is the list —
    this help text deliberately doesn't repeat it, so it can't go stale.

.PARAMETER SkipUpgrade
    Don't upgrade packages that are already installed but outdated.

.PARAMETER WhatIfOnly
    Report every action without performing any of them - packages, the Node download, the
    PATH entries and the files written into $HOME. It used to stop after listing the winget
    packages, which quietly hid the parts most worth reviewing beforehand.

.EXAMPLE
    pwsh apps\install.ps1
    pwsh apps\install.ps1 -Optional
    pwsh apps\install.ps1 -WhatIfOnly
#>
[CmdletBinding()]
param(
    [switch]$Optional,
    [switch]$SkipUpgrade,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

# Every helper in _lib reads this, so the dry run reaches the whole script rather than
# stopping wherever the flag happened to be checked.
$script:DryRun = [bool]$WhatIfOnly

if (-not (Test-Cmd winget)) {
    Write-Fail 'winget is missing.'
    Write-Host '  It ships inside App Installer, which comes from the Microsoft Store - and the' -ForegroundColor DarkGray
    Write-Host '  target OS here is LTSC, which has no Store. So on a fresh install this is the' -ForegroundColor DarkGray
    Write-Host '  expected state, not a broken machine, and pointing you at the Store would be' -ForegroundColor DarkGray
    Write-Host '  sending you somewhere that does not exist. windows\bootstrap.ps1 is written for' -ForegroundColor DarkGray
    Write-Host '  exactly this: it pulls App Installer straight from GitHub.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '      powershell -ExecutionPolicy Bypass -File windows\bootstrap.ps1' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Elevated, and with Windows PowerShell 5.1 - not pwsh, which it also installs.' -ForegroundColor DarkGray
    exit 1
}

$readme = Join-Path $PSScriptRoot 'README.md'
$core = Get-IdsFromReadme $readme @('Essentials', 'Terminal', 'Desktop / utilities', 'Games', 'Runtimes')
$extra = Get-IdsFromReadme $readme @('Optional')
$targets = if ($Optional) { $core + $extra } else { $core }

Write-Step "Apps — $($targets.Count) packages"
Write-Host "  $($core.Count) core$(if ($Optional) { " + $($extra.Count) optional" } else { " ($($extra.Count) optional skipped — pass -Optional)" })"

# ---------------------------------------------------------------- fonts need admin
$fontIds = $targets | Where-Object { $_ -match 'NerdFont|Font$' }
if ($fontIds -and -not (Test-Admin)) {
    Write-Warn2 "Not running as admin. Font packages install machine-wide (C:\Windows\Fonts)"
    Write-Warn2 "via an MSI with no user-scope option — winget will prompt for UAC, or fail"
    Write-Warn2 "outright in an unattended run. A font that didn't install shows up as hollow"
    Write-Warn2 "boxes everywhere with no error message. Re-run elevated if that happens."
}

# ---------------------------------------------------------------- winget packages
# Collected rather than acted on immediately: one failed package shouldn't abort a restore,
# and a wall of scrolled-past output is not a report. Both lists feed the summary.
$failed = [System.Collections.Generic.List[string]]::new()
$fresh = [System.Collections.Generic.List[string]]::new()

foreach ($id in $targets) {
    switch (Install-WingetPackage $id) {
        'ok' { $fresh.Add($id) }
        'fail' { $failed.Add($id) }
    }
}

# ---------------------------------------------------------------- latest stable, always
# House rule: this machine runs the latest stable of everything, so every package in the
# tables gets upgraded - not just the ones installed fresh above.
#
# The terminal stack is why the rule exists. Windows Terminal silently ignores settings
# keys it doesn't recognise, and this config uses font.builtinGlyphs, font.colorGlyphs and
# font.cellHeight, all recent additions. On an old build it loads without complaint and
# just looks wrong, with nothing pointing at the version.
if (-not $SkipUpgrade) {
    Write-Step "Upgrading to latest stable"

    # Skip whatever was installed seconds ago - it's current by definition. Each check is a
    # network round-trip, measured at ~1.4s, so on a fresh machine this is the difference
    # between finishing and spending another 47 seconds confirming what we already know.
    $stale = @($targets | Where-Object { $_ -notin $fresh })
    if ($fresh.Count) { Write-Skip "$($fresh.Count) just installed - already at the latest" }
    foreach ($id in $stale) { Update-WingetPackage $id }
}

# ---------------------------------------------------------------- Node
Write-Step "Node"
# layout\LAYOUT.md owns this. A literal here would be the second place the path is written
# down, and the tree it points into is created by a script that reads the first one.
$nodeDir = Get-LayoutPath 'node'

# Resolved at run time, not pinned: a hardcoded version in a restore script is stale the
# day after you write it. LTS rather than Current - "latest stable" for Node means the LTS
# line. The literal below is only the fallback for when nodejs.org can't be reached.
$nodeVersion = 'v24.18.0'
try {
    # Assign first, then pipe. Invoke-RestMethod emits a JSON array as ONE object instead
    # of enumerating it, so piping it straight into Where-Object hands the filter a single
    # item - the whole array. `$_.lts` on an array member-enumerates to a non-empty list,
    # which is truthy, so every version "passes" and $nodeVersion ends up holding all 854
    # of them. The URL built from that 404s and Node never installs. Don't re-merge these
    # two lines.
    $index = Invoke-RestMethod 'https://nodejs.org/dist/index.json' -TimeoutSec 20
    $latest = $index | Where-Object { $_.lts } | Select-Object -First 1

    # Belt and braces: it goes straight into a download URL, so refuse anything that isn't
    # a single well-formed version rather than fetching a nonsense path.
    if ($latest.version -is [string] -and $latest.version -match '^v\d+\.\d+\.\d+$') {
        $nodeVersion = $latest.version
    }
    else {
        Write-Warn2 "unexpected answer from nodejs.org - falling back to the pinned $nodeVersion"
    }
}
catch { Write-Warn2 "nodejs.org unreachable - falling back to the pinned $nodeVersion" }

$nodeExe = Join-Path $nodeDir 'node.exe'
$nodeCurrent = if (Test-Path $nodeExe) { (& $nodeExe --version).Trim() } else { $null }

if ($nodeCurrent -eq $nodeVersion) {
    Write-Skip "Node $nodeCurrent (latest LTS)"
}
elseif ($nodeCurrent -and $SkipUpgrade) {
    Write-Skip "Node $nodeCurrent - latest LTS is $nodeVersion, held back by -SkipUpgrade"
}
elseif ($script:DryRun) {
    Write-Would "download Node $nodeVersion (~100 MB) and $(if ($nodeCurrent) { "replace $nodeCurrent in" } else { 'unpack it into' }) $nodeDir"
}
else {
    Write-Host "  ...$(if ($nodeCurrent) { "Node $nodeCurrent -> $nodeVersion" } else { "downloading Node $nodeVersion" })" -ForegroundColor DarkYellow
    try {
        $zip = Join-Path $env:TEMP 'node.zip'
        $tmp = Join-Path $env:TEMP 'node-extract'
        Invoke-WebRequest "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-win-x64.zip" -OutFile $zip -UseBasicParsing
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive $zip -DestinationPath $tmp -Force
        New-Item -ItemType Directory -Force -Path (Split-Path $nodeDir -Parent) | Out-Null

        # Swap only once the new tree is on disk, and keep the old one until it lands. Global
        # packages live in %APPDATA%\npm, so replacing this directory loses nothing.
        Remove-Item "$nodeDir.old" -Recurse -Force -ErrorAction SilentlyContinue
        if ($nodeCurrent) { Move-Item $nodeDir "$nodeDir.old" -Force }
        Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $nodeDir -Force
        Remove-Item "$nodeDir.old", $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "Node $nodeVersion at $nodeDir"
    }
    catch {
        # _lib sets $ErrorActionPreference to Stop, so without catching here a dropped
        # download takes the whole restore down with it. Record it and keep going.
        Write-Fail "Node $nodeVersion failed: $($_.Exception.Message)"
        if ((Test-Path "$nodeDir.old") -and -not (Test-Path $nodeExe)) {
            Move-Item "$nodeDir.old" $nodeDir -Force
            Write-Warn2 "put the previous Node $nodeCurrent back"
        }
        $failed.Add('Node')
    }
}

# A dry run never wrote Node, so on a fresh machine it isn't there - but the real run would
# have put it there by now. Without this the rest of the report reads "skipped, no Node" for
# steps that would actually have happened.
$haveNode = (Test-Path $nodeExe) -or $script:DryRun
if ($haveNode) { Add-UserPath $nodeDir }

# The registry's "latest" dist-tag, which is the stable release - prereleases live under
# their own tags and never answer here. $null when the registry can't be reached.
function Get-NpmLatest {
    param([Parameter(Mandatory)][string]$Package)
    $v = npm view $Package version 2>$null | Select-Object -Last 1
    if ($LASTEXITCODE -eq 0 -and $v) { return $v.Trim() }
    return $null
}

# pnpm rides on corepack, which ships with Node - so if Node didn't land, don't pretend.
if (-not $haveNode) { Write-Warn2 'pnpm skipped - no Node' }
elseif ($script:DryRun) {
    $pnpmHave = if (Test-Cmd pnpm) { (pnpm --version 2>$null).Trim() } else { $null }
    $pnpmWant = Get-NpmLatest 'pnpm'
    if ($pnpmHave -and $pnpmHave -eq $pnpmWant) { Write-Skip "pnpm $pnpmHave" }
    else { Write-Would "enable corepack and activate pnpm@latest$(if ($pnpmWant) { " ($pnpmWant)" })" }
}
else {
    & "$nodeDir\corepack.cmd" enable 2>&1 | Out-Null
    $pnpmHave = if (Test-Cmd pnpm) { (pnpm --version 2>$null).Trim() } else { $null }
    $pnpmWant = if ($pnpmHave -and $SkipUpgrade) { $pnpmHave } else { Get-NpmLatest 'pnpm' }

    if ($pnpmHave -and ($pnpmHave -eq $pnpmWant -or -not $pnpmWant)) { Write-Skip "pnpm $pnpmHave" }
    else {
        Write-Host "  ...pnpm$(if ($pnpmHave) { " $pnpmHave -> $pnpmWant" })" -ForegroundColor DarkYellow
        & "$nodeDir\corepack.cmd" prepare pnpm@latest --activate 2>&1 | Out-Null
        Write-Ok "pnpm $((pnpm --version 2>$null).Trim())"
    }
}

# uv --version prints "uv 0.11.20 (hash date target)" - only the second field is the version.
function Get-UvVersion { if (Test-Cmd uv) { (uv --version 2>$null) -split '\s+' | Select-Object -Index 1 } }

$uvHave = Get-UvVersion
if (-not $uvHave -and $script:DryRun) { Write-Would 'install uv from astral.sh into ~\.local\bin' }
elseif (-not $uvHave) {
    powershell -ExecutionPolicy Bypass -c 'irm https://astral.sh/uv/install.ps1 | iex' 2>&1 | Out-Null
    Write-Ok "uv $(Get-UvVersion)"
}
elseif ($SkipUpgrade) { Write-Skip "uv $uvHave" }
elseif ($script:DryRun) { Write-Would "run uv self update (currently $uvHave)" }
else {
    # uv ships its own updater and no-ops when it's already current.
    uv self update 2>&1 | Out-Null
    $uvNow = Get-UvVersion
    if ($uvNow -eq $uvHave) { Write-Skip "uv $uvHave" } else { Write-Ok "uv $uvHave -> $uvNow" }
}
Add-UserPath (Join-Path $HOME '.local\bin')

# ---------------------------------------------------------------- npm globals
Write-Step "npm globals"

# npm's builtin npmrc, shipped inside the Node zip, sets prefix=${APPDATA}\npm - global
# binaries land there, not next to node.exe. The zip touches no environment variables, so
# nothing puts that directory on PATH. Without this line a fresh machine installs omc and
# the MCP servers without a single error and then cannot run any of them. It only works on
# the current machine because an older Node MSI added the entry years ago.
Add-UserPath (Join-Path $env:APPDATA 'npm')

# Before the installs, so ignore-scripts is already in force for them.
Install-ConfigFile (Join-Path $PSScriptRoot 'npmrc') (Join-Path $HOME '.npmrc') | Out-Null

$wanted = Get-IdsFromReadme $readme @('npm globals')

if (-not $haveNode) { Write-Warn2 "$($wanted.Count) globals skipped - no Node, so no npm" }
else {
    $installed = @{}
    $deps = (npm ls -g --depth=0 --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue).dependencies
    if ($deps) { $deps.PSObject.Properties | ForEach-Object { $installed[$_.Name] = $_.Value.version } }

    foreach ($pkg in $wanted) {
        $have = $installed[$pkg]

        if ($have) {
            if ($SkipUpgrade) { Write-Skip "$pkg $have"; continue }
            $want = Get-NpmLatest $pkg
            if (-not $want) { Write-Warn2 "$pkg $have - registry unreachable, left alone"; continue }
            if ($have -eq $want) { Write-Skip "$pkg $have"; continue }
        }

        if ($script:DryRun) { Write-Would "npm i -g $pkg@latest$(if ($have) { " (upgrading $have)" })"; continue }

        Write-Host "  ...npm i -g $pkg@latest$(if ($have) { " ($have -> $want)" })" -ForegroundColor DarkYellow
        npm install -g "$pkg@latest" --silent 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "$pkg $(if ($want) { $want })".Trim() }
        else {
            Write-Warn2 "$pkg failed (code $LASTEXITCODE)"
            $failed.Add("npm: $pkg")
        }
    }
}

# ---------------------------------------------------------------- summary
# CLAUDE.md: "Report honestly: what came out green, what failed." A run that scrolled two
# hundred lines past you isn't a report - and the lines that matter are the ones you missed.
Write-Step 'Summary'
Write-Host "  $($targets.Count) winget packages checked, $($wanted.Count) npm globals" -ForegroundColor DarkGray

if ($fresh.Count) {
    if ($script:DryRun) { Write-Would "install $($fresh.Count) package(s)" }
    else { Write-Ok "$($fresh.Count) newly installed" }
    foreach ($f in $fresh) { Write-Host "         $f" -ForegroundColor DarkGray }
}

# Only mentioned when something that actually needs one was installed on this run. A
# warning that fires every time is a warning you stop reading.
$needsReboot = @($fresh | Where-Object { $_ -in @('Docker.DockerDesktop', 'Microsoft.WSL') })
if ($needsReboot) {
    Write-Warn2 "$(if ($script:DryRun) { 'would need a REBOOT' } else { 'REBOOT before these work' }): $($needsReboot -join ', ')"
}

# Named out loud, every run. These can't be installed by any flag - written down in the
# README is not the same as being told, and the whole point of the section is that you find
# out now instead of three weeks after the format.
$manual = Get-RowsFromReadme $readme @('Manual afterwards')
if ($manual.Count) {
    Write-Host ''
    Write-Warn2 "$($manual.Count) things this script cannot install - do them by hand:"
    foreach ($m in $manual) { Write-Host "         $m" -ForegroundColor Yellow }
    Write-Host '  Reasons and download links: apps\README.md, section "Manual afterwards".' -ForegroundColor DarkGray
}

if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) failed - this machine is NOT fully set up:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host '  winget failures are usually transient. Re-running is safe and skips' -ForegroundColor DarkGray
    Write-Host '  everything that already worked. A font that failed means: re-run elevated.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host '  Open a new terminal so the PATH changes take effect.' -ForegroundColor DarkGray
Write-Host ''

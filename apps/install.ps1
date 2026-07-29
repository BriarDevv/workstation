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
    PATH entries and the files written into $HOME.

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
    Write-Host '  It ships inside App Installer, which Windows 11 Pro does include - so this is' -ForegroundColor DarkGray
    Write-Host '  unusual rather than expected. Most likely App Installer has not finished' -ForegroundColor DarkGray
    Write-Host '  registering for your user yet, which happens on a machine that had no network' -ForegroundColor DarkGray
    Write-Host '  during setup. Try the Store first; if it is still missing, bootstrap pulls it' -ForegroundColor DarkGray
    Write-Host '  straight from GitHub:' -ForegroundColor DarkGray
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

# Kept out of $targets on purpose. These need --source msstore, and they are deliberately
# absent from the upgrade pass below: Store apps update themselves, and `winget upgrade` on a
# Store ID without a source can hit the ambiguity error the source flag exists to avoid.
$store = @(Get-IdsFromReadme $readme @('Microsoft Store'))

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
    # A package only gets a location if LAYOUT.md declares one, which is almost none of them.
    # The vendor default is the right answer unless there's a reason, and LAYOUT.md is where
    # the reasons are written down - so -IfDeclared, and $null is the expected answer.
    $dest = Get-LayoutPath -Key $id -IfDeclared
    $outcome = if ($dest) { Install-WingetPackage -Id $id -Location $dest }
    else { Install-WingetPackage -Id $id }

    switch ($outcome) {
        'ok' { $fresh.Add($id) }
        'fail' { $failed.Add($id) }
    }
}

if ($store.Count) {
    Write-Step "Microsoft Store — $($store.Count) package(s)"
    Write-Host '  Store may request a Microsoft sign-in; if it does, the package is reported as failed.' -ForegroundColor DarkGray
    foreach ($id in $store) {
        switch (Install-WingetPackage -Id $id -Source 'msstore') {
            'ok' { }
            'fail' { $failed.Add("$id (msstore)") }
        }
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

    # Skip whatever was installed seconds ago - it is current by definition and does not
    # need another network query.
    $stale = @($targets | Where-Object { $_ -notin $fresh })
    if ($fresh.Count) { Write-Skip "$($fresh.Count) just installed - already at the latest" }
    foreach ($id in $stale) {
        if ((Update-WingetPackage $id) -eq 'fail') { $failed.Add("upgrade: $id") }
    }
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
    $nodeStage = Join-Path ([IO.Path]::GetTempPath()) "workstation-node-$PID-$([guid]::NewGuid().ToString('N'))"
    $nodeOld = "$nodeDir.workstation-old-$PID-$([guid]::NewGuid().ToString('N'))"
    try {
        New-Item -ItemType Directory -Path $nodeStage | Out-Null
        $zip = Join-Path $nodeStage 'node.zip'
        $tmp = Join-Path $nodeStage 'extract'
        Invoke-WebRequest "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-win-x64.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tmp -Force
        New-Item -ItemType Directory -Force -Path (Split-Path $nodeDir -Parent) | Out-Null

        # Swap only once the new tree is on disk, and keep the old one until it lands. Global
        # packages live in %APPDATA%\npm, so replacing this directory loses nothing.
        if ($nodeCurrent) { Move-Item -LiteralPath $nodeDir -Destination $nodeOld }
        Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $nodeDir -Force
        $landedVersion = (& (Join-Path $nodeDir 'node.exe') --version).Trim()
        if ($landedVersion -ne $nodeVersion) { throw "staged runtime reported $landedVersion" }
        if (Test-Path $nodeOld) { Remove-Item -LiteralPath $nodeOld -Recurse -Force }
        Write-Ok "Node $nodeVersion at $nodeDir"
    }
    catch {
        # _lib sets $ErrorActionPreference to Stop, so without catching here a dropped
        # download takes the whole restore down with it. Record it and keep going.
        Write-Fail "Node $nodeVersion failed: $($_.Exception.Message)"
        if (Test-Path $nodeOld) {
            if (Test-Path $nodeDir) { Remove-Item -LiteralPath $nodeDir -Recurse -Force }
            Move-Item -LiteralPath $nodeOld -Destination $nodeDir
            Write-Warn2 "put the previous Node $nodeCurrent back"
        }
        elseif (-not $nodeCurrent -and (Test-Path $nodeDir)) {
            Remove-Item -LiteralPath $nodeDir -Recurse -Force
            Write-Warn2 'removed the incomplete new Node tree'
        }
        $failed.Add('Node')
    }
    finally {
        if (Test-Path $nodeStage) { Remove-Item -LiteralPath $nodeStage -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Distinguish what exists now from what the dry run predicts. The prediction is useful for
# the report, but it must never authorize a call to npm/corepack that does not exist yet.
$haveNode = Test-Path $nodeExe
$nodeWillExist = $haveNode -or $script:DryRun
if ($nodeWillExist) { Add-UserPath $nodeDir }

# The registry's "latest" dist-tag, which is the stable release - prereleases live under
# their own tags and never answer here. $null when the registry can't be reached.
function Get-NpmLatest {
    param([Parameter(Mandatory)][string]$Package)
    try {
        # Registry HTTP works during a clean dry run where Node/npm are only planned, and
        # avoids turning that preview into an accidental dependency on the current machine.
        $escaped = [Uri]::EscapeDataString($Package)
        $answer = Invoke-RestMethod "https://registry.npmjs.org/$escaped/latest" -TimeoutSec 20
        if ($answer.version -is [string]) { return $answer.version.Trim() }
    }
    catch { }
    return $null
}

# pnpm rides on corepack, which ships with Node - so if Node didn't land, don't pretend.
if (-not $nodeWillExist) { Write-Warn2 'pnpm skipped - no Node' }
elseif ($script:DryRun) {
    $pnpmHave = if (Test-Cmd pnpm) { (pnpm --version 2>$null).Trim() } else { $null }
    $pnpmWant = Get-NpmLatest 'pnpm'
    if (-not $pnpmWant) {
        Write-Warn2 'pnpm update check failed - npm registry unreachable'
        $failed.Add('pnpm update check')
    }
    elseif ($pnpmHave -and $pnpmHave -eq $pnpmWant) { Write-Skip "pnpm $pnpmHave" }
    else { Write-Would "enable corepack and activate pnpm@latest$(if ($pnpmWant) { " ($pnpmWant)" })" }
}
else {
    & "$nodeDir\corepack.cmd" enable 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "corepack enable failed (code $LASTEXITCODE)"
        $failed.Add('corepack enable')
    }
    else {
        $pnpmHave = if (Test-Cmd pnpm) { (pnpm --version 2>$null).Trim() } else { $null }
        $pnpmWant = if ($pnpmHave -and $SkipUpgrade) { $pnpmHave } else { Get-NpmLatest 'pnpm' }

        if (-not $pnpmWant) {
            Write-Warn2 'pnpm update check failed - npm registry unreachable'
            $failed.Add('pnpm update check')
        }
        elseif ($pnpmHave -and $pnpmHave -eq $pnpmWant) { Write-Skip "pnpm $pnpmHave" }
        else {
            Write-Host "  ...pnpm$(if ($pnpmHave) { " $pnpmHave -> $pnpmWant" })" -ForegroundColor DarkYellow
            & "$nodeDir\corepack.cmd" prepare pnpm@latest --activate 2>&1 | Out-Null
            $pnpmCode = $LASTEXITCODE
            $pnpmNow = if ($pnpmCode -eq 0 -and (Test-Cmd pnpm)) { (pnpm --version 2>$null).Trim() } else { $null }
            if ($pnpmCode -eq 0 -and $pnpmNow) { Write-Ok "pnpm $pnpmNow" }
            else {
                Write-Warn2 "pnpm activation failed (code $pnpmCode)"
                $failed.Add('pnpm activation')
            }
        }
    }
}

# uv --version prints "uv 0.11.20 (hash date target)" - only the second field is the version.
function Get-UvVersion { if (Test-Cmd uv) { (uv --version 2>$null) -split '\s+' | Select-Object -Index 1 } }

$uvHave = Get-UvVersion
if (-not $uvHave -and $script:DryRun) { Write-Would 'install uv from astral.sh into ~\.local\bin' }
elseif (-not $uvHave) {
    powershell -ExecutionPolicy Bypass -c 'irm https://astral.sh/uv/install.ps1 | iex' 2>&1 | Out-Null
    $uvInstallCode = $LASTEXITCODE
    $uvNow = Get-UvVersion
    if ($uvInstallCode -eq 0 -and $uvNow) { Write-Ok "uv $uvNow" }
    else {
        Write-Warn2 'uv installation failed'
        $failed.Add('uv installation')
    }
}
elseif ($SkipUpgrade) { Write-Skip "uv $uvHave" }
elseif ($script:DryRun) { Write-Would "run uv self update (currently $uvHave)" }
else {
    # uv ships its own updater and no-ops when it's already current.
    uv self update 2>&1 | Out-Null
    $uvCode = $LASTEXITCODE
    $uvNow = Get-UvVersion
    if ($uvCode -ne 0) {
        Write-Warn2 "uv self update failed (code $uvCode)"
        $failed.Add('uv update')
    }
    elseif ($uvNow -eq $uvHave) { Write-Skip "uv $uvHave" }
    else { Write-Ok "uv $uvHave -> $uvNow" }
}
Add-UserPath (Join-Path $HOME '.local\bin')

# ---------------------------------------------------------------- npm globals
Write-Step "npm globals"

# npm's builtin npmrc, shipped inside the Node zip, sets prefix=${APPDATA}\npm - global
# binaries land there, not next to node.exe. The zip touches no environment variables, so
# nothing puts that directory on PATH. Without this line a fresh machine can install a
# global CLI successfully and still be unable to run it.
Add-UserPath (Join-Path $env:APPDATA 'npm')

# Before the installs, so ignore-scripts is already in force for them.
if (-not (Install-ConfigFile (Join-Path $PSScriptRoot 'npmrc') (Join-Path $HOME '.npmrc'))) {
    $failed.Add('.npmrc')
}

$wanted = Get-IdsFromReadme $readme @('npm globals')

if (-not $nodeWillExist) { Write-Warn2 "$($wanted.Count) globals skipped - no Node, so no npm" }
else {
    $installed = @{}
    if ($haveNode -and (Test-Cmd npm)) {
        $deps = (npm ls -g --depth=0 --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue).dependencies
        if ($deps) { $deps.PSObject.Properties | ForEach-Object { $installed[$_.Name] = $_.Value.version } }
    }
    elseif (-not $script:DryRun) {
        Write-Warn2 'npm is missing even though Node exists'
        $failed.Add('npm missing')
    }

    foreach ($pkg in $wanted) {
        $have = $installed[$pkg]

        if ($have) {
            if ($SkipUpgrade) { Write-Skip "$pkg $have"; continue }
            $want = Get-NpmLatest $pkg
            if (-not $want) {
                Write-Warn2 "$pkg $have - update check failed, left alone"
                $failed.Add("npm update check: $pkg")
                continue
            }
            if ($have -eq $want) { Write-Skip "$pkg $have"; continue }
        }

        if ($script:DryRun) { Write-Would "npm i -g $pkg@latest$(if ($have) { " (upgrading $have)" })"; continue }
        if (-not (Test-Cmd npm)) { continue }

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
if ($script:DryRun) { Write-Host '  Dry run complete; no PATH or files changed.' -ForegroundColor DarkGray }
else { Write-Host '  Open a new terminal so the PATH changes take effect.' -ForegroundColor DarkGray }
Write-Host ''
exit 0

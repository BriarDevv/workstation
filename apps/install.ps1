<#
.SYNOPSIS
    Installs the programs listed in README.md.

.DESCRIPTION
    Reads the winget IDs straight out of README.md's tables, so adding a row there is
    enough to get a package installed on the next run. Idempotent: anything already
    present is skipped.

.PARAMETER Optional
    Also install the "Optional" table (games, Ollama, Teams...). Off by default.

.PARAMETER SkipUpgrade
    Don't upgrade packages that are already installed but outdated.

.PARAMETER WhatIfOnly
    Print what would happen and exit. Nothing is installed.

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

if (-not (Test-Cmd winget)) {
    Write-Fail "winget is missing. Install 'App Installer' from the Microsoft Store."
    exit 1
}

$readme = Join-Path $PSScriptRoot 'README.md'
$core = Get-IdsFromReadme $readme @('Essentials', 'Terminal', 'Desktop / utilities')
$extra = Get-IdsFromReadme $readme @('Optional')
$targets = if ($Optional) { $core + $extra } else { $core }

Write-Step "Apps — $($targets.Count) packages"
Write-Host "  $($core.Count) core$(if ($Optional) { " + $($extra.Count) optional" } else { " ($($extra.Count) optional skipped — pass -Optional)" })"

if ($WhatIfOnly) {
    $targets | ForEach-Object { Write-Host "  would install: $_" -ForegroundColor DarkGray }
    return
}

# ---------------------------------------------------------------- fonts need admin
$fontIds = $targets | Where-Object { $_ -match 'NerdFont|Font$' }
if ($fontIds -and -not (Test-Admin)) {
    Write-Warn2 "Not running as admin. Font packages install machine-wide (C:\Windows\Fonts)"
    Write-Warn2 "via an MSI with no user-scope option — winget will prompt for UAC, or fail"
    Write-Warn2 "outright in an unattended run. A font that didn't install shows up as hollow"
    Write-Warn2 "boxes everywhere with no error message. Re-run elevated if that happens."
}

# ---------------------------------------------------------------- winget packages
foreach ($id in $targets) { Install-WingetPackage $id | Out-Null }

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
    foreach ($id in $targets) { Update-WingetPackage $id }
}

# ---------------------------------------------------------------- Node
Write-Step "Node"
$nodeDir = 'C:\Briar\Code\Node'

# Resolved at run time, not pinned: a hardcoded version in a restore script is stale the
# day after you write it. LTS rather than Current - "latest stable" for Node means the LTS
# line. The literal below is only the fallback for when nodejs.org can't be reached.
$nodeVersion = 'v24.18.0'
try {
    $latest = Invoke-RestMethod 'https://nodejs.org/dist/index.json' -TimeoutSec 20 |
        Where-Object { $_.lts } | Select-Object -First 1
    if ($latest.version) { $nodeVersion = $latest.version }
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
else {
    Write-Host "  ...$(if ($nodeCurrent) { "Node $nodeCurrent -> $nodeVersion" } else { "downloading Node $nodeVersion" })" -ForegroundColor DarkYellow
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
Add-UserPath $nodeDir

# The registry's "latest" dist-tag, which is the stable release - prereleases live under
# their own tags and never answer here. $null when the registry can't be reached.
function Get-NpmLatest {
    param([Parameter(Mandatory)][string]$Package)
    $v = npm view $Package version 2>$null | Select-Object -Last 1
    if ($LASTEXITCODE -eq 0 -and $v) { return $v.Trim() }
    return $null
}

& "$nodeDir\corepack.cmd" enable 2>&1 | Out-Null
$pnpmHave = if (Test-Cmd pnpm) { (pnpm --version 2>$null).Trim() } else { $null }
$pnpmWant = if ($pnpmHave -and $SkipUpgrade) { $pnpmHave } else { Get-NpmLatest 'pnpm' }

if ($pnpmHave -and ($pnpmHave -eq $pnpmWant -or -not $pnpmWant)) { Write-Skip "pnpm $pnpmHave" }
else {
    Write-Host "  ...pnpm$(if ($pnpmHave) { " $pnpmHave -> $pnpmWant" })" -ForegroundColor DarkYellow
    & "$nodeDir\corepack.cmd" prepare pnpm@latest --activate 2>&1 | Out-Null
    Write-Ok "pnpm $((pnpm --version 2>$null).Trim())"
}

# uv --version prints "uv 0.11.20 (hash date target)" - only the second field is the version.
function Get-UvVersion { if (Test-Cmd uv) { (uv --version 2>$null) -split '\s+' | Select-Object -Index 1 } }

$uvHave = Get-UvVersion
if (-not $uvHave) {
    powershell -ExecutionPolicy Bypass -c 'irm https://astral.sh/uv/install.ps1 | iex' 2>&1 | Out-Null
    Write-Ok "uv $(Get-UvVersion)"
}
elseif ($SkipUpgrade) { Write-Skip "uv $uvHave" }
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

    Write-Host "  ...npm i -g $pkg@latest$(if ($have) { " ($have -> $want)" })" -ForegroundColor DarkYellow
    npm install -g "$pkg@latest" --silent 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "$pkg $(if ($want) { $want })".Trim() }
    else { Write-Warn2 "$pkg failed (code $LASTEXITCODE)" }
}

# ---------------------------------------------------------------- wrap up
Write-Host ''
Write-Warn2 'Docker Desktop and WSL need a REBOOT before they work.'
Write-Warn2 'Open a new terminal so the PATH changes take effect.'
Write-Host ''

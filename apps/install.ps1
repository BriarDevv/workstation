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

# ---------------------------------------------------------------- keep the terminal current
# Windows Terminal silently ignores settings keys it doesn't recognise. Our settings.json
# uses font.builtinGlyphs, font.colorGlyphs and font.cellHeight — all recent additions.
# On an old build the terminal loads without complaint and just looks wrong.
if (-not $SkipUpgrade) {
    Write-Step "Keeping the terminal stack current"
    foreach ($id in @(
            'Microsoft.WindowsTerminal'
            'Fastfetch-cli.Fastfetch'
            'Microsoft.PowerShell'
            'JanDeDobbeleer.OhMyPosh'
        )) { Update-WingetPackage $id }
}

# ---------------------------------------------------------------- Node
Write-Step "Node"
$nodeDir = 'C:\Briar\Code\Node'
if (Test-Path (Join-Path $nodeDir 'node.exe')) {
    Write-Skip "Node already at $nodeDir ($(& "$nodeDir\node.exe" --version))"
}
else {
    Write-Host "  ...downloading Node v24.12.0" -ForegroundColor DarkYellow
    $zip = Join-Path $env:TEMP 'node.zip'
    $tmp = Join-Path $env:TEMP 'node-extract'
    Invoke-WebRequest 'https://nodejs.org/dist/v24.12.0/node-v24.12.0-win-x64.zip' -OutFile $zip -UseBasicParsing
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $nodeDir -Parent) | Out-Null
    Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $nodeDir -Force
    Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Node at $nodeDir"
}
Add-UserPath $nodeDir

if (Test-Cmd pnpm) { Write-Skip "pnpm $(pnpm --version)" }
else {
    & "$nodeDir\corepack.cmd" enable 2>&1 | Out-Null
    & "$nodeDir\corepack.cmd" prepare pnpm@latest --activate 2>&1 | Out-Null
    Write-Ok 'pnpm'
}

if (Test-Cmd uv) { Write-Skip "uv $(uv --version)" }
else {
    powershell -ExecutionPolicy Bypass -c 'irm https://astral.sh/uv/install.ps1 | iex' 2>&1 | Out-Null
    Write-Ok 'uv'
}
Add-UserPath (Join-Path $HOME '.local\bin')

# ---------------------------------------------------------------- npm globals
Write-Step "npm globals"
$wanted = Get-IdsFromReadme $readme @('npm globals')
$installed = @(npm ls -g --depth=0 --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue |
    ForEach-Object { $_.dependencies.PSObject.Properties.Name })

foreach ($pkg in $wanted) {
    if ($installed -contains $pkg) { Write-Skip $pkg; continue }
    Write-Host "  ...npm i -g $pkg" -ForegroundColor DarkYellow
    npm install -g $pkg --silent 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok $pkg } else { Write-Warn2 "$pkg failed (code $LASTEXITCODE)" }
}

# ---------------------------------------------------------------- wrap up
Write-Host ''
Write-Warn2 'Docker Desktop and WSL need a REBOOT before they work.'
Write-Warn2 'Open a new terminal so the PATH changes take effect.'
Write-Host ''

# Shared helpers. Every install script starts with:  . "$PSScriptRoot\..\_lib.ps1"

$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path $PSCommandPath -Parent
$script:BackupDir = Join-Path $HOME ".workstation-backup\$(Get-Date -Format 'yyyy-MM-dd_HHmm')"

function Write-Step { param($m) Write-Host "`n=== $m" -ForegroundColor Cyan }
function Write-Ok { param($m) Write-Host "  [ok]   $m" -ForegroundColor Green }
function Write-Skip { param($m) Write-Host "  [skip] $m" -ForegroundColor DarkGray }
function Write-Warn2 { param($m) Write-Host "  [!]    $m" -ForegroundColor Yellow }
function Write-Fail { param($m) Write-Host "  [FAIL] $m" -ForegroundColor Red }

function Test-Cmd { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Fail "PowerShell $($PSVersionTable.PSVersion) - these scripts need 7+. Install with 'winget install Microsoft.PowerShell', then use 'pwsh'."
        exit 1
    }
}

# Copy a file into place, backing up whatever was there. Idempotent.
function Install-ConfigFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path $Source)) { Write-Fail "source missing: $Source"; return $false }

    if (Test-Path $Destination) {
        if ((Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash) {
            Write-Skip "$(Split-Path $Destination -Leaf) already identical"
            return $true
        }
        $bak = Join-Path $script:BackupDir (Split-Path $Destination -Leaf)
        New-Item -ItemType Directory -Force -Path (Split-Path $bak -Parent) | Out-Null
        Copy-Item $Destination $bak -Force
        Write-Warn2 "backed up original -> $bak"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Copy-Item $Source $Destination -Force
    Write-Ok $Destination
    return $true
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    $found = winget list --id $Id --exact --disable-interactivity 2>$null | Select-String -SimpleMatch $Id
    if ($found) { Write-Skip "$Id already installed"; return $true }

    Write-Host "  ...installing $Id" -ForegroundColor DarkYellow
    winget install --id $Id --exact --silent --accept-package-agreements `
        --accept-source-agreements --disable-interactivity 2>&1 |
        Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -eq 0) { Write-Ok $Id; return $true }
    Write-Warn2 "$Id exited with code $LASTEXITCODE"
    return $false
}

# Is there a newer version available? Returns $null when up to date.
function Get-WingetUpdate {
    param([Parameter(Mandatory)][string]$Id)
    $line = winget list --id $Id --exact --disable-interactivity 2>$null |
        Select-String -SimpleMatch $Id | Select-Object -First 1
    if (-not $line) { return $null }
    # winget prints: Name  Id  Version  Available  Source
    $cols = ($line.ToString() -split '\s{2,}') | Where-Object { $_ }
    if ($cols.Count -ge 4) { return @{ Current = $cols[2]; Available = $cols[3] } }
    return $null
}

function Update-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    $u = Get-WingetUpdate $Id
    if (-not $u) { Write-Skip "$Id up to date"; return }
    Write-Host "  ...upgrading $Id ($($u.Current) -> $($u.Available))" -ForegroundColor DarkYellow
    winget upgrade --id $Id --exact --silent --accept-package-agreements `
        --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "$Id -> $($u.Available)" }
    else { Write-Warn2 "$Id upgrade exited with code $LASTEXITCODE" }
}

function Add-UserPath {
    param([Parameter(Mandatory)][string]$Path)
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($cur -split ';' -contains $Path) { Write-Skip "PATH already has $Path"; return }
    [Environment]::SetEnvironmentVariable('Path', "$cur;$Path", 'User')
    $env:Path += ";$Path"
    Write-Ok "PATH += $Path"
}

# Pull winget IDs out of a README's markdown tables.
# Only reads the sections you name, so the npm/Node tables never get mistaken for winget IDs.
function Get-IdsFromReadme {
    param(
        [Parameter(Mandatory)][string]$ReadmePath,
        [Parameter(Mandatory)][string[]]$Sections
    )
    $current = ''
    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content $ReadmePath) {
        if ($line -match '^##\s+(.+?)\s*$') { $current = $Matches[1].Trim(); continue }
        if ($Sections -notcontains $current) { continue }
        if ($line -match '^\|\s*`([^`]+)`\s*\|') { $ids.Add($Matches[1].Trim()) }
    }
    return $ids
}

# The real font family name Windows registered, whatever naming scheme the package used.
# Nerd Fonts ships both "JetBrainsMono NFM" and "JetBrainsMono Nerd Font Mono" depending
# on the release, and picking the wrong one fails silently.
function Resolve-FontFamily {
    param([Parameter(Mandatory)][string]$Pattern)
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    return [System.Drawing.FontFamily]::Families.Name |
        Where-Object { $_ -match $Pattern } | Sort-Object Length | Select-Object -First 1
}

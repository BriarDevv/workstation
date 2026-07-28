# Shared helpers. Every install script starts with:  . "$PSScriptRoot\..\_lib.ps1"

$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path $PSCommandPath -Parent
$script:BackupDir = Join-Path $HOME ".workstation-backup\$(Get-Date -Format 'yyyy-MM-dd_HHmm')"

# Dry run. A calling script sets `$script:DryRun = $true` right after dot-sourcing this
# file, and every helper below reports what it would do instead of doing it. Dot-sourcing
# shares one script scope, which is what makes a single flag reach all of them.
#
# It lives here rather than in one script on purpose: a dry run is only trustworthy if it
# covers everything, and the way that breaks is a new script inventing its own half of the
# feature. Anything built on these helpers gets the whole thing for free.
$script:DryRun = $false

function Write-Step { param($m) Write-Host "`n=== $m" -ForegroundColor Cyan }
function Write-Would { param($m) Write-Host "  would  $m" -ForegroundColor DarkCyan }
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
        if ($script:DryRun) { Write-Would "overwrite $Destination (backing the current one up first)"; return $true }

        $bak = Join-Path $script:BackupDir (Split-Path $Destination -Leaf)
        New-Item -ItemType Directory -Force -Path (Split-Path $bak -Parent) | Out-Null
        Copy-Item $Destination $bak -Force
        Write-Warn2 "backed up original -> $bak"
    }
    if ($script:DryRun) { Write-Would "create $Destination"; return $true }

    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Copy-Item $Source $Destination -Force
    Write-Ok $Destination
    return $true
}

# Is the package installed? winget renders a table on a hit and prints "No installed
# package found matching input criteria." on a miss, so testing for the separator row is
# exact. Matching the Id in the output is not: winget truncates long columns with an
# ellipsis in narrow consoles, and the Id is usually the longest column.
function Test-WingetInstalled {
    param([Parameter(Mandatory)][string]$Id)
    $out = winget list --id $Id --exact --disable-interactivity 2>$null | Out-String
    return [bool]($out -match '(?m)^-{3,}')
}

# Returns 'skip', 'ok' or 'fail' rather than a boolean, so a caller can tell "was already
# there" apart from "installed it just now" without asking winget a second time. Knowing
# which is which is what lets the reboot warning fire only when it's actually earned.
function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    if (Test-WingetInstalled $Id) { Write-Skip "$Id already installed"; return 'skip' }
    # 'ok' rather than 'skip': the caller uses that to mean "this run put it there", which
    # is what a dry run is claiming would happen. Reporting 'skip' made the upgrade pass
    # then ask winget about a package that isn't installed, and get told it was up to date.
    if ($script:DryRun) { Write-Would "install $Id"; return 'ok' }

    Write-Host "  ...installing $Id" -ForegroundColor DarkYellow
    winget install --id $Id --exact --silent --accept-package-agreements `
        --accept-source-agreements --disable-interactivity 2>&1 |
        Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -eq 0) { Write-Ok $Id; return 'ok' }
    Write-Warn2 "$Id exited with code $LASTEXITCODE"
    return 'fail'
}

# Is there a newer version available? $null means "nothing to do" - either the package is
# current or it isn't installed at all.
#
# Do NOT go back to splitting a plain `winget list` on runs of whitespace. When a value
# fills its column winget separates it from the next one with a SINGLE space, so the split
# merges Id into Version. Measured on this machine, that made the old version of this
# function return Available='winget' (the source name) for Git.Git, and report fastfetch as
# up to date while it sat 8 releases behind - which silently turned the whole "keep the
# terminal stack current" step into a no-op.
#
# --upgrade-available only renders a table when an upgrade actually exists, so the presence
# of the table is the answer and no parsing is needed to get it right.
function Get-WingetUpdate {
    param([Parameter(Mandatory)][string]$Id)
    $lines = @(winget list --id $Id --exact --upgrade-available --disable-interactivity 2>$null)

    $sep = 0
    while ($sep -lt $lines.Count -and $lines[$sep] -notmatch '^-{3,}') { $sep++ }
    if ($sep -ge $lines.Count - 1) { return $null }

    # Versions are for the log line only, so a parse failure must not hide the upgrade.
    # Column widths are computed per query, which makes the header a reliable offset map.
    $header = if ($sep -ge 1) { $lines[$sep - 1] } else { '' }
    $row = $lines[$sep + 1]
    $iCur = $header.IndexOf('Version')
    $iNew = $header.IndexOf('Available')
    $iSrc = $header.IndexOf('Source')
    if ($iCur -lt 0 -or $iNew -le $iCur -or $iSrc -le $iNew -or $row.Length -le $iNew) {
        return @{ Current = '?'; Available = '?' }
    }
    return @{
        Current   = $row.Substring($iCur, $iNew - $iCur).Trim()
        Available = $row.Substring($iNew, [Math]::Min($iSrc - $iNew, $row.Length - $iNew)).Trim()
    }
}

function Update-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    $u = Get-WingetUpdate $Id
    # $null covers both "already current" and "not installed", so don't claim the first.
    if (-not $u) { Write-Skip "$Id nothing to upgrade"; return }
    if ($script:DryRun) { Write-Would "upgrade $Id ($($u.Current) -> $($u.Available))"; return }
    Write-Host "  ...upgrading $Id ($($u.Current) -> $($u.Available))" -ForegroundColor DarkYellow
    winget upgrade --id $Id --exact --silent --accept-package-agreements `
        --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "$Id -> $($u.Available)" }
    else { Write-Warn2 "$Id upgrade exited with code $LASTEXITCODE" }
}

function Add-UserPath {
    param([Parameter(Mandatory)][string]$Path)
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')

    # Check both scopes: a directory already on the machine PATH would otherwise get a
    # second, redundant copy in the user one. Compare without the trailing separator -
    # "C:\x" and "C:\x\" are the same directory but not the same string. -contains is
    # already case-insensitive.
    $seen = ((($cur, [Environment]::GetEnvironmentVariable('Path', 'Machine')) -join ';') -split ';') |
        Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
    if ($seen -contains $Path.TrimEnd('\')) { Write-Skip "PATH already has $Path"; return }
    if ($script:DryRun) { Write-Would "add $Path to the user PATH"; return }

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

# First column of every table row in the named sections, with markdown emphasis stripped.
#
# Get-IdsFromReadme only sees `backticked` cells, and that's deliberate - it's what keeps a
# prose table from being mistaken for an install list. This is its opposite number, for
# sections that describe steps instead of packages, so those can be read out loud at the
# end of a run rather than sitting unread in a file.
function Get-RowsFromReadme {
    param(
        [Parameter(Mandatory)][string]$ReadmePath,
        [Parameter(Mandatory)][string[]]$Sections
    )
    $current = ''
    $rows = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content $ReadmePath) {
        if ($line -match '^##\s+(.+?)\s*$') { $current = $Matches[1].Trim(); continue }
        if ($Sections -notcontains $current) { continue }
        if ($line -notmatch '^\|') { continue }

        $cell = (($line -split '\|')[1] -replace '\*\*|`', '').Trim()
        if (-not $cell) { continue }
        if ($cell -match '^-+$') { continue }                       # the ---- separator
        if ($cell -in @('What', 'winget ID', 'Package', 'ID')) { continue }   # header
        $rows.Add($cell)
    }
    return $rows
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

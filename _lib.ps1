# Shared helpers. Every install script starts with:  . "$PSScriptRoot\..\_lib.ps1"

$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path $PSCommandPath -Parent

# One restore run gets one backup directory, including when the root orchestrator invokes
# several folder scripts in the same PowerShell process. A standalone folder run creates its
# own ID. Milliseconds plus the process ID prevent two launches in the same minute from
# sharing a destination.
if (-not $env:WORKSTATION_BACKUP_RUN_ID) {
    $env:WORKSTATION_BACKUP_RUN_ID = "$(Get-Date -Format 'yyyy-MM-dd_HHmmssfff')-$PID"
}
$script:BackupDir = Join-Path $HOME ".workstation-backup\$env:WORKSTATION_BACKUP_RUN_ID"

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

# Return a collision-free backup path that preserves the destination's location. Using only
# the leaf name loses data as soon as two different programs both own a settings.json.
function Get-BackupPath {
    param([Parameter(Mandatory)][string]$Destination)

    $full = [IO.Path]::GetFullPath($Destination)
    $homeFull = [IO.Path]::GetFullPath($HOME).TrimEnd('\')
    if ($full.Equals($homeFull, [StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith($homeFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $relative = [IO.Path]::GetRelativePath($homeFull, $full)
        return Join-Path $script:BackupDir (Join-Path 'home' $relative)
    }

    $root = [IO.Path]::GetPathRoot($full)
    $rootLabel = ($root.TrimEnd('\') -replace '[:\\/]+', '-')
    if (-not $rootLabel) { $rootLabel = 'filesystem' }
    $relative = [IO.Path]::GetRelativePath($root, $full)
    return Join-Path $script:BackupDir (Join-Path "root-$rootLabel" $relative)
}

# Keep the first pre-run copy. If two steps touch the same destination, overwriting its
# backup with the intermediate state would make the original impossible to recover.
function Backup-ExistingFile {
    param([Parameter(Mandatory)][string]$Destination)

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) { return $null }
    $bak = Get-BackupPath $Destination
    if (Test-Path -LiteralPath $bak) {
        Write-Skip "original already backed up -> $bak"
        return $bak
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $bak -Parent) | Out-Null
    Copy-Item -LiteralPath $Destination -Destination $bak
    Write-Warn2 "backed up original -> $bak"
    return $bak
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

        Backup-ExistingFile $Destination | Out-Null
    }
    if ($script:DryRun) { Write-Would "create $Destination"; return $true }

    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Copy-Item $Source $Destination -Force
    Write-Ok $Destination
    return $true
}

# Install generated text with the same comparison, dry-run and backup guarantees as a file
# copied from the repo. Keeping this shared avoids each composer inventing a weaker writer.
function Install-ConfigText {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Label = (Split-Path $Destination -Leaf)
    )

    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
        ((Get-Content -LiteralPath $Destination -Raw) -ceq $Text)) {
        Write-Skip "$Label already identical"
        return $true
    }

    if ($script:DryRun) {
        if (Test-Path -LiteralPath $Destination) {
            Write-Would "overwrite $Destination (backing the current one up first)"
        }
        else { Write-Would "create $Destination" }
        return $true
    }

    try {
        Backup-ExistingFile $Destination | Out-Null
        $parent = Split-Path $Destination -Parent
        New-Item -ItemType Directory -Force -Path $parent | Out-Null

        # Stage beside the destination so the final rename stays on one volume and is atomic.
        $tmp = Join-Path $parent ".workstation-$PID-$([guid]::NewGuid().ToString('N')).tmp"
        Set-Content -LiteralPath $tmp -Value $Text -NoNewline -Encoding utf8
        Move-Item -LiteralPath $tmp -Destination $Destination -Force
        Write-Ok $Label
        return $true
    }
    catch {
        if ($tmp -and (Test-Path -LiteralPath $tmp)) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        Write-Fail "$Label - $($_.Exception.Message)"
        return $false
    }
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
#
# -Location comes from layout\LAYOUT.md and is best-effort on purpose. Not every installer
# accepts it - winget can only pass it on to installer types that declare a switch for it -
# and a package landing in its default folder is a far better outcome than a restore that
# stops. So a rejected location is retried without one and reported, never fatal.
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Location,
        # 'msstore' for the handful of things Microsoft publishes nowhere else. Left empty,
        # winget searches every source and can hit the same name twice, then refuses with an
        # ambiguity error rather than picking - so a Store row must say so explicitly.
        [string]$Source
    )
    if (Test-WingetInstalled $Id) { Write-Skip "$Id already installed"; return 'skip' }
    # 'ok' rather than 'skip': the caller uses that to mean "this run put it there", which
    # is what a dry run is claiming would happen. Reporting 'skip' made the upgrade pass
    # then ask winget about a package that isn't installed, and get told it was up to date.
    if ($script:DryRun) {
        Write-Would "install $Id$(if ($Location) { " into $Location" })"
        return 'ok'
    }

    Write-Host "  ...installing $Id$(if ($Location) { " -> $Location" })" -ForegroundColor DarkYellow
    $common = @('--exact', '--silent', '--accept-package-agreements',
        '--accept-source-agreements', '--disable-interactivity')
    if ($Source) { $common += @('--source', $Source) }

    $argv = @('install', '--id', $Id) + $common
    if ($Location) { $argv += @('--location', $Location) }
    & winget @argv 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -ne 0 -and $Location) {
        Write-Warn2 "$Id rejected --location (exit $LASTEXITCODE) - retrying at its default path"
        & winget @(@('install', '--id', $Id) + $common) 2>&1 |
            Select-Object -Last 2 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -eq 0) {
            Write-Warn2 "$Id installed, but NOT at $Location - update layout\LAYOUT.md or move it by hand"
            return 'ok'
        }
    }

    if ($LASTEXITCODE -eq 0) { Write-Ok "$Id$(if ($Location) { " at $Location" })"; return 'ok' }
    Write-Warn2 "$Id exited with code $LASTEXITCODE"
    return 'fail'
}

# Report whether an upgrade is available without confusing "current" with "winget failed".
# --upgrade-available only renders a table when an upgrade exists; the header offsets are
# used only for the human-readable versions.
function Get-WingetUpdate {
    param([Parameter(Mandatory)][string]$Id)
    $lines = @(winget list --id $Id --exact --upgrade-available --disable-interactivity 2>$null)
    $code = $LASTEXITCODE
    if ($code -ne 0) { return @{ Status = 'check-failed'; ExitCode = $code } }

    $sep = 0
    while ($sep -lt $lines.Count -and $lines[$sep] -notmatch '^-{3,}') { $sep++ }
    if ($sep -ge $lines.Count - 1) { return @{ Status = 'current' } }

    # Versions are for the log line only, so a parse failure must not hide the upgrade.
    # Column widths are computed per query, which makes the header a reliable offset map.
    $header = if ($sep -ge 1) { $lines[$sep - 1] } else { '' }
    $row = $lines[$sep + 1]
    $iCur = $header.IndexOf('Version')
    $iNew = $header.IndexOf('Available')
    $iSrc = $header.IndexOf('Source')
    if ($iCur -lt 0 -or $iNew -le $iCur -or $iSrc -le $iNew -or $row.Length -le $iNew) {
        return @{ Status = 'available'; Current = '?'; Available = '?' }
    }
    return @{
        Status    = 'available'
        Current   = $row.Substring($iCur, $iNew - $iCur).Trim()
        Available = $row.Substring($iNew, [Math]::Min($iSrc - $iNew, $row.Length - $iNew)).Trim()
    }
}

function Update-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    $u = Get-WingetUpdate $Id
    if ($u.Status -eq 'check-failed') {
        Write-Warn2 "$Id update check failed (winget exit $($u.ExitCode))"
        return 'fail'
    }
    if ($u.Status -eq 'current') { Write-Skip "$Id nothing to upgrade"; return 'skip' }
    if ($script:DryRun) { Write-Would "upgrade $Id ($($u.Current) -> $($u.Available))"; return 'ok' }
    Write-Host "  ...upgrading $Id ($($u.Current) -> $($u.Available))" -ForegroundColor DarkYellow
    winget upgrade --id $Id --exact --silent --accept-package-agreements `
        --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "$Id -> $($u.Available)"; return 'ok' }
    Write-Warn2 "$Id upgrade exited with code $LASTEXITCODE"
    return 'fail'
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

# layout\LAYOUT.md is the only place a path under the layout root is written down, and these
# two are how a script asks. Holding a literal instead is what this exists to prevent: the
# second copy is never wrong on the day you write it, only on the day the tree moves.
#
# It reads the copy in the repo, not the one at the root of the tree. The one on disk is for
# whoever opens that folder in three years; the repo is what the scripts are built from, and
# the two can only disagree if something reads the wrong one.
function Get-LayoutRows {
    $md = Join-Path $script:RepoRoot 'layout\LAYOUT.md'
    if (-not (Test-Path $md)) { throw "layout\LAYOUT.md is missing - it is the source of every path under the layout root" }

    $rows = [System.Collections.Generic.List[hashtable]]::new()
    $inPaths = $false
    foreach ($line in Get-Content $md) {
        if ($line -match '^##\s+(.+?)\s*$') { $inPaths = ($Matches[1].Trim() -eq 'Paths'); continue }
        if (-not $inPaths) { continue }
        # Both cells backticked, which skips the header and the ---- separator for free.
        if ($line -notmatch '^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|\s*([^|]*)\|') { continue }
        $rows.Add(@{
                Key     = $Matches[1].Trim()
                Path    = $Matches[2].Trim()
                Created = $Matches[3].Trim() -eq 'yes'
            })
    }
    if (-not $rows.Count) { throw "layout\LAYOUT.md has no readable rows under '## Paths'" }
    return $rows
}

# Throws when there is no row, on purpose: a typo'd key returning $null would send an
# installer to whatever the working directory happened to be. -IfDeclared is for the one
# honest question - "does this package declare an override at all?" - where absence is the
# expected answer rather than a mistake.
function Get-LayoutPath {
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$IfDeclared
    )
    $row = Get-LayoutRows | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
    if ($row) { return $row.Path }
    if ($IfDeclared) { return $null }
    throw "no row for '$Key' in layout\LAYOUT.md"
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

# Most coding fonts have no winget package at all - Nerd Fonts publishes a zip per family on
# GitHub and nothing else. Without this, choosing one of those would make the font the single
# manual step in an otherwise scripted restore, and the styles that need it would fail their
# validation on a fresh machine with no way to fix it except remembering.
#
# Family and URL both backticked, which skips the header and the ---- separator for free.
function Get-FontRowsFromReadme {
    param(
        [Parameter(Mandatory)][string]$ReadmePath,
        [Parameter(Mandatory)][string[]]$Sections
    )
    $current = ''
    $rows = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($line in Get-Content $ReadmePath) {
        if ($line -match '^##\s+(.+?)\s*$') { $current = $Matches[1].Trim(); continue }
        if ($Sections -notcontains $current) { continue }
        if ($line -notmatch '^\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|') { continue }
        $rows.Add(@{ Family = $Matches[1].Trim(); Url = $Matches[2].Trim() })
    }
    return $rows
}

# GDI keeps a per-session list of the fonts it knows about, built when a process first asks.
# A file dropped into the user font directory is not in it. That matters here rather than in
# the abstract: install.ps1 at the repo root runs apps\ and terminal\ in one process, so
# without this the terminal step would fail its font check on the very font the apps step had
# just installed. The broadcast is the same courtesy for programs already open.
$script:FontApi = $null
function Get-FontApi {
    if (-not $script:FontApi) {
        $script:FontApi = Add-Type -Name Font -Namespace Workstation -PassThru -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int AddFontResourceW(string path);

[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam,
    IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
'@
    }
    return $script:FontApi
}

function Publish-FontChange {
    $api = Get-FontApi
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST, WM_FONTCHANGE, SMTO_ABORTIFHUNG. Timeout so one wedged window can't
    # hang a restore.
    [void]$api::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$result)
}

# Install every font file in a release zip, for the current user. User scope on purpose:
# C:\Windows\Fonts needs elevation and nothing else in apps\install.ps1 does, so requiring it
# here would turn an unattended restore into one that stops for a UAC prompt.
#
# Returns 'skip', 'ok' or 'fail' like Install-WingetPackage, so callers report it the same way.
function Install-ZipFont {
    param(
        [Parameter(Mandatory)][string]$Family,
        [Parameter(Mandatory)][string]$Url,
        [switch]$SkipUpgrade
    )

    $have = Resolve-FontFamily "^$([regex]::Escape($Family))$"

    if ($have -and $SkipUpgrade) { Write-Skip "$Family - held back by -SkipUpgrade"; return 'skip' }
    if ($script:DryRun) {
        if ($have) { Write-Would "re-check $Family against $Url and install anything that changed" }
        else { Write-Would "download $Family from $Url and install it for the current user" }
        return 'ok'
    }

    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $stage = Join-Path ([IO.Path]::GetTempPath()) "workstation-font-$PID-$([guid]::NewGuid().ToString('N'))"
    $written = 0
    $seen = 0

    try {
        New-Item -ItemType Directory -Path $stage | Out-Null
        $zip = Join-Path $stage 'font.zip'
        if (-not $have) { Write-Host "  ...downloading $Family" -ForegroundColor DarkYellow }
        Invoke-WebRequest $Url -OutFile $zip -UseBasicParsing
        $unpacked = Join-Path $stage 'unpacked'
        Expand-Archive $zip -DestinationPath $unpacked -Force

        $files = @(Get-ChildItem $unpacked -Recurse -File | Where-Object Extension -in '.ttf', '.otf')
        if (-not $files) { throw "no .ttf or .otf inside the archive" }
        $seen = $files.Count

        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

        foreach ($f in $files) {
            $target = Join-Path $fontDir $f.Name

            # Compare contents rather than trusting the family being present. That is what
            # makes a re-run cheap and still lets a new upstream release actually land -
            # "latest stable of everything" has to hold for fonts too.
            if ((Test-Path -LiteralPath $target) -and
                (Get-FileHash -LiteralPath $target).Hash -eq (Get-FileHash -LiteralPath $f.FullName).Hash) {
                continue
            }

            Copy-Item -LiteralPath $f.FullName -Destination $target -Force

            # The value name is cosmetic - it labels the font in Settings, while rendering
            # follows the path in the value. The file's own name is close enough and cannot
            # disagree with the file it points at.
            $kind = if ($f.Extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
            Set-ItemProperty -Path $regPath -Name "$($f.BaseName) ($kind)" -Value $target
            [void](Get-FontApi)::AddFontResourceW($target)
            $written++
        }
    }
    catch {
        # _lib sets $ErrorActionPreference to Stop, so a dropped download would otherwise
        # take the whole restore down with it.
        Write-Fail "$Family - $($_.Exception.Message)"
        return 'fail'
    }
    finally {
        if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }

    if (-not $written) { Write-Skip "$Family already current ($seen files)"; return 'skip' }
    Publish-FontChange

    # A font that didn't register renders as hollow boxes with no error anywhere, so confirm
    # the family Windows now reports rather than assuming the copy was enough. A mismatch is
    # nearly always the name in README.md, not the install.
    if (-not (Resolve-FontFamily "^$([regex]::Escape($Family))$")) {
        Write-Fail "installed $written file(s) but Windows reports no family called '$Family'"
        Write-Warn2 "check that name against the font itself - it is what styles reference"
        return 'fail'
    }

    Write-Ok "$Family ($written of $seen file(s) written)"
    return 'ok'
}

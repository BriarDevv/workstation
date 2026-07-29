<#
.SYNOPSIS
    Removes the inbox apps listed in README.md.

.DESCRIPTION
    Reads the package names straight out of README.md's "Inbox apps" table, so adding a row
    there is enough. The table is the complete list - this script holds no names of its own.

    This is the one script in the repo that DELETES rather than configures, so it is the one
    that most deserves a dry run first. It is also the least trustworthy on day one: package
    names change between Windows releases, and this table was written before the machine
    existed. -List is how you reconcile the two.

    Per-user by default, which is reversible - reinstall from the Store. -AllUsers also
    removes the provisioned package so new profiles don't get it back, and needs elevation.

    Idempotent: an app that isn't there is a skip, not a failure.

.PARAMETER List
    Show every removable app on this machine and exit. Removes nothing. Use it to check the
    table against reality before believing either.

.PARAMETER AllUsers
    Also remove the provisioned copy, so a newly created profile doesn't get the app back.
    Needs an elevated shell.

.PARAMETER WhatIfOnly
    Report every action without performing any of them.

.EXAMPLE
    pwsh windows\debloat.ps1 -List
    pwsh windows\debloat.ps1 -WhatIfOnly
    pwsh windows\debloat.ps1
    pwsh windows\debloat.ps1 -AllUsers
#>
[CmdletBinding()]
param(
    [switch]$List,
    [switch]$AllUsers,
    [switch]$WhatIfOnly
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

$script:DryRun = [bool]$WhatIfOnly
$readme = Join-Path $PSScriptRoot 'README.md'

# Never removable, whatever any table says. Appx is unforgiving - take out a framework or the
# Store and the fix is a repair install, not an undo. This guard exists because the list of
# names lives in a markdown file that is easy to edit and impossible to type-check.
$PROTECTED = @(
    'Microsoft.WindowsStore'              # one-way door on Pro
    'Microsoft.DesktopAppInstaller'       # winget itself
    'Microsoft.VCLibs'                    # C++ runtime, half the Store depends on it
    'Microsoft.UI.Xaml'                   # UI framework, same
    'Microsoft.NET'                       # .NET native framework
    'Microsoft.WindowsTerminal'           # apps\ installs it on purpose
    'MicrosoftWindows.Client'             # the shell itself
    'Microsoft.Windows.Photos'            # default image handler, no replacement installed
    'Microsoft.SecHealthUI'               # Windows Security UI
)

function Test-Protected {
    param([Parameter(Mandatory)][string]$Name)
    foreach ($p in $PROTECTED) { if ($Name -like "$p*") { return $true } }
    return $false
}

# ---------------------------------------------------------------- -List
if ($List) {
    Write-Step 'Removable apps on this machine'
    Write-Host '  Frameworks and system components are hidden - they are never candidates.' -ForegroundColor DarkGray
    Write-Host ''

    $wanted = @(Get-IdsFromReadme $readme @('Inbox apps'))
    $apps = @(Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.NonRemovable -ne $true } | Sort-Object Name)

    foreach ($a in $apps) {
        if (Test-Protected $a.Name) { continue }
        $mark = if ($wanted -contains $a.Name) { '[in table]' } else { '          ' }
        $colour = if ($wanted -contains $a.Name) { 'Yellow' } else { 'Gray' }
        Write-Host ("  $mark {0}" -f $a.Name) -ForegroundColor $colour
    }

    Write-Host ''
    Write-Host "  $($apps.Count) removable, $(@($apps | Where-Object { $wanted -contains $_.Name }).Count) of them named in the table." -ForegroundColor DarkGray
    Write-Host '  Anything above without [in table] that you do not want needs a row in README.md.' -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}

# ---------------------------------------------------------------- remove
Write-Step 'Inbox apps'
$wanted = @(Get-IdsFromReadme $readme @('Inbox apps'))
if (-not $wanted.Count) {
    Write-Fail 'no packages found under "## Inbox apps" in README.md'
    exit 1
}

if ($AllUsers -and -not (Test-Admin)) {
    Write-Warn2 '-AllUsers needs an elevated shell. Doing the per-user removal only.'
    Write-Host '         The provisioned copies stay, so a NEW Windows profile would get them back.' -ForegroundColor DarkGray
    $AllUsers = $false
}

Write-Host "  $($wanted.Count) in the table$(if ($AllUsers) { ', removing for all users' } else { ', current user only' })" -ForegroundColor DarkGray

$removed = 0
$absent = [System.Collections.Generic.List[string]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($name in $wanted) {
    if (Test-Protected $name) {
        Write-Warn2 "$name is protected and will not be removed - take the row out of README.md"
        continue
    }

    $pkg = @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
    if (-not $pkg.Count) {
        # Not a failure. Either Windows stopped shipping it or it was never there, and both
        # mean the row is stale rather than the machine being wrong.
        $absent.Add($name)
        continue
    }

    if ($script:DryRun) { Write-Would "remove $name"; $removed++; continue }

    try {
        $pkg | Remove-AppxPackage -ErrorAction Stop
        if ($AllUsers) {
            Get-AppxProvisionedPackage -Online |
                Where-Object { $_.DisplayName -eq $name } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null }
        }
        Write-Ok $name
        $removed++
    }
    catch {
        Write-Warn2 "$name - $($_.Exception.Message)"
        $failed.Add($name)
    }
}

# ---------------------------------------------------------------- summary
Write-Step 'Summary'
Write-Host "  $removed removed, $($absent.Count) not present, $($failed.Count) failed" -ForegroundColor DarkGray

if ($absent.Count) {
    Write-Host ''
    Write-Skip "$($absent.Count) named in the table but not on this machine:"
    foreach ($a in $absent) { Write-Host "         $a" -ForegroundColor DarkGray }
    Write-Host '         Stale rows. Windows renames and drops packages between releases - check' -ForegroundColor DarkGray
    Write-Host '         with -List, then delete the rows. A row that matches nothing is noise.' -ForegroundColor DarkGray
}

if (-not $AllUsers -and $removed) {
    Write-Host ''
    Write-Warn2 'Removed for this user only. A new Windows profile gets them all back.'
    Write-Host '         Elevate and re-run with -AllUsers to strip the provisioned copies too.' -ForegroundColor DarkGray
}

if ($failed.Count) {
    Write-Host ''
    Write-Fail "$($failed.Count) didn't complete:"
    foreach ($f in $failed) { Write-Host "         $f" -ForegroundColor Red }
    Write-Host ''
    exit 1
}

Write-Ok 'nothing failed'
Write-Host ''
Write-Host '  install.ps1 sets DisableWindowsConsumerFeatures, which is what stops Windows' -ForegroundColor DarkGray
Write-Host '  putting a fresh batch of suggested apps back on the next feature update.' -ForegroundColor DarkGray
Write-Host ''
